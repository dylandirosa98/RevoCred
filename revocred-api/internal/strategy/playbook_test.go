package strategy

import (
	"slices"
	"strings"
	"testing"
)

func TestScheduleDoesNotTurnCoveredOrUnavailableRolesIntoApplications(t *testing.T) {
	p := Playbook{Steps: []PlaybookStep{
		{Name: "Owned substitute", Status: "have"},
		{Name: "Filtered card", Status: "unavailable"},
		{Name: "Next", Status: "next"},
		{Name: "Future", Status: "later"},
	}}
	Schedule(&p)
	if p.Steps[0].Timing != "Already covered" || p.Steps[1].Timing != "Do not apply now" {
		t.Fatalf("non-applications got application timing: %+v", p.Steps)
	}
	if !strings.Contains(p.Steps[2].TimingNote, "eligibility timing is unknown") {
		t.Fatal("next must disclose missing history")
	}
	if !strings.Contains(p.Steps[3].Timing, "after the previous application") || !strings.Contains(p.Steps[3].TimingNote, "Planning estimate only") {
		t.Fatal("future timing must be conditional and relative, not a fabricated date")
	}
	p.Steps[2].Status = "have"
	Schedule(&p)
	if p.Steps[2].Timing != "Already covered" {
		t.Fatal("stale application timing survived ownership change")
	}
}

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
	if got.Steps[0].CoveredBy != "Chase Freedom Unlimited" {
		t.Fatalf("owned coverage = %q", got.Steps[0].CoveredBy)
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
	if got.Steps[0].CoveredBy != "Savor" {
		t.Fatalf("covered by = %q", got.Steps[0].CoveredBy)
	}
}

func TestBuildPlaybookDoesNotSuggestUnownedSubstitutes(t *testing.T) {
	got := Build("S03", nil, nil)
	if got.Steps[0].Name != "SavorOne" || got.Steps[0].Status != "next" || got.Steps[0].CoveredBy != "" {
		t.Fatalf("unowned substitute leaked into roadmap: %+v", got.Steps[0])
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
