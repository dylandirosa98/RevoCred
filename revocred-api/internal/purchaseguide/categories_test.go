package purchaseguide

import (
	"github.com/revocred/revocred-api/internal/domain"
	"testing"
)

func TestSpecificCategoryRulesAndRestrictedBonuses(t *testing.T) {
	cases := []struct {
		category, bonus, winner string
		rate                    float64
	}{
		{"gas", "us-citi-strata", "us-citi-strata", 3},
		{"transit", "us-citi-strata", "us-citi-strata", 3},
		{"streaming", "us-capital-one-savorone", "us-capital-one-savorone", 3},
		{"entertainment", "us-capital-one-savor-student-cash-rewards", "us-capital-one-savor-student-cash-rewards", 3},
		{"drugstores", "us-chase-freedom-flex", "us-chase-freedom-flex", 3},
		{"streaming", "us-citi-strata", "us-capital-one-venture-x", 2},
		{"dining", "us-chase-freedom-rise", "us-capital-one-venture-x", 2},
		{"dining", "us-citi-strata-elite", "us-citi-strata-elite", 3},
	}
	for _, tc := range cases {
		t.Run(tc.category+"/"+tc.bonus, func(t *testing.T) {
			g := category(t, Build([]domain.WalletCard{sourceCard(t, tc.bonus), sourceCard(t, "us-capital-one-venture-x")}, DefaultOptions()), tc.category)
			if g.Options[0].CardID != tc.winner || g.Options[0].Rate != tc.rate {
				t.Fatalf("winner %+v, want %s at %g", g.Options[0], tc.winner, tc.rate)
			}
		})
	}
}
