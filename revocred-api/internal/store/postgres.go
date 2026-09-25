package store

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"sort"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/revocred/revocred-api/internal/domain"
	"github.com/revocred/revocred-api/internal/recommendation"
	"github.com/revocred/revocred-api/internal/scoring"
	"github.com/revocred/revocred-api/internal/strategy"
)

type Postgres struct {
	pool *pgxpool.Pool
}

func NewPostgres(pool *pgxpool.Pool) *Postgres { return &Postgres{pool: pool} }

func (p *Postgres) Ping(ctx context.Context) error {
	var ready bool
	if err := p.pool.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM revocred.catalog_cards WHERE data_kind='issuer_snapshot' AND is_active) AND to_regprocedure('revocred.delete_account(uuid)') IS NOT NULL`).Scan(&ready); err != nil {
		return err
	}
	if !ready {
		return errors.New("catalog or schema not ready")
	}
	return nil
}

func (p *Postgres) Bootstrap(ctx context.Context, userID string) (domain.Bootstrap, error) {
	profile, err := p.GetProfile(ctx, userID)
	if err != nil {
		return domain.Bootstrap{}, err
	}
	wallet, err := p.ListWallet(ctx, userID)
	if err != nil {
		return domain.Bootstrap{}, err
	}
	catalog, err := p.ListCatalog(ctx)
	if err != nil {
		return domain.Bootstrap{}, err
	}
	recommendations, err := p.latestRecommendation(ctx, userID)
	if err != nil {
		return domain.Bootstrap{}, err
	}
	questionnaire, err := p.latestQuestionnaire(ctx, userID)
	if err != nil {
		return domain.Bootstrap{}, err
	}
	spend := map[string]int64{}
	if questionnaire != nil {
		spend = questionnaire.MonthlyCategorySpend
		questionnaire.ExistingCardIDs = []string{}
		for _, item := range wallet {
			if item.Status == "active" {
				questionnaire.ExistingCardIDs = append(questionnaire.ExistingCardIDs, item.CatalogCardID)
				if item.Card != nil {
					questionnaire.OwnedCards = append(questionnaire.OwnedCards, *item.Card)
				}
			}
		}
		// Re-evaluate against the current wallet; saved runs remain immutable audit records.
		current := recommendation.New().Recommend(*questionnaire, catalog)
		recommendations = &current
	}
	code := ""
	if profile != nil {
		code = profile.CreditCardStrategy
	}
	if recommendations != nil {
		recommendations.StrategyCode = code
	}
	playbook := strategy.Build(code, walletNames(wallet), playbookPrefs(questionnaire))
	applyRecommendation(&playbook, recommendations)
	if profile != nil {
		profile.NextApplicationTarget = playbook.NextCard
	}
	return domain.Bootstrap{
		Catalog:               catalog,
		Profile:               profile,
		Wallet:                wallet,
		LatestRecommendations: recommendations,
		LatestQuestionnaire:   questionnaire,
		WalletMetrics:         scoring.Metrics(wallet, spend),
		Playbook:              &playbook,
		QuickPrompts: []string{
			"What card should I use for groceries?",
			"What should I apply for next?",
			"How do I maximize travel?",
		},
	}, nil
}

const catalogQuery = `
SELECT c.id::text, c.slug, c.issuer, c.network, c.name,
       v.summary, v.best_use, v.annual_fee_cents, v.reward_rates, v.benefits,
       v.transferable_points, v.travel_scope, v.minimum_credit_tier, v.rewards_type,
       v.first_year_bonus_estimate_cents, v.annual_benefit_estimate_cents,
       v.dataset_version, s.name, COALESCE(s.url, ''), s.disclaimer, s.published_at, v.created_at
