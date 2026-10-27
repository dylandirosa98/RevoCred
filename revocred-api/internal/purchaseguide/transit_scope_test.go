package purchaseguide

import (
	"github.com/revocred/revocred-api/internal/domain"
	"testing"
)

func TestReviewedTravelAndTransitScope(t *testing.T) {
	for _, tc := range []struct {
		product, category string
		rate              float64
	}{
		{"us-chase-sapphire-preferred", "transit", 2},
		{"us-chase-sapphire-preferred", "gas", 1},
		{"us-chase-sapphire-reserve", "transit", 1},
		{"us-chase-freedom-flex", "transit", 1},
		{"us-chase-freedom-unlimited", "transit", 1.5},
		{"us-citi-strata", "transit", 3},
		{"us-amex-gold", "travel", 1},
	} {
		t.Run(tc.product+"/"+tc.category, func(t *testing.T) {
			g := category(t, Build([]domain.WalletCard{sourceCard(t, tc.product)}, DefaultOptions()), tc.category)
			if len(g.Options) != 1 || g.Options[0].Rate != tc.rate {
				t.Fatalf("unexpected scope: %+v", g.Options)
			}
		})
	}
}
