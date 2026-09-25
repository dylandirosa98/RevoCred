package strategy

import "fmt"

type Goal string

const (
	GoalCashBack Goal = "cash_back"
	GoalTravel   Goal = "travel"
)

type Code string

const (
	S01 Code = "S01"
	S02 Code = "S02"
	S03 Code = "S03"
	S04 Code = "S04"
	S05 Code = "S05"
	S06 Code = "S06"
	S07 Code = "S07"
	S08 Code = "S08"
	S09 Code = "S09"
)

type Travel string

const (
	TravelDomestic      Travel = "domestic"
	TravelInternational Travel = "international"
	TravelBoth          Travel = "both"
)

// SelectStrategy maps a credit score and goal to one of the stable strategy codes.
func SelectStrategy(creditScore int, goal Goal, annualFee bool, travel Travel) (Code, error) {
	if creditScore >= 720 {
		if creditScore >= 750 && goal == GoalTravel && annualFee == true && travel == TravelBoth {
			return S09, nil
		}
		if goal == GoalCashBack {
			if annualFee {
				return S07, nil
			}
			return S03, nil
		}
		if goal == GoalTravel {
			if annualFee {
				if travel == TravelDomestic {
					return S08, nil
				} else if travel == TravelInternational {
					return S05, nil
				}
				return S06, nil
			}
			if travel == TravelBoth {
				return S04, nil
			}
			if travel == TravelDomestic {
				return S04, nil
			}
			return S06, nil
		}
	} else if creditScore >= 650 {
		if goal == GoalCashBack {
			return S03, nil
		}
		return S04, nil
	}
	if goal == GoalTravel {
		return S02, nil
	}
	return S01, nil
}

// SelectFromQuestionnaire translates the questionnaire's coarse credit and fee
// bands into the score-based matrix. A premium fee path requires comfort above
// $300 because the matrix's high-fee cards sit above the questionnaire's mid tier.
func SelectFromQuestionnaire(creditTier string, goal Goal, feeToleranceCents int, travel Travel) (Code, error) {
	creditScore, ok := map[string]int{
		"building":  600,
		"fair":      680,
		"good":      720,
		"excellent": 750,
	}[creditTier]
	if !ok {
		return "", fmt.Errorf("unknown credit tier %q", creditTier)
	}
	if goal != GoalCashBack && goal != GoalTravel {
		return "", fmt.Errorf("unknown rewards goal %q", goal)
	}
	if travel == "none" {
		travel = TravelBoth
	}
	if travel != TravelDomestic && travel != TravelInternational && travel != TravelBoth {
		return "", fmt.Errorf("unknown travel scope %q", travel)
	}
	return SelectStrategy(creditScore, goal, feeToleranceCents > 30_000, travel)
}
