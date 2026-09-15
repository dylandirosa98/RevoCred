package scoring

import "math"

type MonthlySpending struct {
	RentOrHousing int
	DiningGrocery int
	Traveling     int
	Other         int
}

type BestCreditPoints struct {
	RentOrHousing float64
	DiningGrocery float64
	Traveling     float64
	Other         float64
}

func YearlyValue(spend MonthlySpending, rates BestCreditPoints) int {
	total := dollarValue(spend.RentOrHousing, rates.RentOrHousing) +
		dollarValue(spend.DiningGrocery, rates.DiningGrocery) +
		dollarValue(spend.Traveling, rates.Traveling) +
		dollarValue(spend.Other, rates.Other)
	return int(math.Round(total))
}

func dollarValue(monthlyDollars int, rate float64) float64 {
	return float64(monthlyDollars) * 12 * atLeastOne(rate) / 100
}

func BestRates(wallet Wallet) BestCreditPoints {
	catchAll := atLeastOne(wallet.CatchAll)
	diningGrocery := maxRate(bestRate(wallet.Dining, wallet.CatchAll), bestRate(wallet.Groceries, wallet.CatchAll))
	travel := bestRate(wallet.Travel, wallet.CatchAll)
	travel = maxRate(travel, bestRate(wallet.Flights, wallet.CatchAll))
	travel = maxRate(travel, bestRate(wallet.Hotels, wallet.CatchAll))
	return BestCreditPoints{
		RentOrHousing: catchAll,
		DiningGrocery: diningGrocery,
		Traveling:     travel,
		Other:         catchAll,
	}
}
