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

	return Result{Additions: additions}
}
