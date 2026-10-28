package valuation

import (
	"encoding/json"
	"github.com/revocred/revocred-api/internal/domain"
	"os"
	"testing"
)

func TestReviewedCatalogCoverageAndBudgetOverlap(t *testing.T) {
	raw, err := os.ReadFile("testdata/catalog.json")
	if err != nil {
		t.Fatal(err)
	}
	var cards []domain.CatalogCard
	if err = json.Unmarshal(raw, &cards); err != nil {
		t.Fatal(err)
	}
	if len(cards) != 15 {
		t.Fatalf("catalog coverage=%d", len(cards))
	}
	for _, c := range cards {
		got := Ongoing(map[string]int64{"food": 60000, "travel": 20000, "everyday": 40000}, []domain.CatalogCard{c}, "both")
		if len(got.Benefits) == 0 {
			t.Fatalf("no coverage for %s", c.Slug)
		}
		for _, b := range got.Benefits {
			if b.Status == "missing_data" || b.Status == "source_missing_or_changed" {
				t.Fatalf("unreviewed fixture %s: %+v", c.Slug, b)
			}
		}
	}
	// All travel credits across multiple cards share one budget, not separate
	// assumptions that spend the same dollar repeatedly. Stable regardless of order.
	spend := map[string]int64{"travel": 100}
	got := Ongoing(spend, cards, "both")
	var travelCredits int64
	rules := []benefitRule{}
	_ = json.Unmarshal(reviewedEvidence, &rules)
	categories := map[string]string{}
	for _, r := range rules {
		categories[r.ID] = r.Category
	}
	for _, b := range got.Benefits {
		if b.Kind == "credit" && categories[b.ID] == "travel" {
			travelCredits += b.EstimatedCents
		}
	}
	if travelCredits != 840 {
		t.Fatalf("overlap budget=%d, want 840", travelCredits)
	}
	for i, j := 0, len(cards)-1; i < j; i, j = i+1, j-1 {
		cards[i], cards[j] = cards[j], cards[i]
	}
	again := Ongoing(spend, cards, "both")
	if again.TotalCents != got.TotalCents || again.CreditsCents != got.CreditsCents {
		t.Fatal("input order changed budget allocation")
	}
}

func TestNonCashAndTemporaryPerksAreNeverParsed(t *testing.T) {
	c := venture()
	c.CommunityData.Benefits = []string{"$9999 lounge access", "$100000 welcome bonus", "$300 Capital One Travel credit — changed terms", "Earn $500 each stay through 2025"}
	got := Ongoing(map[string]int64{"travel": 10000}, []domain.CatalogCard{c}, "both")
	if got.CreditsCents != 0 || got.AnniversaryCents != 0 {
		t.Fatalf("parsed marketing prose: %+v", got)
	}
}
