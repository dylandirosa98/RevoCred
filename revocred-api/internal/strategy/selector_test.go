package strategy

import (
	"fmt"
	"testing"
)

func TestSelectStrategyProfiles(t *testing.T) {
	cases := []struct {
		name        string
		creditScore int
		goal        Goal
		annualFee   bool
		travel      Travel
		want        Code
	}{
		// Below 650: fee and travel scope are ignored.
		{"building cash-back no-fee domestic", 580, GoalCashBack, false, TravelDomestic, "strategy_1"},
		{"building cash-back fee international", 580, GoalCashBack, true, TravelInternational, "strategy_1"},
		{"building travel no-fee domestic", 580, GoalTravel, false, TravelDomestic, "strategy_2"},
		{"building travel fee both", 580, GoalTravel, true, TravelBoth, "strategy_2"},
		{"649 cash-back fee both", 649, GoalCashBack, true, TravelBoth, "strategy_1"},
		{"649 travel no-fee international", 649, GoalTravel, false, TravelInternational, "strategy_2"},

		// 650–719: cash-back vs travel only; fee and travel scope are ignored.
		{"650 cash-back no-fee domestic", 650, GoalCashBack, false, TravelDomestic, "strategy_3"},
		{"650 cash-back fee both", 650, GoalCashBack, true, TravelBoth, "strategy_3"},
		{"650 travel no-fee domestic", 650, GoalTravel, false, TravelDomestic, "strategy_4"},
		{"650 travel fee international", 650, GoalTravel, true, TravelInternational, "strategy_4"},
		{"719 cash-back fee both", 719, GoalCashBack, true, TravelBoth, "strategy_3"},
		{"719 travel no-fee both", 719, GoalTravel, false, TravelBoth, "strategy_4"},

		// 720–749: fee and travel scope start to split the travel path.
		{"720 cash-back no-fee domestic", 720, GoalCashBack, false, TravelDomestic, "strategy_3"},
		{"720 cash-back fee both", 720, GoalCashBack, true, TravelBoth, "strategy_7"},
		{"720 travel no-fee domestic", 720, GoalTravel, false, TravelDomestic, "strategy_4"},
		{"720 travel no-fee both", 720, GoalTravel, false, TravelBoth, "strategy_4"},
		{"720 travel no-fee international", 720, GoalTravel, false, TravelInternational, "strategy_6"},
		{"720 travel fee domestic", 720, GoalTravel, true, TravelDomestic, "strategy_8"},
		{"720 travel fee international", 720, GoalTravel, true, TravelInternational, "strategy_5"},
		{"720 travel fee both", 720, GoalTravel, true, TravelBoth, "strategy_6"},
		{"749 travel fee both", 749, GoalTravel, true, TravelBoth, "strategy_6"},

		// 750+: same as 720+ except travel + fee + both becomes strategy_9.
		{"750 cash-back no-fee both", 750, GoalCashBack, false, TravelBoth, "strategy_3"},
		{"750 cash-back fee both", 750, GoalCashBack, true, TravelBoth, "strategy_7"},
		{"750 travel fee both", 750, GoalTravel, true, TravelBoth, "strategy_9"},
		{"750 travel fee domestic", 750, GoalTravel, true, TravelDomestic, "strategy_8"},
		{"750 travel fee international", 750, GoalTravel, true, TravelInternational, "strategy_5"},
		{"750 travel no-fee both", 750, GoalTravel, false, TravelBoth, "strategy_4"},
		{"800 travel fee both", 800, GoalTravel, true, TravelBoth, "strategy_9"},

		// Unknown goal falls through: 720+ and <650 become strategy_1; 650–719 treats it like travel.
		{"800 unknown goal", 800, Goal(""), false, TravelDomestic, "strategy_1"},
		{"680 unknown goal", 680, Goal(""), false, TravelDomestic, "strategy_4"},
		{"600 unknown goal", 600, Goal(""), false, TravelDomestic, "strategy_1"},
	}

	t.Logf("%-42s %5s %-10s %5s %-13s %s", "profile", "score", "goal", "fee", "travel", "strategy")
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got, err := SelectStrategy(tc.creditScore, tc.goal, tc.annualFee, tc.travel)
			if err != nil {
				t.Fatalf("SelectStrategy(%d, %q, %v, %q) error: %v", tc.creditScore, tc.goal, tc.annualFee, tc.travel, err)
			}
			t.Logf("%-42s %5d %-10s %5v %-13s %s", tc.name, tc.creditScore, tc.goal, tc.annualFee, tc.travel, got)
			if got != tc.want {
				t.Fatalf("SelectStrategy(%d, %q, %v, %q) = %q, want %q", tc.creditScore, tc.goal, tc.annualFee, tc.travel, got, tc.want)
			}
		})
	}
}

func TestSelectStrategyNeverReturnsErrorOrEmptyCode(t *testing.T) {
	scores := []int{0, 300, 649, 650, 719, 720, 749, 750, 850}
	goals := []Goal{GoalCashBack, GoalTravel, Goal("hybrid"), Goal("")}
	fees := []bool{false, true}
	travels := []Travel{TravelDomestic, TravelInternational, TravelBoth, Travel("")}

	seen := map[Code]int{}
	for _, score := range scores {
		for _, goal := range goals {
			for _, fee := range fees {
				for _, travel := range travels {
					got, err := SelectStrategy(score, goal, fee, travel)
					if err != nil {
						t.Errorf("unexpected error for score=%d goal=%q fee=%v travel=%q: %v", score, goal, fee, travel, err)
					}
					if got == "" {
						t.Errorf("empty code for score=%d goal=%q fee=%v travel=%q", score, goal, fee, travel)
					}
					seen[got]++
				}
			}
		}
	}

	t.Log("codes observed across the full input grid:")
	for code, n := range seen {
		t.Logf("  %s x%d", code, n)
	}
}

func ExampleSelectStrategy() {
	code, err := SelectStrategy(760, GoalTravel, true, TravelBoth)
	fmt.Printf("%s %v\n", code, err)
	// Output: strategy_9 <nil>
}
