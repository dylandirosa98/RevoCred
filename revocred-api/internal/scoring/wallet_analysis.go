package scoring

import (
	"math"

	"github.com/revocred/revocred-api/internal/domain"
	"github.com/revocred/revocred-api/internal/valuation"
)

// AnalyzeWallet converts persisted active cards into the stable wallet scoring
// input. Catalog reward rates are structured data, so the server does not need
// to parse display strings as the Flutter demo does.
func AnalyzeWallet(cards []domain.WalletCard) Wallet {
	var wallet Wallet
	issuers := make(map[string]struct{})
	for _, item := range cards {
		// A card whose terms the user skipped is shown as owned but must not be
		// scored: no known rate is not the same as a low rate.
		if item.Status != "active" || item.Card == nil || item.Card.TermsUnknown {
			continue
		}
		card := item.Card
		if card.Issuer != "" {
			issuers[card.Issuer] = struct{}{}
		}
		wallet.CatchAll = maxRate(wallet.CatchAll, card.RewardRates["other"])
		wallet.Dining = maxRate(wallet.Dining, card.RewardRates["dining"])
		wallet.Groceries = maxRate(wallet.Groceries, card.RewardRates["groceries"])
		wallet.Gas = maxRate(wallet.Gas, card.RewardRates["gas"])
		wallet.Travel = maxRate(wallet.Travel, card.RewardRates["travel"])
		wallet.Flights = maxRate(wallet.Flights, card.RewardRates["flights"])
		wallet.Hotels = maxRate(wallet.Hotels, card.RewardRates["hotels"])
		wallet.TransferPartners = wallet.TransferPartners || card.TransferablePoints
		wallet.PremiumBenefits = wallet.PremiumBenefits || card.AnnualFeeCents >= 30000
	}
	wallet.EcosystemDiversity = len(issuers) >= 2
	return wallet
}

func Metrics(cards []domain.WalletCard, categorySpendCents map[string]int64) domain.WalletMetrics {
	wallet := AnalyzeWallet(cards)
	score := Score(wallet)
	active := []domain.CatalogCard{}
	for _, item := range cards {
		if item.Status == "active" && item.Card != nil && !item.Card.TermsUnknown {
			active = append(active, *item.Card)
		}
	}
	return domain.WalletMetrics{
		Score:       score.Score,
		Rating:      score.Rating,
		Additions:   score.Additions,
		Penalties:   score.Penalties,
		YearlyValue: int(math.Round(float64(valuation.Net(categorySpendCents, active)) / 100)),
	}
}

// MonthlySpendingFromCategoryCents maps questionnaire categories to the four
// wallet-value buckets. Values are rounded to whole dollars because YearlyValue
// intentionally returns a whole-dollar estimate for the UI.
func MonthlySpendingFromCategoryCents(categories map[string]int64) MonthlySpending {
	dollars := func(cents int64) int { return int(math.Round(float64(cents) / 100)) }
	return MonthlySpending{
		RentOrHousing: dollars(categories["rent"] + categories["housing"]),
		DiningGrocery: dollars(categories["food"] + categories["dining"] + categories["groceries"]),
		Traveling:     dollars(categories["travel"]),
		Other:         dollars(categories["everyday"] + categories["other"]),
	}
}
