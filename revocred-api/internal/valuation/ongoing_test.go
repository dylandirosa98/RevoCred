package valuation

import (
	"github.com/revocred/revocred-api/internal/carddata"
	"github.com/revocred/revocred-api/internal/domain"
	"testing"
)

func venture() domain.CatalogCard {
	return domain.CatalogCard{ID: "20000000-0000-4000-8000-000000000015", AnnualFeeCents: 39500, RewardRates: map[string]float64{"other": 2}, CommunityData: &carddata.Details{ID: "us-capital-one-venture-x", Benefits: []string{"$300 Capital One Travel credit — $300 annual credit for hotels, flights, vacation rentals and related Capital One Travel purchases.", "10,000 anniversary bonus miles — Earn 10,000 bonus miles after each account anniversary, starting with the first."}}}
}
func TestOngoingFailsClosed(t *testing.T) {
	for _, tc := range []struct {
		name, scope          string
		spend                map[string]int64
		modify               func(*domain.CatalogCard)
		credits, anniversary int64
	}{
		{"no travel", "none", map[string]int64{"everyday": 120000}, func(c *domain.CatalogCard) {}, 0, 10000},
		{"no travel budget", "both", map[string]int64{}, func(c *domain.CatalogCard) {}, 0, 10000},
		{"missing source", "both", map[string]int64{"travel": 20000}, func(c *domain.CatalogCard) { c.CommunityData = nil }, 0, 0},
		{"changed source", "both", map[string]int64{"travel": 20000}, func(c *domain.CatalogCard) { c.CommunityData.Benefits[0] += " changed" }, 0, 10000},
		{"custom", "both", map[string]int64{"travel": 20000}, func(c *domain.CatalogCard) { c.ID = "custom" }, 0, 0},
	} {
		t.Run(tc.name, func(t *testing.T) {
			c := venture()
			tc.modify(&c)
			got := Ongoing(tc.spend, []domain.CatalogCard{c}, tc.scope)
			if got.CreditsCents != tc.credits || got.AnniversaryCents != tc.anniversary {
				t.Fatalf("%+v", got)
			}
		})
	}
}
func TestOngoingDuplicateEvidence(t *testing.T) {
	c := venture()
	c.CommunityData.Benefits = append(c.CommunityData.Benefits, c.CommunityData.Benefits...)
	got := Ongoing(map[string]int64{"travel": 20000}, []domain.CatalogCard{c, c}, "both")
	if got.CreditsCents != 21000 || got.AnniversaryCents != 10000 || got.FeesCents != 39500 {
		t.Fatalf("duplicate product counted: %+v", got)
	}
}
func TestOngoingNoFee(t *testing.T) {
	got := Ongoing(map[string]int64{"everyday": 100000}, []domain.CatalogCard{{RewardRates: map[string]float64{"other": 2}}}, "none")
	if got.TotalCents != 24000 {
		t.Fatalf("%+v", got)
	}
}
func TestOngoingVenture(t *testing.T) {
	c := venture()
	spend := map[string]int64{"everyday": 100000, "travel": 20000}
	got := Ongoing(spend, []domain.CatalogCard{c}, "both")
	if got.TotalCents != 20300 || got.CreditsCents != 21000 || got.AnniversaryCents != 10000 || got.RewardsCents != 28800 || got.FeesCents != 39500 {
		t.Fatalf("breakdown: %+v", got)
	}
	if Net(spend, []domain.CatalogCard{c}) != -10700 {
		t.Fatal("ranking Net semantics changed")
	}
}