FROM revocred.catalog_cards c
JOIN LATERAL (
    SELECT cv.* FROM revocred.card_catalog_versions cv
    WHERE cv.catalog_card_id = c.id
    ORDER BY cv.created_at DESC, cv.id DESC LIMIT 1
) v ON true
JOIN revocred.catalog_sources s ON s.id = v.source_id
WHERE c.is_active = true AND c.owner_user_id IS NULL AND c.data_kind = 'issuer_snapshot'
ORDER BY c.issuer, c.name`

func (p *Postgres) ListCatalog(ctx context.Context) ([]domain.CatalogCard, error) {
	rows, err := p.pool.Query(ctx, catalogQuery)
	if err != nil {
		return nil, fmt.Errorf("list catalog: %w", err)
	}
	defer rows.Close()

	cards := make([]domain.CatalogCard, 0)
	for rows.Next() {
		card, err := scanCatalogCard(rows)
		if err != nil {
			return nil, fmt.Errorf("scan catalog card: %w", err)
		}
		cards = append(cards, card)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate catalog: %w", err)
	}
	return cards, nil
}

type rowScanner interface {
	Scan(dest ...any) error
}

func scanCatalogCard(row rowScanner) (domain.CatalogCard, error) {
	var card domain.CatalogCard
	var ratesJSON, benefitsJSON []byte
	err := row.Scan(
		&card.ID, &card.Slug, &card.Issuer, &card.Network, &card.Name,
		&card.Summary, &card.BestUse, &card.AnnualFeeCents, &ratesJSON, &benefitsJSON,
		&card.TransferablePoints, &card.TravelScope, &card.MinimumCreditTier, &card.RewardsType,
		&card.FirstYearBonusCents, &card.AnnualBenefitValue, &card.DatasetVersion,
		&card.SourceName, &card.SourceURL, &card.SourceDisclaimer, &card.SourcePublishedAt, &card.CatalogVersionCreated,
	)
	if err != nil {
		return domain.CatalogCard{}, err
	}
	if err := json.Unmarshal(ratesJSON, &card.RewardRates); err != nil {
		return domain.CatalogCard{}, fmt.Errorf("decode reward rates: %w", err)
	}
	if err := json.Unmarshal(benefitsJSON, &card.Benefits); err != nil {
		return domain.CatalogCard{}, fmt.Errorf("decode benefits: %w", err)
	}
	return card, nil
}

func (p *Postgres) GetProfile(ctx context.Context, userID string) (*domain.Profile, error) {
	var profile domain.Profile
	err := p.pool.QueryRow(ctx, `
SELECT user_id::text, display_name, credit_card_strategy, goal, top_spend_categories,
       next_application_target, rewards_goal, travel_scope, created_at, updated_at
FROM revocred.profiles WHERE user_id = $1`, userID).Scan(
		&profile.UserID, &profile.DisplayName, &profile.CreditCardStrategy, &profile.Goal,
		&profile.TopSpendCategories, &profile.NextApplicationTarget, &profile.RewardsGoal,
		&profile.TravelScope, &profile.CreatedAt, &profile.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("get profile: %w", err)
	}
	return &profile, nil
}

func (p *Postgres) UpsertProfile(ctx context.Context, userID string, profile domain.Profile) (domain.Profile, error) {
	if profile.TopSpendCategories == nil {
		profile.TopSpendCategories = []string{}
	}
	err := p.pool.QueryRow(ctx, `
