package chat

import (
	"github.com/revocred/revocred-api/internal/carddata"
	"github.com/revocred/revocred-api/internal/domain"
	"testing"
)

func TestSnapshotIncludesSourceLabelledCommunityTermsWithoutChangingModeledRates(t *testing.T) {
	c := domain.CatalogCard{ID: "card", Name: "Test Card", RewardRates: map[string]float64{"other": 1}, Benefits: []string{"Issuer terms"}, CommunityData: &carddata.Details{ID: "external", CurrencyLabel: "points", RewardRates: []string{"8x portal only"}, Benefits: []string{"Hotel credit; conditions apply"}, LastVerified: "2026-07-23", Warning: "Community-maintained, not scoring inputs"}}
	facts := Snapshot(Context{Wallet: []domain.WalletCard{{Status: "active", Card: &c}}})
	if _, ok := facts.Wallet[0]["community_product_data"]; !ok {
		t.Fatal("OpenCard evidence missing from REVO facts")
	}
	if facts.Wallet[0]["base_rate"] != float64(1) {
		t.Fatal("community portal rate leaked into deterministic ranking")
	}
	facts = Snapshot(Context{Catalog: []domain.CatalogCard{c}})
	if _, ok := facts.Catalog[0]["community_product_data"]; !ok {
		t.Fatal("catalog reference evidence missing")
	}
}
