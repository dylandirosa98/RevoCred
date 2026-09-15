package scoring

type Wallet struct {
	CatchAll           float64
	Dining             float64
	Groceries          float64
	Gas                float64
	Travel             float64
	Flights            float64
	Hotels             float64
	TransferPartners   bool
	PremiumBenefits    bool
	EcosystemDiversity bool
	MajorOverlap       bool
	MultipleOverlap    bool
}

type Result struct {
	Score     int
	Rating    string
	Additions int
	Penalties int
}

func Score(wallet Wallet) Result {
	additions := additionsFor(wallet)
	penalties := penaltiesFor(wallet)
	score := 50 + additions + penalties
	if score > 95 {
		score = 95
	}
	if score < 22 {
		score = 22
	}
	return Result{
		Score:     score,
		Rating:    ratingFor(score),
		Additions: additions,
		Penalties: penalties,
	}
}

func additionsFor(wallet Wallet) int {
	additions := 0
	if wallet.CatchAll >= 2 {
		additions += 10
	} else if wallet.CatchAll >= 1.5 {
		additions += 5
	}
	if wallet.Dining >= 4 {
		additions += 8
	} else if wallet.Dining >= 3 {
		additions += 4
	}
	if wallet.Groceries >= 3 {
		additions += 6
	}
	if wallet.Gas >= 3 {
		additions += 3
	}
	if wallet.Travel >= 2 {
		additions += 4
	}
	if wallet.Flights >= 5 {
		additions += 4
	}
	if wallet.Hotels >= 5 {
		additions += 3
	}
	if wallet.TransferPartners {
		additions += 4
	}
	if wallet.PremiumBenefits {
		additions += 2
	}
	if wallet.EcosystemDiversity {
		additions += 1
	}
	if additions > 45 {
		additions = 45
	}
	return additions
}

func penaltiesFor(wallet Wallet) int {
	penalties := 0
	if !hasRewards(wallet) {
		penalties -= 10
	} else if atLeastOne(wallet.CatchAll) < 1.5 {
		penalties -= 5
	}
	if bestRate(wallet.Dining, wallet.CatchAll) <= 1 {
		penalties -= 4
	}
	if bestRate(wallet.Groceries, wallet.CatchAll) <= 1 {
		penalties -= 3
	}
	if bestRate(wallet.Gas, wallet.CatchAll) <= 1 {
		penalties -= 2
	}
	if bestRate(wallet.Travel, wallet.CatchAll) <= 1 {
		penalties -= 3
	}
	catchAll := atLeastOne(wallet.CatchAll)
	if categoryOrCatchAll(wallet.Flights, wallet.CatchAll) <= catchAll {
		penalties -= 2
	}
	if categoryOrCatchAll(wallet.Hotels, wallet.CatchAll) <= catchAll {
		penalties -= 2
	}
	if wallet.MultipleOverlap {
		penalties -= 4
	} else if wallet.MajorOverlap {
		penalties -= 2
	}
	if penalties < -28 {
		penalties = -28
	}
	return penalties
}

func hasRewards(wallet Wallet) bool {
	return wallet.CatchAll > 1 || wallet.Dining > 1 || wallet.Groceries > 1 ||
		wallet.Gas > 1 || wallet.Travel > 1 || wallet.Flights > 1 || wallet.Hotels > 1
}

func atLeastOne(rate float64) float64 {
	if rate < 1 {
		return 1
	}
	return rate
}

func bestRate(category, catchAll float64) float64 {
	return maxRate(atLeastOne(category), atLeastOne(catchAll))
}

func categoryOrCatchAll(category, catchAll float64) float64 {
	if category == 0 {
		return atLeastOne(catchAll)
	}
	return atLeastOne(category)
}

func maxRate(a, b float64) float64 {
	if a > b {
		return a
	}
	return b
}

func ratingFor(score int) string {
	switch {
	case score >= 90:
		return "Elite"
	case score >= 80:
		return "Great"
	case score >= 65:
		return "Good"
	case score >= 50:
		return "Fair"
	default:
		return "Poor"
	}
}
