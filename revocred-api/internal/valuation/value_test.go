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

func TestHotelCashEquivalentValue(t *testing.T) {
	hotel := domain.CatalogCard{ID: "hotel", PointValueCents: .5, RewardRates: map[string]float64{"other": 3, "dining": 5}}
	gold := domain.CatalogCard{ID: "gold", RewardRates: map[string]float64{"other": 1, "dining": 4}}
	spend := map[string]int64{"dining": 10000, "everyday": 10000}
	if CardRate(hotel, "dining") != 2.5 || CardRate(gold, "dining") != 4 {
		t.Fatal("incorrect cash comparison")
	}
	if got := Gross(spend, []domain.CatalogCard{hotel}); got != 4800 {
		t.Fatalf("hotel gross = %d", got)
	}
	cards := []domain.CatalogCard{hotel, gold}
	if got := Net(spend, cards); got != 6600 {
		t.Fatalf("net = %d", got)
	}
	if got := Ongoing(spend, cards, "none").RewardsCents; got != 6600 {
		t.Fatalf("ongoing = %d", got)
	}
}
