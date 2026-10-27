package recommendation

import (
	"encoding/json"
	"github.com/revocred/revocred-api/internal/domain"
	"github.com/revocred/revocred-api/internal/valuation"
	"os"
	"reflect"
	"testing"
)

func TestWalletBenefitsNeverChangeApplicationRankings(t *testing.T) {
	raw, err := os.ReadFile("../valuation/testdata/catalog.json")
	if err != nil {
		t.Fatal(err)
	}
	var cards []domain.CatalogCard
	if err = json.Unmarshal(raw, &cards); err != nil {
		t.Fatal(err)
	}
	input := domain.RecommendationInput{MonthlyCategorySpend: map[string]int64{"travel": 20000, "everyday": 100000}, FeeToleranceCents: 100000, TravelScope: "both", RewardsGoal: "travel", CreditTier: "excellent"}
	before := New().Recommend(input, cards)
	_ = valuation.Ongoing(input.MonthlyCategorySpend, cards, input.TravelScope)
	for i := range cards {
		cards[i].CommunityData = nil
		cards[i].AnnualBenefitValue = 99999999
	}
	after := New().Recommend(input, cards)
	if !reflect.DeepEqual(before.Items, after.Items) {
		t.Fatalf("benefits changed rankings\nbefore=%+v\nafter=%+v", before.Items, after.Items)
	}
}
