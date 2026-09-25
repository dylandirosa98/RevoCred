package strategy

import (
	"slices"
	"testing"
)

func TestBuildPlaybookMarksOwnedCardsAndNextApply(t *testing.T) {
	got := Build("S04", []string{"Chase Freedom Unlimited", "Amex Gold"}, nil)
	if got.Code != S04 {
		t.Fatalf("code = %q", got.Code)
	}
	if len(got.Steps) != 3 {
		t.Fatalf("steps = %d", len(got.Steps))
	}
	if got.Steps[0].Status != "have" || got.Steps[0].Name != "Freedom Unlimited" {
		t.Fatalf("first step = %+v", got.Steps[0])
	}
	if got.Steps[1].Status != "next" || got.Steps[1].Name != "Freedom Flex" {
		t.Fatalf("next step = %+v", got.Steps[1])
	}
	if got.Steps[2].Status != "later" {
		t.Fatalf("later step = %+v", got.Steps[2])
	}
	if got.NextCard != "Freedom Flex" {
		t.Fatalf("next card = %q", got.NextCard)
	}
	if len(got.Unused) != 1 || got.Unused[0].Name != "Amex Gold" {
		t.Fatalf("unused = %+v", got.Unused)
	}
	if got.Unused[0].Action != "avoid_for_this_strategy" {
		t.Fatalf("unused action = %q", got.Unused[0].Action)
	}
}

func TestBuildPlaybookAcceptsFamilySubstitutes(t *testing.T) {
	got := Build("S03", []string{"Savor"}, nil)
	if got.Steps[0].Status != "have" || got.Steps[0].Name != "SavorOne" {
		t.Fatalf("savor should substitute for SavorOne: %+v", got.Steps[0])
	}
	if got.Steps[0].Note == "" {
		t.Fatal("expected substitute note")
	}
}

func TestBuildPlaybookAlternativesAreNearbyStrategies(t *testing.T) {
	got := Build("S04", nil, &Preferences{CreditTier: "fair", Goal: GoalTravel, FeeToleranceCents: 10000, Travel: TravelBoth})
	if len(got.Alternatives) == 0 {
		t.Fatal("expected nearby alternatives")
	}
	for _, alt := range got.Alternatives {
		if alt.Code == S04 {
			t.Fatal("assigned strategy should not appear as an alternative")
		}
		if _, ok := DefinitionFor(alt.Code); !ok {
			t.Fatalf("unknown alternative %s", alt.Code)
		}
	}
	codes := []Code{}
	for _, alt := range got.Alternatives {
		codes = append(codes, alt.Code)
	}
	if !slices.Contains(codes, S02) && !slices.Contains(codes, S09) && !slices.Contains(codes, S06) {
		t.Fatalf("expected a nearby travel alternative, got %v", codes)
	}
}

func TestBuildPlaybookUnknownCodeIsEmpty(t *testing.T) {
	got := Build("nope", []string{"Freedom Unlimited"}, nil)
	if got.Code != "" || len(got.Steps) != 0 {
		t.Fatalf("got %+v", got)
	}
}
