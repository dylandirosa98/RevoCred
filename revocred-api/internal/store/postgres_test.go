package store

import (
	"reflect"
	"testing"

	"github.com/revocred/revocred-api/internal/domain"
)

func TestQuestionnaireProfileUsesTopSpendAndTopRecommendation(t *testing.T) {
	categories, goal, target := questionnaireProfile(
		domain.RecommendationInput{
			MonthlyCategorySpend: map[string]int64{
				"travel": 10000, "food": 50000, "rent": 80000, "everyday": 30000,
			},
			RewardsGoal: "cash_back",
		},
		domain.RecommendationResult{
			StrategyCode: "S03",
			Items:        []domain.RecommendationItem{{CardName: "Top Card"}},
		},
	)
	if !reflect.DeepEqual(categories, []string{"rent", "food", "everyday"}) {
		t.Fatalf("categories = %#v", categories)
	}
	if goal != "Build a stronger cash back wallet" || target != "Top Card" {
		t.Fatalf("goal = %q, target = %q", goal, target)
	}
}
