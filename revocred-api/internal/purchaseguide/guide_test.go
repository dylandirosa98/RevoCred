package purchaseguide

import (
	"encoding/json"
	"os"
	"testing"

	"github.com/revocred/revocred-api/internal/carddata"
	"github.com/revocred/revocred-api/internal/domain"
)

func sourceCard(t *testing.T, id string) domain.WalletCard {
	t.Helper()
	raw, err := os.ReadFile("../carddata/testdata/cards.json")
	if err != nil {
		t.Fatal(err)
	}
	var cards []carddata.Card
	if err := json.Unmarshal(raw, &cards); err != nil {
		t.Fatal(err)
	}
	for _, c := range cards {
		if c.ID == id {
			return domain.WalletCard{Status: "active", Card: &domain.CatalogCard{ID: id, Name: c.Name, RewardRates: map[string]float64{"other": 1}, RewardsType: "points", CommunityData: &carddata.Details{ID: id, Rewards: c.Rewards, LastVerified: c.LastVerified, IssuerURL: c.OfficialURL}}}
		}
	}
	t.Fatal("fixture missing", id)
	return domain.WalletCard{}
}
func exampleWallet(t *testing.T) []domain.WalletCard {
	return []domain.WalletCard{
		sourceCard(t, "us-amex-gold"), sourceCard(t, "us-chase-sapphire-reserve"),
		{Status: "active", Card: &domain.CatalogCard{ID: "quicksilver", Name: "Quicksilver", RewardRates: map[string]float64{"other": 1.5}, RewardsType: "cash_back"}},
	}
}
func category(t *testing.T, guides []Category, id string) Category {
	t.Helper()
	for _, g := range guides {
		if g.ID == id {
			return g
		}
	}
	t.Fatal("category missing", id)
	return Category{}
}
func TestEveryHomeCategoryUsesApplicableWalletRates(t *testing.T) {
	guides := Build(exampleWallet(t), DefaultOptions())
	expected := map[string]string{
		"dining": "us-amex-gold", "groceries": "us-amex-gold", "travel": "quicksilver",
		"gas": "quicksilver", "transit": "quicksilver", "online-shopping": "quicksilver",
		"rent": "", "streaming": "quicksilver", "entertainment": "quicksilver",
		"drugstores": "quicksilver", "wholesale-clubs": "quicksilver", "utilities": "quicksilver",
		"phone-and-internet": "quicksilver", "home-improvement": "quicksilver",
		"office-supplies": "quicksilver", "general-purchases": "quicksilver",
	}
	if len(guides) != len(expected) {
		t.Fatalf("home categories missing: got %d want %d", len(guides), len(expected))
	}
	for id, want := range expected {
		got := category(t, guides, id)
		if want == "" {
			if len(got.Options) != 0 {
				t.Fatal("base rewards must not be assumed on rent")
			}
			continue
		}
		if len(got.Options) == 0 || got.Options[0].CardID != want {
			t.Fatalf("%s: got %+v want %s", id, got.Options, want)
		}
	}
}

func TestOnlineShoppingUsesOnlyTheApplicableRateFromTheOwnedWallet(t *testing.T) {
	got := category(t, Build(exampleWallet(t), DefaultOptions()), "online-shopping")
	if len(got.Options) != 3 || got.Options[0].CardID != "quicksilver" || got.Options[0].Rate != 1.5 {
		t.Fatalf("wrong online-shopping ranking: %+v", got.Options)
	}
	for _, option := range got.Options[1:] {
		if option.Rate != 1 {
			t.Fatalf("unrelated dining or travel multiplier leaked into online shopping: %+v", option)
		}
	}
}
