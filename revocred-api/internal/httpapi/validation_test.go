package httpapi

import (
	"testing"

	"github.com/revocred/revocred-api/internal/domain"
)

func TestValidateRecommendation(t *testing.T) {
	valid := domain.RecommendationInput{
		MonthlyCategorySpend: map[string]int64{"dining": 25000},
		FeeToleranceCents:    9500,
		TravelScope:          "both",
		RewardsGoal:          "travel",
		CreditTier:           "good",
		ExistingCardIDs:      []string{"travel-starter-demo"},
		IdealCardCount:       "2-3",
	}
	if errors := validateRecommendation(valid); len(errors) != 0 {
		t.Fatalf("valid input rejected: %#v", errors)
	}
	for _, count := range []string{"1-2", "2-4", "4+", "2-3", "3-4"} {
		input := valid
		input.IdealCardCount = count
		if fields := validateRecommendation(input); len(fields) != 0 {
			t.Fatalf("wallet size %s rejected: %#v", count, fields)
		}
	}

	unknownCategory := valid
	unknownCategory.MonthlyCategorySpend = map[string]int64{"spaceships": 100}
	if errors := validateRecommendation(unknownCategory); errors["monthly_category_spend"] == "" {
		t.Fatalf("unknown category accepted: %#v", errors)
	}

	invalid := valid
	invalid.MonthlyCategorySpend = map[string]int64{"dining": -1}
	invalid.FeeToleranceCents = -1
	invalid.TravelScope = "global"
	invalid.RewardsGoal = "points"
	invalid.CreditTier = "unknown"
	invalid.IdealCardCount = "ten"
	errors := validateRecommendation(invalid)
	for _, field := range []string{"monthly_category_spend", "fee_tolerance_cents", "ideal_card_count", "travel_scope", "rewards_goal", "credit_tier"} {
		if _, ok := errors[field]; !ok {
			t.Errorf("expected error for %s: %#v", field, errors)
		}
	}
}

func TestValidateProfileAndWallet(t *testing.T) {
	if errors := validateProfile(domain.Profile{RewardsGoal: "miles", TravelScope: "space"}); len(errors) != 2 {
		t.Fatalf("expected profile enum errors: %#v", errors)
	}
	if errors := validateWalletCard(domain.CreateWalletCard{CatalogCardID: "not-a-uuid", Status: "lost"}); len(errors) != 2 {
		t.Fatalf("expected wallet errors: %#v", errors)
	}
}

func TestValidateCustomCardAllowsExplicitlyUnknownTerms(t *testing.T) {
	card := domain.CreateCustomCard{
		Name:              "Atmos Rewards Ascent Visa Signature",
		Issuer:            "Bank of America",
		Network:           "Visa",
		TravelScope:       "none",
		RewardsType:       "cash_back",
		MinimumCreditTier: "good",
		TermsUnknown:      true,
	}
	if errors := validateCustomCard(card); len(errors) != 0 {
		t.Fatalf("identity-only card rejected: %#v", errors)
	}
	card.TermsUnknown = false
	if errors := validateCustomCard(card); errors["reward_rates"] == "" {
		t.Fatalf("known terms without rates accepted: %#v", errors)
	}
}
