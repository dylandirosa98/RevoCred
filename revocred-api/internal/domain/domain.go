package domain

import (
	"encoding/json"
	"time"

	"github.com/revocred/revocred-api/internal/carddata"
	"github.com/revocred/revocred-api/internal/strategy"
)

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
	// Community data remains reference-only for scoring, eligibility and card
	// selection. Wallet-only Ongoing uses bounded, reviewed exact-text adapters;
	// unreviewed prose must never be interpreted automatically as cash value.
	CommunityData       *carddata.Details  `json:"community_data,omitempty"`
	ID                  string             `json:"id"`
	Slug                string             `json:"slug"`
	Issuer              string             `json:"issuer"`
	Network             string             `json:"network"`
	Name                string             `json:"name"`
	Summary             string             `json:"summary"`
	BestUse             string             `json:"best_use"`
	AnnualFeeCents      int                `json:"annual_fee_cents"`
	RewardRates         map[string]float64 `json:"reward_rates"`
	Benefits            []string           `json:"benefits"`
	TransferablePoints  bool               `json:"transferable_points"`
	TravelScope         string             `json:"travel_scope"`
	MinimumCreditTier   string             `json:"minimum_credit_tier"`
	RewardsType         string             `json:"rewards_type"`
	FirstYearBonusCents int                `json:"first_year_bonus_estimate_cents"`
	AnnualBenefitValue  int                `json:"annual_benefit_estimate_cents"`
	DatasetVersion      string             `json:"dataset_version"`
	// True only when a user explicitly declined to supply terms. Such a card is
	// shown as owned but must not be scored, because an absent rate is not a
	// low rate. Inverted so an unset value keeps the card in the math.
	TermsUnknown          bool       `json:"terms_unknown"`
	SourceName            string     `json:"source_name"`
	SourceURL             string     `json:"source_url,omitempty"`
	SourceDisclaimer      string     `json:"source_disclaimer"`
	SourcePublishedAt     *time.Time `json:"source_published_at,omitempty"`
	CatalogVersionCreated time.Time  `json:"catalog_version_created_at,omitempty"`
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

type CreateCustomCard struct {
	Name               string             `json:"name"`
	Issuer             string             `json:"issuer"`
	Network            string             `json:"network"`
	AnnualFeeCents     int                `json:"annual_fee_cents"`
	RewardRates        map[string]float64 `json:"reward_rates"`
	TransferablePoints bool               `json:"transferable_points"`
	BestUse            string             `json:"best_use"`
	Benefits           []string           `json:"benefits"`
	TravelScope        string             `json:"travel_scope"`
	RewardsType        string             `json:"rewards_type"`
	MinimumCreditTier  string             `json:"minimum_credit_tier"`
	Nickname           string             `json:"nickname"`
	// TermsUnknown is true only when the user explicitly skipped terms.
	TermsUnknown bool `json:"terms_unknown,omitempty"`
}

// OnboardingCard is a card chosen from the search-only reference index during
// onboarding. Supplying terms is optional; skipping keeps the card out of
// scoring and out of the recommendation inputs.
type OnboardingCard struct {
	ReferenceID    string             `json:"reference_id"`
	IncludeTerms   bool               `json:"include_terms"`
	AnnualFeeCents int                `json:"annual_fee_cents"`
	RewardRates    map[string]float64 `json:"reward_rates"`
	Transferable   bool               `json:"transferable_points"`
	BestUse        string             `json:"best_use"`
	MinimumTier    string             `json:"minimum_credit_tier"`
}

// Substitution names an approved stand-in for a strategy role. It is only used
// when the person already owns that stand-in.
type Substitution struct {
	CardID string `json:"card_id"`
	Name   string `json:"name"`
}

// ReferenceCard is one search result. It carries dated public terms so a user
// can accept them in one tap, and it is never a recommendation candidate.
type ReferenceCard struct {
	ID               string             `json:"id"`
	Slug             string             `json:"slug"`
	Issuer           string             `json:"issuer"`
	Name             string             `json:"name"`
	Network          string             `json:"network"`
	RewardsType      string             `json:"rewards_type"`
	AnnualFeeCents   int                `json:"annual_fee_cents"`
	RewardRates      map[string]float64 `json:"reward_rates"`
	TermsStatus      string             `json:"terms_status"`
	SourceURL        string             `json:"source_url"`
	SourceCapturedOn string             `json:"source_captured_on"`
	Disclaimer       string             `json:"disclaimer"`
	// CatalogCardID is set when this product is already in the vetted catalog,
	// so choosing it keeps the sourced terms instead of a user copy.
	CatalogCardID string `json:"catalog_card_id,omitempty"`
}

