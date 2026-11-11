package chat

import (
	"github.com/revocred/revocred-api/internal/carddata"
	"github.com/revocred/revocred-api/internal/domain"
	"strings"
	"testing"
	"time"
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

func TestWalletCommunityScoringFactsIncludeSourceAndCaptureDate(t *testing.T) {
	c := domain.CatalogCard{ID: "owned", Name: "Autograph", RewardRates: map[string]float64{"other": 1, "dining": 3}, TermsSource: domain.TermsSourceCommunity,
		CommunityTerms: &carddata.Terms{SourceName: carddata.TermsSourceName, CapturedAt: time.Date(2026, 11, 9, 0, 0, 0, 0, time.UTC), LastVerified: "2026-10-22", NotScored: []carddata.TermsRule{{Label: "Portal", Rate: 5, Reason: "portal-only"}}}}
	facts := Snapshot(Context{Wallet: []domain.WalletCard{{Status: "active", Card: &c}}})
	source, ok := facts.Wallet[0]["terms_source"].(map[string]any)
	if !ok || source["captured_on"] != "2026-11-09" || !strings.Contains(source["source"].(string), "community") || len(source["rates_not_counted"].([]string)) != 1 {
		t.Fatalf("missing community provenance: %+v", facts.Wallet)
	}
	if facts.Wallet[0]["base_rate"] != float64(1) {
		t.Fatal("mapped base missing")
	}
}

func TestPurchaseFactsRankCashValueAndPreserveNominalLabels(t *testing.T) {
	hotel := domain.CatalogCard{Name: "Hilton", PointValueCents: .5, TransferablePoints: true, RewardRates: map[string]float64{"other": 3, "dining": 5}}
	gold := domain.CatalogCard{Name: "Gold", RewardRates: map[string]float64{"other": 1, "dining": 4}}
	wallet := []domain.WalletCard{{Status: "active", Card: &hotel}, {Status: "active", Card: &gold}}
	for _, category := range purchaseRankings(wallet) {
		if category.Category != "dining" {
			continue
		}
		if category.Options[0].Card != "Gold" {
			t.Fatalf("ranking = %+v", category)
		}
		h := category.Options[1]
		if h.ModeledValuePer100USD != 2.5 || h.EarnLabel != "5 points per dollar" {
			t.Fatalf("hotel fact = %+v", h)
		}
	}
	facts := Snapshot(Context{Wallet: wallet})
	if facts.Wallet[0]["point_value_cents"] != .5 || facts.Wallet[0]["base_rate"] != float64(3) {
		t.Fatalf("wallet facts = %+v", facts.Wallet)
	}
}