INSERT INTO revocred.profiles (
    user_id, display_name, credit_card_strategy, goal, top_spend_categories,
    next_application_target, rewards_goal, travel_scope
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
ON CONFLICT (user_id) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    credit_card_strategy = EXCLUDED.credit_card_strategy,
    goal = EXCLUDED.goal,
    top_spend_categories = EXCLUDED.top_spend_categories,
    next_application_target = EXCLUDED.next_application_target,
    rewards_goal = EXCLUDED.rewards_goal,
    travel_scope = EXCLUDED.travel_scope,
    updated_at = now()
RETURNING user_id::text, created_at, updated_at`,
		userID, profile.DisplayName, profile.CreditCardStrategy, profile.Goal,
		profile.TopSpendCategories, profile.NextApplicationTarget, profile.RewardsGoal, profile.TravelScope,
	).Scan(&profile.UserID, &profile.CreatedAt, &profile.UpdatedAt)
	if err != nil {
		return domain.Profile{}, fmt.Errorf("upsert profile: %w", err)
	}
	return profile, nil
}

func (p *Postgres) ListWallet(ctx context.Context, userID string) ([]domain.WalletCard, error) {
	rows, err := p.pool.Query(ctx, `
SELECT w.id::text, w.user_id::text, w.catalog_card_id::text, w.nickname, w.status, w.opened_on, w.created_at,
       c.id::text, c.slug, c.issuer, c.network, c.name,
       v.summary, v.best_use, v.annual_fee_cents, v.reward_rates, v.benefits,
       v.transferable_points, v.travel_scope, v.minimum_credit_tier, v.rewards_type,
       v.first_year_bonus_estimate_cents, v.annual_benefit_estimate_cents,
       v.dataset_version, s.name, COALESCE(s.url, ''), s.disclaimer, s.published_at, v.created_at
FROM revocred.wallet_cards w
JOIN revocred.catalog_cards c ON c.id = w.catalog_card_id
JOIN LATERAL (
    SELECT cv.* FROM revocred.card_catalog_versions cv
    WHERE cv.catalog_card_id = c.id
    ORDER BY cv.created_at DESC, cv.id DESC LIMIT 1
) v ON true
JOIN revocred.catalog_sources s ON s.id = v.source_id
WHERE w.user_id = $1
ORDER BY w.created_at DESC`, userID)
	if err != nil {
		return nil, fmt.Errorf("list wallet: %w", err)
	}
	defer rows.Close()

	wallet := make([]domain.WalletCard, 0)
	for rows.Next() {
		var item domain.WalletCard
		var card domain.CatalogCard
		var ratesJSON, benefitsJSON []byte
		err := rows.Scan(
			&item.ID, &item.UserID, &item.CatalogCardID, &item.Nickname, &item.Status, &item.OpenedOn, &item.CreatedAt,
			&card.ID, &card.Slug, &card.Issuer, &card.Network, &card.Name,
			&card.Summary, &card.BestUse, &card.AnnualFeeCents, &ratesJSON, &benefitsJSON,
			&card.TransferablePoints, &card.TravelScope, &card.MinimumCreditTier, &card.RewardsType,
			&card.FirstYearBonusCents, &card.AnnualBenefitValue, &card.DatasetVersion,
			&card.SourceName, &card.SourceURL, &card.SourceDisclaimer, &card.SourcePublishedAt, &card.CatalogVersionCreated,
		)
		if err != nil {
			return nil, fmt.Errorf("scan wallet: %w", err)
		}
		if err := json.Unmarshal(ratesJSON, &card.RewardRates); err != nil {
			return nil, fmt.Errorf("decode wallet reward rates: %w", err)
		}
		if err := json.Unmarshal(benefitsJSON, &card.Benefits); err != nil {
			return nil, fmt.Errorf("decode wallet benefits: %w", err)
		}
		item.Card = &card
		wallet = append(wallet, item)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate wallet: %w", err)
	}
	return wallet, nil
}

func (p *Postgres) CreateWalletCard(ctx context.Context, userID string, input domain.CreateWalletCard) (domain.WalletCard, error) {
	var item domain.WalletCard
	err := p.pool.QueryRow(ctx, `
INSERT INTO revocred.wallet_cards (user_id, catalog_card_id, nickname, status, opened_on)
SELECT $1, id, $3, $4, $5 FROM revocred.catalog_cards
WHERE id = $2 AND is_active AND (owner_user_id IS NULL OR owner_user_id = $1)
RETURNING id::text, user_id::text, catalog_card_id::text, nickname, status, opened_on, created_at`,
		userID, input.CatalogCardID, input.Nickname, input.Status, input.OpenedOn,
	).Scan(&item.ID, &item.UserID, &item.CatalogCardID, &item.Nickname, &item.Status, &item.OpenedOn, &item.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.WalletCard{}, ErrNotFound
		}
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) {
			switch pgErr.Code {
			case "54000":
				return domain.WalletCard{}, ErrQuota
			case "23505":
				return domain.WalletCard{}, ErrConflict
			case "23503", "22P02":
				return domain.WalletCard{}, ErrNotFound
			}
		}
		return domain.WalletCard{}, fmt.Errorf("create wallet card: %w", err)
	}
	return item, nil
}

func (p *Postgres) CreateCustomCard(ctx context.Context, userID string, input domain.CreateCustomCard) (domain.WalletCard, error) {
	tx, err := p.pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return domain.WalletCard{}, fmt.Errorf("begin custom card: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	slug := customSlug(input.Name)
	var cardID string
	err = tx.QueryRow(ctx, `
INSERT INTO revocred.catalog_cards (slug, issuer, network, name, owner_user_id, data_kind)
VALUES ($1, $2, $3, $4, $5, 'user_supplied')
RETURNING id::text`, slug, input.Issuer, input.Network, input.Name, userID).Scan(&cardID)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return domain.WalletCard{}, ErrConflict
		}
		if errors.As(err, &pgErr) && pgErr.Code == "54000" {
			return domain.WalletCard{}, ErrQuota
		}
		return domain.WalletCard{}, fmt.Errorf("insert custom catalog card: %w", err)
	}
	if input.Benefits == nil {
		input.Benefits = []string{}
	}
	if input.RewardRates == nil {
		input.RewardRates = map[string]float64{}
	}
	ratesJSON, err := json.Marshal(input.RewardRates)
	if err != nil {
		return domain.WalletCard{}, fmt.Errorf("encode custom rates: %w", err)
	}
	benefitsJSON, err := json.Marshal(input.Benefits)
	if err != nil {
		return domain.WalletCard{}, fmt.Errorf("encode custom benefits: %w", err)
	}
	_, err = tx.Exec(ctx, `
INSERT INTO revocred.card_catalog_versions (
    catalog_card_id, source_id, dataset_version, summary, best_use, annual_fee_cents,
    reward_rates, benefits, transferable_points, travel_scope, minimum_credit_tier,
    rewards_type
) VALUES ($1, '10000000-0000-4000-8000-000000000002', 'user-supplied', $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
		cardID, "User-supplied card terms.", input.BestUse, input.AnnualFeeCents,
		ratesJSON, benefitsJSON, input.TransferablePoints, input.TravelScope,
		input.MinimumCreditTier, input.RewardsType)
	if err != nil {
		return domain.WalletCard{}, fmt.Errorf("insert custom catalog version: %w", err)
	}
	var item domain.WalletCard
	err = tx.QueryRow(ctx, `
INSERT INTO revocred.wallet_cards (user_id, catalog_card_id, nickname, status)
VALUES ($1, $2, $3, 'active')
RETURNING id::text, user_id::text, catalog_card_id::text, nickname, status, opened_on, created_at`,
		userID, cardID, input.Nickname,
	).Scan(&item.ID, &item.UserID, &item.CatalogCardID, &item.Nickname, &item.Status, &item.OpenedOn, &item.CreatedAt)
	if err != nil {
		return domain.WalletCard{}, fmt.Errorf("insert custom wallet card: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return domain.WalletCard{}, fmt.Errorf("commit custom card: %w", err)
	}
	item.Card = &domain.CatalogCard{
		ID: cardID, Slug: slug, Issuer: input.Issuer, Network: input.Network, Name: input.Name,
		Summary: "User-supplied card terms.", BestUse: input.BestUse, AnnualFeeCents: input.AnnualFeeCents,
		RewardRates: input.RewardRates, Benefits: input.Benefits, TransferablePoints: input.TransferablePoints,
		TravelScope: input.TravelScope, MinimumCreditTier: input.MinimumCreditTier, RewardsType: input.RewardsType,
		DatasetVersion: "user-supplied", SourceName: "User-supplied card terms",
		SourceDisclaimer: "Entered by the user. Not verified against issuer documents. Educational use only.",
	}
	return item, nil
}

func customSlug(name string) string {
	var b strings.Builder
	b.WriteString("custom-")
	for _, r := range strings.ToLower(name) {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') {
			b.WriteRune(r)
		} else if (r == ' ' || r == '-') && !strings.HasSuffix(b.String(), "-") {
			b.WriteByte('-')
		}
	}
	slug := strings.Trim(b.String(), "-")
	if len(slug) < 8 {
		slug = slug + "card"
	}
	if len(slug) > 40 {
		slug = slug[:40]
	}
	return strings.Trim(slug, "-")
}

