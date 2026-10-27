package store

import (
	"context"
	"github.com/jackc/pgx/v5"

	"github.com/revocred/revocred-api/internal/domain"
	"github.com/revocred/revocred-api/internal/recommendation"
	"github.com/revocred/revocred-api/internal/scoring"
	"github.com/revocred/revocred-api/internal/strategy"
)

// PreviewPlan uses the same deterministic engine as a saved plan. It persists
// nothing and never accepts card terms or scores supplied by a browser.
func (p *Postgres) PreviewPlan(ctx context.Context, input domain.RecommendationInput) (domain.Bootstrap, error) {
	catalog, err := p.ListCatalog(ctx)
	if err != nil {
		return domain.Bootstrap{}, err
	}
	wallet := []domain.WalletCard{}
	input.OwnedCards = nil
	seen := map[string]bool{}
	for _, id := range input.ExistingCardIDs {
		if seen[id] {
			continue
		}
		seen[id] = true
		found := false
		for _, card := range catalog {
			if card.ID == id {
				c := card
				wallet = append(wallet, domain.WalletCard{CatalogCardID: id, Status: "active", Card: &c})
				input.OwnedCards = append(input.OwnedCards, card)
				found = true
				break
			}
		}
		if !found {
			return domain.Bootstrap{}, ErrNotFound
		}
	}
	// A preview persists nothing, so index picks are synthesized in memory. They
	// are shown as owned and, when the cardholder supplied terms, fed to the same
	// engine with the same numbers a saved plan will produce.
	previewWallet, err := previewReferenceCards(ctx, p, input.AddedCards, &input, wallet)
	if err != nil {
		return domain.Bootstrap{}, err
	}
	wallet = append(wallet, previewWallet...)
	result := recommendation.New().Recommend(input, catalog)
	result.StrategyCode = onboardingStrategy(input)
	categories, goal, target := questionnaireProfile(input, result)
	profile := domain.Profile{DisplayName: "Your preview", CreditCardStrategy: result.StrategyCode, Goal: goal, TopSpendCategories: categories, NextApplicationTarget: target, RewardsGoal: input.RewardsGoal, TravelScope: input.TravelScope}
	playbook := strategy.Build(result.StrategyCode, walletNames(wallet), playbookPrefs(&input))
	substitutions, err := p.Substitutions(ctx)
	if err != nil {
		return domain.Bootstrap{}, err
	}
	applySubstitutions(&playbook, wallet, substitutions)
	applyRecommendation(&playbook, &result)
	profile.NextApplicationTarget = playbook.NextCard
	return domain.Bootstrap{Catalog: catalog, Wallet: wallet, Profile: &profile, LatestRecommendations: &result, LatestQuestionnaire: &input, WalletMetrics: scoring.Metrics(wallet, input.MonthlyCategorySpend, input.TravelScope), Playbook: &playbook, QuickPrompts: []string{}}, nil
}

