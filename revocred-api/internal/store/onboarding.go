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
	result := recommendation.New().Recommend(input, catalog)
	result.StrategyCode = onboardingStrategy(input)
	categories, goal, target := questionnaireProfile(input, result)
	profile := domain.Profile{DisplayName: "Your preview", CreditCardStrategy: result.StrategyCode, Goal: goal, TopSpendCategories: categories, NextApplicationTarget: target, RewardsGoal: input.RewardsGoal, TravelScope: input.TravelScope}
	playbook := strategy.Build(result.StrategyCode, walletNames(wallet), playbookPrefs(&input))
	applyRecommendation(&playbook, &result)
	return domain.Bootstrap{Catalog: catalog, Wallet: wallet, Profile: &profile, LatestRecommendations: &result, LatestQuestionnaire: &input, WalletMetrics: scoring.Metrics(wallet, input.MonthlyCategorySpend), Playbook: &playbook, QuickPrompts: []string{}}, nil
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
	ids := input.ExistingCardIDs
	if ids == nil {
		ids = []string{}
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
		if item.Status == "active" && item.Card != nil {
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
