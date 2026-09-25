package strategy

import "testing"

func TestSelectFromQuestionnaireMatchesStrategyMatrix(t *testing.T) {
	tests := []struct {
		name         string
		creditTier   string
		goal         Goal
		feeTolerance int
		travel       Travel
		want         Code
	}{
		{"building cash back", "building", GoalCashBack, 0, Travel("none"), "S01"},
		{"building travel", "building", GoalTravel, 0, TravelBoth, "S02"},
		{"fair cash back", "fair", GoalCashBack, 10_000, Travel("none"), "S03"},
		{"fair travel", "fair", GoalTravel, 10_000, TravelBoth, "S04"},
		{"good international premium", "good", GoalTravel, 100_000, TravelInternational, "S05"},
		{"good international low fee", "good", GoalTravel, 10_000, TravelInternational, "S06"},
		{"good cash back premium", "good", GoalCashBack, 100_000, Travel("none"), "S07"},
		{"good domestic premium", "good", GoalTravel, 100_000, TravelDomestic, "S08"},
		{"excellent both premium", "excellent", GoalTravel, 100_000, TravelBoth, "S09"},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			got, err := SelectFromQuestionnaire(test.creditTier, test.goal, test.feeTolerance, test.travel)
			if err != nil {
				t.Fatalf("SelectFromQuestionnaire() error = %v", err)
			}
			if got != test.want {
				t.Fatalf("SelectFromQuestionnaire() = %q, want %q", got, test.want)
			}
		})
	}
}

func TestDefinitionsMatchSuppliedMatrix(t *testing.T) {
	tests := []struct {
		code      Code
		ecosystem string
		cards     []string
	}{
		{"S01", "Capital One", []string{"Savor for Students", "Quicksilver"}},
		{"S02", "Chase", []string{"Freedom Rise", "Freedom Flex", "Sapphire Preferred"}},
		{"S03", "Capital One", []string{"SavorOne", "Quicksilver"}},
		{"S04", "Chase", []string{"Freedom Unlimited", "Freedom Flex", "Sapphire Preferred"}},
		{"S05", "Amex", []string{"Venture X", "Gold", "Platinum"}},
		{"S06", "Capital One", []string{"SavorOne", "Venture X", "Amex Gold"}},
		{"S07", "Chase", []string{"Freedom Unlimited", "Freedom Flex"}},
		{"S08", "Citi", []string{"Double Cash", "Strata", "Strata Elite"}},
		{"S09", "Chase", []string{"Freedom Unlimited", "Freedom Flex", "Sapphire Reserve"}},
	}

	for _, test := range tests {
		definition, ok := DefinitionFor(test.code)
		if !ok {
			t.Fatalf("DefinitionFor(%q) was not found", test.code)
		}
		if definition.Ecosystem != test.ecosystem {
			t.Errorf("DefinitionFor(%q).Ecosystem = %q, want %q", test.code, definition.Ecosystem, test.ecosystem)
		}
		if len(definition.Cards) != len(test.cards) {
			t.Fatalf("DefinitionFor(%q).Cards = %#v, want %#v", test.code, definition.Cards, test.cards)
		}
		for index := range test.cards {
			if definition.Cards[index] != test.cards[index] {
				t.Errorf("DefinitionFor(%q).Cards[%d] = %q, want %q", test.code, index, definition.Cards[index], test.cards[index])
			}
		}
	}
}
