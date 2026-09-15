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
	}
	if errors := validateRecommendation(valid); len(errors) != 0 {
		t.Fatalf("valid input rejected: %#v", errors)
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
	errors := validateRecommendation(invalid)
	for _, field := range []string{"monthly_category_spend", "fee_tolerance_cents", "travel_scope", "rewards_goal", "credit_tier"} {
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
