package store

import (
	"reflect"
	"testing"

	"github.com/revocred/revocred-api/internal/domain"
	"github.com/revocred/revocred-api/internal/strategy"
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

func TestApplySubstitutionsOnlyUsesOwnedApprovedCards(t *testing.T) {
	playbook := strategy.Build("S03", []string{"Freedom Unlimited"}, nil)
	wallet := []domain.WalletCard{{
		Status: "active",
		Card:   &domain.CatalogCard{Name: "Freedom Unlimited"},
	}}
	approved := map[string][]domain.Substitution{
		"Quicksilver": {{Name: "Freedom Unlimited"}},
		"SavorOne":    {{Name: "Discover it Cash Back"}},
	}

	applySubstitutions(&playbook, wallet, approved)

	if playbook.Steps[0].Status == "have" {
		t.Fatal("an unowned substitute covered a strategy role")
	}
	covered := playbook.Steps[1]
	if covered.Status != "have" || covered.Name != "Quicksilver" || covered.CoveredBy != "Freedom Unlimited" {
		t.Fatalf("owned substitute did not cover the original role: %+v", covered)
	}
	for _, unused := range playbook.Unused {
		if unused.Name == "Freedom Unlimited" {
			t.Fatal("accepted substitute remained in unused cards")
		}
	}
}

func TestApplyRecommendationSkipsCoveredRole(t *testing.T) {
	playbook := strategy.Build("S03", []string{"Freedom Unlimited"}, nil)
	applySubstitutions(&playbook, []domain.WalletCard{{
		Status: "active",
		Card:   &domain.CatalogCard{Name: "Freedom Unlimited"},
	}}, map[string][]domain.Substitution{
		"Quicksilver": {{Name: "Freedom Unlimited"}},
	})
	applyRecommendation(&playbook, &domain.RecommendationResult{Items: []domain.RecommendationItem{
		{CardName: "Quicksilver"},
		{CardName: "SavorOne"},
	}})

	if playbook.NextCard != "SavorOne" || playbook.Steps[0].Status != "next" {
		t.Fatalf("recommendation did not advance past covered role: %+v", playbook)
	}
	if playbook.Steps[1].Status != "have" || playbook.Steps[1].CoveredBy != "Freedom Unlimited" {
		t.Fatalf("recommendation overwrote covered role: %+v", playbook.Steps[1])
	}
}
