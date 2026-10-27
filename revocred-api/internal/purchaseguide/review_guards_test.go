package purchaseguide

import (
	"github.com/revocred/revocred-api/internal/domain"
	"testing"
)

func TestKnownGroceryCapSurvivesMissingUpstreamCapMetadata(t *testing.T) {
	wallet := exampleWallet(t)
	for i := range wallet[0].Card.CommunityData.Rewards.Categories {
		wallet[0].Card.CommunityData.Rewards.Categories[i].Cap = nil
	}
	settings := DefaultOptions()
	settings.CapsAvailable = false
	g := category(t, Build(wallet, settings), "groceries")
	if g.Options[0].CardID != "quicksilver" {
		t.Fatal("known grocery cap failed open when upstream cap field was missing")
	}
}
func TestStoredFallbackExcludesKnownCapsButNotUnlimitedCategoryRates(t *testing.T) {
	gold := domain.WalletCard{Status: "active", Card: &domain.CatalogCard{ID: "20000000-0000-4000-8000-000000000016", Name: "Amex Gold", RewardRates: map[string]float64{"other": 1, "dining": 4}}}
	quick := exampleWallet(t)[2]
	settings := DefaultOptions()
	settings.CapsAvailable = false
	g := category(t, Build([]domain.WalletCard{gold, quick}, settings), "dining")
	if g.Options[0].CardID != "quicksilver" {
		t.Fatal("known capped stored fallback ignored caps setting")
	}
	unlimited := domain.WalletCard{Status: "active", Card: &domain.CatalogCard{ID: "custom-unlimited", Name: "User supplied unlimited dining", RewardRates: map[string]float64{"other": 1, "dining": 4}}}
	g = category(t, Build([]domain.WalletCard{unlimited, quick}, settings), "dining")
	if g.Options[0].CardID != "custom-unlimited" || g.Options[0].Rate != 4 {
		t.Fatal("unknown caps must not suppress an unlimited supplied rate")
	}
}