// SaveOnboarding atomically reconciles the chosen wallet and stores the plan.
// Existing custom cards are allowed only for their owner. Failed validation or
// persistence rolls back the wallet changes too, making retries safe.
func (p *Postgres) SaveOnboarding(ctx context.Context, userID string, input domain.RecommendationInput) (domain.RecommendationResult, error) {
	tx, err := p.pool.Begin(ctx)
	if err != nil {
		return domain.RecommendationResult{}, err
	}
	defer tx.Rollback(ctx)
	if _, err = tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtextextended($1,0))`, userID); err != nil {
		return domain.RecommendationResult{}, err
	}
	repo := &Postgres{pool: transactionDB{tx}}
	// Create the picked cards on the same transaction, so a later failure cannot
	// leave owned catalog cards behind without a wallet entry.
	ids, err := repo.resolveOnboardingCards(ctx, userID, input.AddedCards, input.ExistingCardIDs)
	if err != nil {
		return domain.RecommendationResult{}, err
	}
	// Validate the full selection before altering the wallet.
	for _, id := range ids {
		var allowed bool
		err = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM revocred.catalog_cards WHERE id::text=$1 AND is_active AND ((owner_user_id IS NULL AND data_kind='issuer_snapshot') OR owner_user_id=$2))`, id, userID).Scan(&allowed)
		if err != nil {
			return domain.RecommendationResult{}, err
		}
		if !allowed {
			return domain.RecommendationResult{}, ErrNotFound
		}
	}
	if _, err = tx.Exec(ctx, `DELETE FROM revocred.wallet_cards WHERE user_id=$1 AND status='active' AND NOT(catalog_card_id::text=ANY($2::text[]))`, userID, ids); err != nil {
		return domain.RecommendationResult{}, err
	}
	for _, id := range ids {
		_, err = tx.Exec(ctx, `INSERT INTO revocred.wallet_cards(user_id,catalog_card_id,status) VALUES($1,$2,'active') ON CONFLICT(user_id,catalog_card_id) DO UPDATE SET status='active'`, userID, id)
		if err != nil {
			return domain.RecommendationResult{}, err
		}
	}
	wallet, err := repo.ListWallet(ctx, userID)
	if err != nil {
		return domain.RecommendationResult{}, err
	}
	input.OwnedCards = nil
	input.ExistingCardIDs = []string{}
	for _, item := range wallet {
		// A card without terms is owned but must not shape the ranking.
		if item.Status == "active" && item.Card != nil && !item.Card.TermsUnknown {
			input.ExistingCardIDs = append(input.ExistingCardIDs, item.CatalogCardID)
			input.OwnedCards = append(input.OwnedCards, *item.Card)
		}
	}
	cards, err := repo.ListCatalog(ctx)
	if err != nil {
		return domain.RecommendationResult{}, err
	}
	result := recommendation.New().Recommend(input, cards)
	result.StrategyCode = onboardingStrategy(input)
	result, err = repo.SaveRecommendation(ctx, userID, input, result)
	if err != nil {
		return domain.RecommendationResult{}, err
	}
	if err = tx.Commit(ctx); err != nil {
		return domain.RecommendationResult{}, err
	}
	return result, nil
}

// previewReferenceCards turns index picks into display-only wallet entries and
// feeds the engine the vetted cards plus any terms the cardholder supplied.
func previewReferenceCards(ctx context.Context, repo *Postgres, picks []domain.OnboardingCard, input *domain.RecommendationInput, wallet []domain.WalletCard) ([]domain.WalletCard, error) {
	if len(picks) == 0 {
		return nil, nil
	}
	wanted := make([]string, 0, len(picks))
	for _, pick := range picks {
		wanted = append(wanted, pick.ReferenceID)
	}
	references, err := repo.referenceCardsByID(ctx, wanted)
	if err != nil {
		return nil, err
	}
	shown := make([]domain.WalletCard, 0, len(picks))
	for _, pick := range picks {
		reference, ok := references[pick.ReferenceID]
		if !ok {
			continue
		}
		if reference.CatalogCardID != "" {
			input.ExistingCardIDs = append(input.ExistingCardIDs, reference.CatalogCardID)
			continue
		}
		card := domain.CatalogCard{
			ID:                reference.ID,
			Slug:              reference.Slug,
			Issuer:            reference.Issuer,
			Network:           reference.Network,
			Name:              reference.Name,
			BestUse:           pick.BestUse,
			Summary:           "Card added from search. Terms are supplied by the cardholder or left out of the score.",
			TermsUnknown:      true,
			SourceName:        "Search index",
			SourceDisclaimer:  reference.Disclaimer,
			DatasetVersion:    "search-index",
			MinimumCreditTier: "good",
			TravelScope:       "none",
			RewardsType:       reference.RewardsType,
		}
		if pick.IncludeTerms {
			// Mirror the saved path: supplied terms count toward the score.
			card.TermsUnknown = false
			card.AnnualFeeCents = pick.AnnualFeeCents
			card.RewardRates = pick.RewardRates
			card.TransferablePoints = pick.Transferable
			input.OwnedCards = append(input.OwnedCards, card)
		}
		shown = append(shown, domain.WalletCard{CatalogCardID: card.ID, Status: "active", Card: &card})
	}
	return shown, nil
}

func onboardingStrategy(input domain.RecommendationInput) string {
	goal := strategy.Goal(input.RewardsGoal)
	if input.RewardsGoal == "hybrid" {
		goal = strategy.GoalTravel
		if input.TravelScope == "none" {
			goal = strategy.GoalCashBack
		}
	}
	code, err := strategy.SelectFromQuestionnaire(input.CreditTier, goal, input.FeeToleranceCents, strategy.Travel(input.TravelScope))
	if err != nil {
		return ""
	}
	return string(code)
}

type transactionDB struct{ pgx.Tx }

func (t transactionDB) BeginTx(ctx context.Context, _ pgx.TxOptions) (pgx.Tx, error) {
	return t.Begin(ctx)
}
