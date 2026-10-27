package purchaseguide

import (
	"encoding/json"
	"os"
	"strings"
	"testing"

	"github.com/revocred/revocred-api/internal/carddata"
	"github.com/revocred/revocred-api/internal/domain"
)

func TestCapsExhaustedAndNoActivationAssumptions(t *testing.T) {
	w := exampleWallet(t)
	w = append(w, sourceCard(t, "us-chase-freedom-flex"))
	settings := DefaultOptions()
	settings.CapsAvailable = false
	g := category(t, Build(w, settings), "groceries")
	if g.Options[0].CardID != "quicksilver" || g.Options[0].Rate != 1.5 {
		t.Fatalf("capped/rotating bonus wrongly assumed: %+v", g.Options[0])
	}
	if len(g.Conditional) == 0 {
		t.Fatal("missing explanation of conditional bonuses")
	}
}
func TestUnknownInactiveDuplicatesAndTies(t *testing.T) {
	w := exampleWallet(t)
	w[0].Card.TermsUnknown = true
	w[1].Status = "inactive"
	w = append(w, w[2])
	g := category(t, Build(w, DefaultOptions()), "dining")
	if len(g.Options) != 1 || g.Options[0].CardID != "quicksilver" || len(g.Unknown) == 0 {
		t.Fatal("unsafe wallet candidates")
	}
	a := domain.WalletCard{Status: "active", Card: &domain.CatalogCard{ID: "a", Name: "Same", RewardRates: map[string]float64{"other": 2}}}
	b := domain.WalletCard{Status: "active", Card: &domain.CatalogCard{ID: "b", Name: "Same", RewardRates: map[string]float64{"other": 2}}}
	g = category(t, Build([]domain.WalletCard{b, a}, DefaultOptions()), "online-shopping")
	if !g.Tied || g.Options[0].CardID != "a" {
		t.Fatal("tie handling is unstable")
	}
}
func TestSourceRatesAreReadNotHardcoded(t *testing.T) {
	w := exampleWallet(t)
	rate := 7.0
	w[0].Card.CommunityData.Rewards.Categories[0].PointsPerDollar = &rate
	g := category(t, Build(w, DefaultOptions()), "dining")
	if g.Options[0].Rate != 7 {
		t.Fatal("source rate was replaced by a hardcoded value")
	}
}
func TestUnreviewedSourceRuleIsFlaggedAndNeverInferred(t *testing.T) {
	w := exampleWallet(t)
	w[0].Card.CommunityData.Rewards.Categories = append(w[0].Card.CommunityData.Rewards.Categories, carddata.Category{Label: "New ambiguous bonus rule"})
	g := category(t, Build(w, DefaultOptions()), "online-shopping")
	if len(g.Unknown) == 0 || !strings.Contains(strings.Join(g.Unknown, " "), "unreviewed") {
		t.Fatal("partial source coverage was hidden")
	}
	if g.Options[0].CardID != "quicksilver" {
		t.Fatal("ambiguous rule affected ranking")
	}
}
func TestExplicitRentRuleDoesNotRequireACatchallRate(t *testing.T) {
	w := []domain.WalletCard{{Status: "active", Card: &domain.CatalogCard{ID: "rent", Name: "Explicit rent terms", RewardRates: map[string]float64{"rent": 1}}}}
	g := category(t, Build(w, DefaultOptions()), "rent")
	if len(g.Options) != 1 || g.Options[0].Rate != 1 {
		t.Fatal("explicit rent terms lost")
	}
}
func TestKnownCategoryWorksWithoutInventingMissingBaseRate(t *testing.T) {
	w := []domain.WalletCard{{Status: "active", Card: &domain.CatalogCard{ID: "custom", Name: "Custom dining card", RewardRates: map[string]float64{"dining": 4}}}}
	guides := Build(w, DefaultOptions())
	dining := category(t, guides, "dining")
	if len(dining.Options) != 1 || dining.Options[0].Rate != 4 {
		t.Fatal("explicit dining rate ignored")
	}
	if len(category(t, guides, "online-shopping").Options) != 0 {
		t.Fatal("missing catch-all rate guessed")
	}
}

func TestEveryCurrentFeedRuleHasAnExplicitReviewedScope(t *testing.T) {
	raw, _ := os.ReadFile("../carddata/testdata/cards.json")
	var cards []carddata.Card
	if err := json.Unmarshal(raw, &cards); err != nil {
		t.Fatal(err)
	}
	for _, c := range cards {
		for _, r := range c.Rewards.Categories {
			if _, ok := reviewed[c.ID][r.Label]; ok {
				continue
			}
			if _, ok := travelReviewed[c.ID][r.Label]; ok {
				continue
			}
			if _, ok := categoryReviewed[c.ID][r.Label]; ok {
				continue
			}
			t.Errorf("unreviewed fixture rule %s / %s", c.ID, r.Label)
		}
	}
}
