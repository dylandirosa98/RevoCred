package valuation

import (
	"github.com/revocred/revocred-api/internal/domain"
	"testing"
)

func TestConservativeWalletValue(t *testing.T) {
	spend := map[string]int64{"housing": 200000, "food": 50000, "other": 10000}
	cards := []domain.CatalogCard{{AnnualFeeCents: 9500, RewardRates: map[string]float64{"dining": 4, "other": 2}}}
	// Housing earns zero. Unknown food mix earns 2%; $600/month * 12 * .02 - $95 = $49.
	if got := Net(spend, cards); got != 4900 {
		t.Fatalf("got %d, want 4900", got)
	}
	if got := Net(spend, nil); got != 0 {
		t.Fatalf("empty wallet earns %d", got)
	}
}
