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
	if got.Items[0].FirstYearEstimate != got.Items[0].OngoingEstimate {
		t.Fatalf("conditional bonus must not be counted: %#v", got.Items[0])
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
	// Unknown food split uses the lower 3% rate; other spending earns 2%.
	if got.Items[0].OngoingEstimate != 6000 {
		t.Fatalf("ongoing estimate = %d, want 6000", got.Items[0].OngoingEstimate)
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

func TestStudentEligibilityMustBeExplicit(t *testing.T) {
	input := domain.RecommendationInput{MonthlyCategorySpend: map[string]int64{"other": 10000}, CreditTier: "good"}
	cards := []domain.CatalogCard{{Slug: "savor-for-students", MinimumCreditTier: "building", RewardRates: map[string]float64{"other": 1}}}
	if got := New().Recommend(input, cards); len(got.Items) != 0 {
		t.Fatal("recommended student product without student status")
	}
	input.LifeStage = "student"
	if got := New().Recommend(input, cards); len(got.Items) != 1 {
		t.Fatal("student selection was ignored")
	}
}

func TestRecommendMeasuresIncrementalValueAndRejectsNoImprovement(t *testing.T) {
	input := domain.RecommendationInput{MonthlyCategorySpend: map[string]int64{"other": 100000}, CreditTier: "good", TravelScope: "none", RewardsGoal: "cash_back", FeeToleranceCents: 10000,
		OwnedCards: []domain.CatalogCard{{RewardRates: map[string]float64{"other": 2}}}}
	cards := []domain.CatalogCard{
		{ID: "worse", Slug: "worse", MinimumCreditTier: "good", RewardRates: map[string]float64{"other": 1.5}},
		{ID: "better", Slug: "better", MinimumCreditTier: "good", AnnualFeeCents: 9500, RewardRates: map[string]float64{"other": 3}},
	}
	got := New().Recommend(input, cards)
	// $12,000 annual spend * 1% incremental rewards - $95 fee = $25.
	if len(got.Items) != 1 || got.Items[0].CardID != "better" || got.Items[0].OngoingEstimate != 2500 {
		t.Fatalf("got %+v", got)
	}
}
