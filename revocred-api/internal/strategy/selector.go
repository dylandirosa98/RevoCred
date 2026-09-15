package strategy

type Goal string

const (
	GoalCashBack Goal = "cash_back"
	GoalTravel   Goal = "travel"
)

type Code string

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
			return "strategy_9", nil
		}
		if goal == GoalCashBack {
			if annualFee {
				return "strategy_7", nil
			}
			return "strategy_3", nil
		}
		if goal == GoalTravel {
			if annualFee {
				if travel == TravelDomestic {
					return "strategy_8", nil
				} else if travel == TravelInternational {
					return "strategy_5", nil
				}
				return "strategy_6", nil
			}
			if travel == TravelBoth {
				return "strategy_4", nil
			}
			if travel == TravelDomestic {
				return "strategy_4", nil
			}
			return "strategy_6", nil
		}
	} else if creditScore >= 650 {
		if goal == GoalCashBack {
			return "strategy_3", nil
		}
		return "strategy_4", nil
	}
	if goal == GoalTravel {
		return "strategy_2", nil
	}
	return "strategy_1", nil
}