func (p *Postgres) DeleteWalletCard(ctx context.Context, userID, walletCardID string) error {
	tx, err := p.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	var cardID string
	err = tx.QueryRow(ctx, `DELETE FROM revocred.wallet_cards WHERE id = $1 AND user_id = $2 RETURNING catalog_card_id::text`, walletCardID, userID).Scan(&cardID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrNotFound
		}
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "22P02" {
			return ErrNotFound
		}
		return fmt.Errorf("delete wallet card: %w", err)
	}
	if _, err = tx.Exec(ctx, `DELETE FROM revocred.catalog_cards WHERE id = $1 AND owner_user_id = $2`, cardID, userID); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (p *Postgres) SaveRecommendation(ctx context.Context, userID string, input domain.RecommendationInput, result domain.RecommendationResult) (domain.RecommendationResult, error) {
	if input.ExistingCardIDs == nil {
		input.ExistingCardIDs = []string{}
	}
	if result.Exclusions == nil {
		result.Exclusions = []domain.RecommendationExclusion{}
	}
	if result.CatalogSnapshot == nil {
		result.CatalogSnapshot = []domain.CatalogCard{}
	}
	tx, err := p.pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return domain.RecommendationResult{}, fmt.Errorf("begin recommendation transaction: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	spendJSON, err := json.Marshal(input.MonthlyCategorySpend)
	if err != nil {
		return domain.RecommendationResult{}, fmt.Errorf("encode questionnaire spend: %w", err)
	}
	var questionnaireID string
	err = tx.QueryRow(ctx, `
INSERT INTO revocred.questionnaire_responses (
    user_id, monthly_category_spend, fee_tolerance_cents, travel_scope,
    rewards_goal, credit_tier, existing_card_ids, life_stage
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
RETURNING id::text`, userID, spendJSON, input.FeeToleranceCents, input.TravelScope,
		input.RewardsGoal, input.CreditTier, input.ExistingCardIDs, input.LifeStage).Scan(&questionnaireID)
	if err != nil {
		return domain.RecommendationResult{}, fmt.Errorf("save questionnaire: %w", err)
	}

	categories, goal, target := questionnaireProfile(input, result)
	_, err = tx.Exec(ctx, `
INSERT INTO revocred.profiles (
	user_id, credit_card_strategy, goal, top_spend_categories, next_application_target, rewards_goal, travel_scope
) VALUES ($1, $2, $3, $4, $5, $6, $7)
ON CONFLICT (user_id) DO UPDATE SET
	credit_card_strategy = EXCLUDED.credit_card_strategy,
	goal = EXCLUDED.goal,
    top_spend_categories = EXCLUDED.top_spend_categories,
    next_application_target = EXCLUDED.next_application_target,
    rewards_goal = EXCLUDED.rewards_goal,
    travel_scope = EXCLUDED.travel_scope,
    updated_at = now()`, userID, result.StrategyCode, goal, categories, target, input.RewardsGoal, input.TravelScope)
	if err != nil {
		return domain.RecommendationResult{}, fmt.Errorf("update profile from questionnaire: %w", err)
	}

	exclusionsJSON, err := json.Marshal(result.Exclusions)
	if err != nil {
		return domain.RecommendationResult{}, fmt.Errorf("encode recommendation exclusions: %w", err)
	}
	snapshotJSON, err := json.Marshal(result.CatalogSnapshot)
	if err != nil {
		return domain.RecommendationResult{}, err
	}
	err = tx.QueryRow(ctx, `
INSERT INTO revocred.recommendation_runs (
    user_id, questionnaire_response_id, engine_version, dataset_version, exclusions, catalog_snapshot
) VALUES ($1, $2, $3, $4, $5, $6)
RETURNING id::text, created_at`, userID, questionnaireID, result.EngineVersion,
		result.DatasetVersion, exclusionsJSON, snapshotJSON).Scan(&result.RunID, &result.CreatedAt)
	if err != nil {
		return domain.RecommendationResult{}, fmt.Errorf("save recommendation run: %w", err)
	}

	for _, item := range result.Items {
		reasonsJSON, marshalErr := json.Marshal(item.Reasons)
		if marshalErr != nil {
			return domain.RecommendationResult{}, fmt.Errorf("encode recommendation reasons: %w", marshalErr)
		}
		_, err = tx.Exec(ctx, `
INSERT INTO revocred.recommendation_items (
    recommendation_run_id, catalog_card_id, rank, score,
    first_year_estimate_cents, ongoing_annual_estimate_cents, reasons
) VALUES ($1, $2, $3, $4, $5, $6, $7)`, result.RunID, item.CardID, item.Rank, item.Score,
			item.FirstYearEstimate, item.OngoingEstimate, reasonsJSON)
		if err != nil {
			return domain.RecommendationResult{}, fmt.Errorf("save recommendation item: %w", err)
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return domain.RecommendationResult{}, fmt.Errorf("commit recommendation: %w", err)
	}
	return result, nil
}

func questionnaireProfile(input domain.RecommendationInput, result domain.RecommendationResult) ([]string, string, string) {
	type categorySpend struct {
		category string
		spend    int64
	}
	spending := make([]categorySpend, 0, len(input.MonthlyCategorySpend))
	for category, spend := range input.MonthlyCategorySpend {
		if spend > 0 {
			spending = append(spending, categorySpend{category: category, spend: spend})
		}
	}
	sort.Slice(spending, func(i, j int) bool {
		if spending[i].spend == spending[j].spend {
			return spending[i].category < spending[j].category
		}
		return spending[i].spend > spending[j].spend
	})
	if len(spending) > 3 {
		spending = spending[:3]
	}
	categories := make([]string, len(spending))
	for i, item := range spending {
		categories[i] = item.category
	}
	goal := "Build a stronger " + strings.ReplaceAll(input.RewardsGoal, "_", " ") + " wallet"
	target := ""
	if len(result.Items) > 0 {
		target = result.Items[0].CardName
	}
	return categories, goal, target
}

// The same ranked server result supplies profile, playbook and chat guidance.
func applyRecommendation(playbook *strategy.Playbook, result *domain.RecommendationResult) {
	playbook.NextCard = ""
	// A card outside a thematic playbook may still be best for some spending.
	playbook.Unused = []strategy.UnusedCard{}
	eligible := map[string]bool{}
	if result != nil {
		for _, item := range result.Items {
			eligible[item.CardName] = true
		}
		if len(result.Items) > 0 {
			playbook.NextCard = result.Items[0].CardName
		}
	}
	found := false
	for i := range playbook.Steps {
		step := &playbook.Steps[i]
		if step.Status == "have" {
			continue
		}
		step.Status = "later"
		if !eligible[step.Name] {
			step.Status = "unavailable"
			step.Note = "Not currently eligible or no positive modeled wallet improvement."
		}
		if step.Name == playbook.NextCard {
			step.Status = "next"
			found = true
		}
	}
	if playbook.NextCard != "" && !found {
		playbook.Steps = append(playbook.Steps, strategy.PlaybookStep{Name: playbook.NextCard, Status: "next", Use: "Highest-ranked eligible improvement for your current wallet."})
	}
}

func walletNames(wallet []domain.WalletCard) []string {
	names := make([]string, 0, len(wallet))
	for _, item := range wallet {
		if item.Status != "active" || item.Card == nil {
			continue
		}
		names = append(names, item.Card.Name)
	}
	return names
}

func playbookPrefs(input *domain.RecommendationInput) *strategy.Preferences {
	if input == nil {
		return nil
	}
	return &strategy.Preferences{
		CreditTier:        input.CreditTier,
		Goal:              strategy.Goal(input.RewardsGoal),
		FeeToleranceCents: input.FeeToleranceCents,
		Travel:            strategy.Travel(input.TravelScope),
	}
}

func (p *Postgres) latestQuestionnaire(ctx context.Context, userID string) (*domain.RecommendationInput, error) {
	var input domain.RecommendationInput
	var spendJSON []byte
	err := p.pool.QueryRow(ctx, `
SELECT monthly_category_spend, fee_tolerance_cents, travel_scope, rewards_goal,
       credit_tier, existing_card_ids, life_stage
FROM revocred.questionnaire_responses
WHERE user_id = $1 ORDER BY created_at DESC, id DESC LIMIT 1`, userID).Scan(
		&spendJSON, &input.FeeToleranceCents, &input.TravelScope, &input.RewardsGoal,
		&input.CreditTier, &input.ExistingCardIDs, &input.LifeStage,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("get latest questionnaire: %w", err)
	}
	if err := json.Unmarshal(spendJSON, &input.MonthlyCategorySpend); err != nil {
		return nil, fmt.Errorf("decode latest questionnaire spend: %w", err)
	}
	return &input, nil
}

func (p *Postgres) latestRecommendation(ctx context.Context, userID string) (*domain.RecommendationResult, error) {
	var result domain.RecommendationResult
	var exclusionsJSON []byte
	err := p.pool.QueryRow(ctx, `
SELECT id::text, engine_version, dataset_version, exclusions, created_at
FROM revocred.recommendation_runs WHERE user_id = $1 ORDER BY created_at DESC, id DESC LIMIT 1`, userID).Scan(
		&result.RunID, &result.EngineVersion, &result.DatasetVersion, &exclusionsJSON, &result.CreatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("get latest recommendation: %w", err)
	}
	if err := json.Unmarshal(exclusionsJSON, &result.Exclusions); err != nil {
		return nil, fmt.Errorf("decode recommendation exclusions: %w", err)
	}
	rows, err := p.pool.Query(ctx, `
SELECT ri.catalog_card_id::text, c.slug, c.name, ri.score,
       ri.first_year_estimate_cents, ri.ongoing_annual_estimate_cents, ri.reasons, ri.rank
FROM revocred.recommendation_items ri
JOIN revocred.catalog_cards c ON c.id = ri.catalog_card_id
WHERE ri.recommendation_run_id = $1 ORDER BY ri.rank`, result.RunID)
	if err != nil {
		return nil, fmt.Errorf("list recommendation items: %w", err)
	}
	defer rows.Close()
	result.Items = make([]domain.RecommendationItem, 0)
	for rows.Next() {
		var item domain.RecommendationItem
		var reasonsJSON []byte
		if err := rows.Scan(&item.CardID, &item.CardSlug, &item.CardName, &item.Score,
			&item.FirstYearEstimate, &item.OngoingEstimate, &reasonsJSON, &item.Rank); err != nil {
			return nil, fmt.Errorf("scan recommendation item: %w", err)
		}
		if err := json.Unmarshal(reasonsJSON, &item.Reasons); err != nil {
			return nil, fmt.Errorf("decode recommendation reasons: %w", err)
		}
		result.Items = append(result.Items, item)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate recommendation items: %w", err)
	}
	return &result, nil
}

func (p *Postgres) ListMessages(ctx context.Context, userID string, limit int) ([]domain.ChatMessage, error) {
	rows, err := p.pool.Query(ctx, `
SELECT id::text, role, content, created_at FROM (
    SELECT id, role, content, created_at, sequence
    FROM revocred.chat_messages WHERE user_id = $1
    ORDER BY sequence DESC LIMIT $2
) recent ORDER BY sequence`, userID, limit)
	if err != nil {
		return nil, fmt.Errorf("list chat messages: %w", err)
	}
	defer rows.Close()
	messages := make([]domain.ChatMessage, 0)
	for rows.Next() {
		var message domain.ChatMessage
		if err := rows.Scan(&message.ID, &message.Role, &message.Content, &message.CreatedAt); err != nil {
			return nil, fmt.Errorf("scan chat message: %w", err)
		}
		messages = append(messages, message)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate chat messages: %w", err)
	}
	return messages, nil
}

func (p *Postgres) AppendChatExchange(ctx context.Context, userID, prompt, reply string) ([]domain.ChatMessage, error) {
	tx, err := p.pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return nil, fmt.Errorf("begin chat transaction: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	messages := make([]domain.ChatMessage, 2)
	for i, message := range []struct{ role, content string }{{"user", prompt}, {"assistant", reply}} {
		err := tx.QueryRow(ctx, `
INSERT INTO revocred.chat_messages (user_id, role, content) VALUES ($1, $2, $3)
RETURNING id::text, role, content, created_at`, userID, message.role, message.content).Scan(
			&messages[i].ID, &messages[i].Role, &messages[i].Content, &messages[i].CreatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("save %s message: %w", message.role, err)
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit chat exchange: %w", err)
	}
	return messages, nil
}