type RecommendationInput struct {
	LifeStage            string           `json:"life_stage,omitempty"`
	OwnedCards           []CatalogCard    `json:"-"`
	MonthlyCategorySpend map[string]int64 `json:"monthly_category_spend"`
	FeeToleranceCents    int              `json:"fee_tolerance_cents"`
	IdealCardCount       string           `json:"ideal_card_count,omitempty"`
	TravelScope          string           `json:"travel_scope"`
	RewardsGoal          string           `json:"rewards_goal"`
	CreditTier           string           `json:"credit_tier"`
	ExistingCardIDs      []string         `json:"existing_card_ids"`
	AddedCards           []OnboardingCard `json:"added_cards,omitempty"`
	// DisplayName is captured at sign-up and saved with the plan, so the
	// greeting is never a hardcoded placeholder.
	DisplayName string `json:"display_name,omitempty"`
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
	CatalogSnapshot []CatalogCard             `json:"catalog_snapshot"`
	RunID           string                    `json:"run_id,omitempty"`
	StrategyCode    string                    `json:"strategy_code"`
	EngineVersion   string                    `json:"engine_version"`
	DatasetVersion  string                    `json:"dataset_version"`
	Items           []RecommendationItem      `json:"items"`
	Exclusions      []RecommendationExclusion `json:"exclusions"`
	CreatedAt       time.Time                 `json:"created_at,omitempty"`
}

type ChatMessage struct {
	ID      string `json:"id"`
	Role    string `json:"role"`
	Content string `json:"content"`
	// Blocks is the resolved structured reply the app renders. It may be empty
	// for older messages, which then render as plain text.
	Blocks    json.RawMessage `json:"blocks,omitempty"`
	CreatedAt time.Time       `json:"created_at"`
}

// OngoingValue is wallet-only. Recommendation Net remains rewards less fees.
type OngoingValue struct {
	ModelVersion     string         `json:"model_version"`
	RewardsCents     int64          `json:"rewards_cents"`
	CreditsCents     int64          `json:"credits_cents"`
	AnniversaryCents int64          `json:"anniversary_cents"`
	FeesCents        int64          `json:"fees_cents"`
	TotalCents       int64          `json:"total_cents"`
	Benefits         []BenefitValue `json:"benefits"`
	Assumptions      []string       `json:"assumptions"`
}
type BenefitValue struct {
	SourceVerifiedOn string `json:"source_verified_on"`
	SnapshotSHA256   string `json:"snapshot_sha256"`
	CatalogVersion   string `json:"catalog_version"`
	CardID           string `json:"card_id"`
	CardName         string `json:"card_name"`
	ID               string `json:"id"`
	Title            string `json:"title"`
	Kind             string `json:"kind"`
	FaceCents        int64  `json:"face_cents"`
	EstimatedCents   int64  `json:"estimated_cents"`
	Frequency        string `json:"frequency"`
	Conditions       string `json:"conditions"`
	SourceURL        string `json:"source_url"`
	ReviewedOn       string `json:"reviewed_on"`
	EvidenceVersion  string `json:"evidence_version"`
	Status           string `json:"status"`
}

type WalletMetrics struct {
	OngoingValue OngoingValue `json:"ongoing_value"`
	Score        int          `json:"score"`
	Rating       string       `json:"rating"`
	Additions    int          `json:"additions"`
	Penalties    int          `json:"penalties"`
	YearlyValue  int          `json:"yearly_value"`
}

type Bootstrap struct {
	Catalog               []CatalogCard         `json:"catalog"`
	Profile               *Profile              `json:"profile"`
	Wallet                []WalletCard          `json:"wallet"`
	LatestRecommendations *RecommendationResult `json:"latest_recommendations,omitempty"`
	LatestQuestionnaire   *RecommendationInput  `json:"latest_questionnaire,omitempty"`
	WalletMetrics         WalletMetrics         `json:"wallet_metrics"`
	Playbook              *strategy.Playbook    `json:"playbook,omitempty"`
	QuickPrompts          []string              `json:"quick_prompts"`
	ChatMode              string                `json:"chat_mode,omitempty"`
}
