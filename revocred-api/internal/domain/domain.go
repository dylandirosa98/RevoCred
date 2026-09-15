package domain

import "time"

type Profile struct {
	UserID                string    `json:"user_id,omitempty"`
	DisplayName           string    `json:"display_name"`
	CreditCardStrategy    string    `json:"credit_card_strategy"`
	Goal                  string    `json:"goal"`
	TopSpendCategories    []string  `json:"top_spend_categories"`
	NextApplicationTarget string    `json:"next_application_target"`
	RewardsGoal           string    `json:"rewards_goal"`
	TravelScope           string    `json:"travel_scope"`
	CreatedAt             time.Time `json:"created_at,omitempty"`
	UpdatedAt             time.Time `json:"updated_at,omitempty"`
}

type CatalogCard struct {
	ID                    string             `json:"id"`
	Slug                  string             `json:"slug"`
	Issuer                string             `json:"issuer"`
	Network               string             `json:"network"`
	Name                  string             `json:"name"`
	Summary               string             `json:"summary"`
	BestUse               string             `json:"best_use"`
	AnnualFeeCents        int                `json:"annual_fee_cents"`
	RewardRates           map[string]float64 `json:"reward_rates"`
	Benefits              []string           `json:"benefits"`
	TransferablePoints    bool               `json:"transferable_points"`
	TravelScope           string             `json:"travel_scope"`
	MinimumCreditTier     string             `json:"minimum_credit_tier"`
	RewardsType           string             `json:"rewards_type"`
	FirstYearBonusCents   int                `json:"first_year_bonus_estimate_cents"`
	AnnualBenefitValue    int                `json:"annual_benefit_estimate_cents"`
	DatasetVersion        string             `json:"dataset_version"`
	SourceName            string             `json:"source_name"`
	SourceURL             string             `json:"source_url,omitempty"`
	SourceDisclaimer      string             `json:"source_disclaimer"`
	SourcePublishedAt     *time.Time         `json:"source_published_at,omitempty"`
	CatalogVersionCreated time.Time          `json:"catalog_version_created_at,omitempty"`
}

type WalletCard struct {
	ID            string       `json:"id"`
	UserID        string       `json:"user_id,omitempty"`
	CatalogCardID string       `json:"catalog_card_id"`
	Nickname      string       `json:"nickname"`
	Status        string       `json:"status"`
	OpenedOn      *time.Time   `json:"opened_on,omitempty"`
	CreatedAt     time.Time    `json:"created_at"`
	Card          *CatalogCard `json:"card,omitempty"`
}

type CreateWalletCard struct {
	CatalogCardID string     `json:"catalog_card_id"`
	Nickname      string     `json:"nickname"`
	Status        string     `json:"status"`
	OpenedOn      *time.Time `json:"opened_on,omitempty"`
}

type RecommendationInput struct {
	MonthlyCategorySpend map[string]int64 `json:"monthly_category_spend"`
	FeeToleranceCents    int              `json:"fee_tolerance_cents"`
	TravelScope          string           `json:"travel_scope"`
	RewardsGoal          string           `json:"rewards_goal"`
	CreditTier           string           `json:"credit_tier"`
	ExistingCardIDs      []string         `json:"existing_card_ids"`
}

type RecommendationItem struct {
	CardID            string   `json:"card_id"`
	CardSlug          string   `json:"card_slug"`
	CardName          string   `json:"card_name"`
	Score             float64  `json:"score"`
	FirstYearEstimate int64    `json:"first_year_estimate_cents"`
	OngoingEstimate   int64    `json:"ongoing_annual_estimate_cents"`
	Reasons           []string `json:"reasons"`
	Rank              int      `json:"rank"`
}

type RecommendationExclusion struct {
	CardID   string `json:"card_id"`
	CardSlug string `json:"card_slug"`
	Reason   string `json:"reason"`
}

type RecommendationResult struct {
	RunID          string                    `json:"run_id,omitempty"`
	EngineVersion  string                    `json:"engine_version"`
	DatasetVersion string                    `json:"dataset_version"`
	Items          []RecommendationItem      `json:"items"`
	Exclusions     []RecommendationExclusion `json:"exclusions"`
	CreatedAt      time.Time                 `json:"created_at,omitempty"`
}

type ChatMessage struct {
	ID        string    `json:"id"`
	Role      string    `json:"role"`
	Content   string    `json:"content"`
	CreatedAt time.Time `json:"created_at"`
}

type WalletMetrics struct {
	Score       int    `json:"score"`
	Rating      string `json:"rating"`
	Additions   int    `json:"additions"`
	Penalties   int    `json:"penalties"`
	YearlyValue int    `json:"yearly_value"`
}

type Bootstrap struct {
	Catalog               []CatalogCard         `json:"catalog"`
	Profile               *Profile              `json:"profile"`
	Wallet                []WalletCard          `json:"wallet"`
	LatestRecommendations *RecommendationResult `json:"latest_recommendations,omitempty"`
	LatestQuestionnaire   *RecommendationInput  `json:"latest_questionnaire,omitempty"`
	WalletMetrics         WalletMetrics         `json:"wallet_metrics"`
	QuickPrompts          []string              `json:"quick_prompts"`
}
