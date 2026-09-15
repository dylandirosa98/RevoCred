package recommendation

import (
	"reflect"
	"testing"

	"github.com/revocred/revocred-api/internal/domain"
)

func TestRecommendRanksDeterministicallyAndExplainsValue(t *testing.T) {
	input := domain.RecommendationInput{
		MonthlyCategorySpend: map[string]int64{"dining": 50000, "other": 20000},
		FeeToleranceCents:    10000, TravelScope: "international", RewardsGoal: "travel", CreditTier: "good",
	}
	cards := []domain.CatalogCard{
		{ID: "b", Slug: "flat", Name: "Flat", AnnualFeeCents: 0, RewardRates: map[string]float64{"other": 2}, RewardsType: "cash_back", TravelScope: "both", MinimumCreditTier: "good", DatasetVersion: "demo-1"},
		{ID: "a", Slug: "dining", Name: "Dining", AnnualFeeCents: 9500, RewardRates: map[string]float64{"dining": 4, "other": 1}, RewardsType: "travel", TravelScope: "both", MinimumCreditTier: "good", FirstYearBonusCents: 30000, DatasetVersion: "demo-1"},
	}

	got := New().Recommend(input, cards)
	if got.EngineVersion != EngineVersion || got.DatasetVersion != "demo-1" {
		t.Fatalf("unexpected versions: %#v", got)
	}
	if len(got.Items) != 2 || got.Items[0].CardSlug != "dining" || got.Items[0].Rank != 1 {
		t.Fatalf("unexpected ranking: %#v", got.Items)
	}
	if got.Items[0].FirstYearEstimate-got.Items[0].OngoingEstimate != 30000 {
		t.Fatalf("first year bonus not reflected: %#v", got.Items[0])
	}
	if len(got.Items[0].Reasons) < 2 {
		t.Fatalf("expected transparent reasons: %#v", got.Items[0].Reasons)
	}
	if again := New().Recommend(input, cards); !reflect.DeepEqual(got, again) {
		t.Fatalf("recommendation is not deterministic\nfirst: %#v\nagain: %#v", got, again)
	}
}

func TestQuestionnaireBucketsUseCatalogCategoryRates(t *testing.T) {
	input := domain.RecommendationInput{
		MonthlyCategorySpend: map[string]int64{"food": 10000, "everyday": 10000},
		FeeToleranceCents:    0, TravelScope: "none", RewardsGoal: "cash_back", CreditTier: "good",
	}
	card := domain.CatalogCard{
		ID: "1", Slug: "food-card", Name: "Food Card", RewardRates: map[string]float64{
			"dining": 4, "groceries": 3, "other": 2,
		}, RewardsType: "cash_back", TravelScope: "none", MinimumCreditTier: "good",
	}

	got := New().Recommend(input, []domain.CatalogCard{card})
	if len(got.Items) != 1 {
		t.Fatalf("items = %#v", got.Items)
	}
	// $100/month food at 4%% plus $100/month everyday at 2%% = $72/year.
	if got.Items[0].OngoingEstimate != 7200 {
		t.Fatalf("ongoing estimate = %d, want 7200", got.Items[0].OngoingEstimate)
	}
}

func TestRecommendReportsExclusions(t *testing.T) {
	input := domain.RecommendationInput{
		MonthlyCategorySpend: map[string]int64{"other": 10000}, FeeToleranceCents: 0,
		TravelScope: "domestic", RewardsGoal: "cash_back", CreditTier: "fair", ExistingCardIDs: []string{"owned"},
	}
	cards := []domain.CatalogCard{
		{ID: "1", Slug: "owned", AnnualFeeCents: 0, MinimumCreditTier: "fair", TravelScope: "both"},
		{ID: "2", Slug: "fee", AnnualFeeCents: 9500, MinimumCreditTier: "fair", TravelScope: "both"},
		{ID: "3", Slug: "credit", AnnualFeeCents: 0, MinimumCreditTier: "good", TravelScope: "both"},
	}

	got := New().Recommend(input, cards)
	if len(got.Items) != 0 || len(got.Exclusions) != 3 {
		t.Fatalf("unexpected result: %#v", got)
	}
}
