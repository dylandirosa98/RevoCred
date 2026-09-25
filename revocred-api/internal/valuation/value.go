// Package valuation owns conservative rewards estimates shared by wallet metrics
// and recommendation ranking. Catalog rates must already exclude conditional uplift.
package valuation

import (
	"math"
	"sort"

	"github.com/revocred/revocred-api/internal/domain"
)

// Rate assumes one cent per point, no housing rewards, and the lower rate for
// combined food spend (the dining/grocery split is unknown).
func Rate(rates map[string]float64, category string) float64 {
	if category == "rent" || category == "housing" {
		return 0
	}
	if category == "food" {
		return min(Rate(rates, "dining"), Rate(rates, "groceries"))
	}
	if rate, ok := rates[category]; ok {
		return max(0, rate)
	}
	return max(0, rates["other"])
}

func Gross(spend map[string]int64, cards []domain.CatalogCard) int64 {
	keys := make([]string, 0, len(spend))
	for category := range spend {
		keys = append(keys, category)
	}
	sort.Strings(keys)
	var total int64
	for _, category := range keys {
		var best float64
		for _, card := range cards {
			best = max(best, Rate(card.RewardRates, category))
		}
		total += int64(math.Round(float64(spend[category]) * 12 * best / 100))
	}
	return total
}

func Net(spend map[string]int64, cards []domain.CatalogCard) int64 {
	total := Gross(spend, cards)
	for _, card := range cards {
		total -= int64(card.AnnualFeeCents)
	}
	return total
}
