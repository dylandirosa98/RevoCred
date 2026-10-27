package purchaseguide

import (
	"fmt"
	"strings"

	"github.com/revocred/revocred-api/internal/domain"
)

var homeCategories = [][2]string{
	{"dining", "Dining"}, {"groceries", "Groceries"}, {"travel", "Travel"},
	{"gas", "Gas"}, {"transit", "Transit"}, {"online-shopping", "Online shopping"},
	{"rent", "Rent"}, {"streaming", "Streaming"}, {"entertainment", "Entertainment"},
	{"drugstores", "Drugstores"}, {"wholesale-clubs", "Wholesale clubs"}, {"utilities", "Utilities"},
	{"phone-and-internet", "Phone & internet"}, {"home-improvement", "Home improvement"},
	{"office-supplies", "Office supplies"}, {"general-purchases", "General purchases"},
}

type rule struct {
	Categories  []string
	Modes       []string
	Conditional bool
	Capped      bool
	Note        string
}

// Labels are reviewed selectors, not a text-scoring heuristic. Rates come from
// the bound source record. New/changed labels fail closed to base/stored terms.
var reviewed = map[string]map[string]rule{
	"us-amex-gold": {
		"Restaurants worldwide": {Categories: []string{"dining"}, Capped: true, Note: "Eligible restaurants; up to $50,000 per calendar year, then base rate. This cap is also in the newer issuer snapshot."},
		"U.S. supermarkets":     {Categories: []string{"groceries"}, Capped: true, Note: "Eligible U.S. supermarkets only; excludes nonqualifying merchants. Known annual spending cap applies even if upstream cap metadata is missing."},
	},
}
var storedCategories = map[string]string{
	"dining": "dining", "groceries": "groceries", "gas": "gas", "transit": "transit",
	"online-shopping": "online_shopping", "rent": "rent", "streaming": "streaming",
	"entertainment": "entertainment", "drugstores": "drugstores", "wholesale-clubs": "wholesale_clubs",
	"utilities": "utilities", "phone-and-internet": "phone_internet", "home-improvement": "home_improvement",
	"office-supplies": "office_supplies", "general-purchases": "other",
}

func contains(values []string, value string) bool {
	for _, s := range values {
		if s == value {
			return true
		}
	}
	return false
}
func scopeFor(product, label string) (rule, bool) {
	for _, table := range []map[string]map[string]rule{reviewed, travelReviewed, categoryReviewed} {
		if spec, ok := table[product][label]; ok {
			return spec, true
		}
	}
	return rule{}, false
}

func earningLabel(rate float64, card domain.CatalogCard) string {
	if d := card.CommunityData; d != nil {
		if d.Rewards.RateType == "cashback_percent" {
			return fmt.Sprintf("%g%% cash back", rate)
		}
		return fmt.Sprintf("%gx %s", rate, d.Rewards.CurrencyLabel)
	}
	if card.RewardsType == "cash_back" {
		return fmt.Sprintf("%g%% cash back", rate)
	}
	return fmt.Sprintf("%gx points per dollar", rate)
}
func storedKey(category string, settings Settings) string {
	if category != "travel" {
		return storedCategories[category]
	}
	if settings.TravelMode == "flights-direct" {
		return "flights"
	}
	if settings.TravelMode == "hotels-direct" {
		return "hotels"
	}
	return "travel"
}

func applyRules(card domain.CatalogCard, category string, settings Settings, base Option) (Option, []Option, bool) {
	conditional := []Option{}
	if category == "rent" {
		// A catch-all reward is not evidence that a card earns on rent or that a
		// payment route accepts it without fees. Only explicit rent terms may rank.
		rate, ok := card.RewardRates["rent"]
		if !ok || !validRate(rate) {
			return base, conditional, false
		}
		base.Rate = rate
		base.EarnLabel = earningLabel(rate, card)
		base.Reason = "Explicit rent earning rule; confirm payment-route eligibility and fees."
		return base, conditional, true
	}
	if card.CommunityData == nil {
		key := storedKey(category, settings)
		if key != "" {
			if rate, ok := card.RewardRates[key]; ok && validRate(rate) && rate > base.Rate {
				candidate := base
				candidate.Rate = rate
				candidate.EarnLabel = earningLabel(rate, card)
				candidate.Reason = "Stored category-specific earning rate."
				candidate.Conditions = append([]string{}, base.Conditions...)
				candidate.Conditions = append(candidate.Conditions, "Verify merchant eligibility and any spending caps with the issuer. Cap setting excludes known caps only; unknown limits are not inferred.")
				knownCap := (card.ID == "20000000-0000-4000-8000-000000000016" && (key == "dining" || key == "groceries")) ||
					(card.ID == "20000000-0000-4000-8000-000000000017" && key == "flights")
				if knownCap {
					candidate.Conditions = append(candidate.Conditions, "Known capped product rule from the stored issuer snapshot; unused allowance is required.")
					if !settings.CapsAvailable {
						conditional = append(conditional, candidate)
						return base, conditional, true
					}
				}
				base = candidate
			}
		}
		return base, conditional, true
	}
	d := card.CommunityData
	for _, sourceRule := range d.Rewards.Categories {
		spec, ok := scopeFor(d.ID, sourceRule.Label)
		if !ok || !contains(spec.Categories, category) || sourceRule.PointsPerDollar == nil || !validRate(*sourceRule.PointsPerDollar) {
			continue
		}
		candidate := base
		candidate.Rate = *sourceRule.PointsPerDollar
		candidate.EarnLabel = earningLabel(candidate.Rate, card)
		candidate.Reason = sourceRule.Label
		candidate.Conditions = []string{}
		if spec.Note != "" {
			candidate.Conditions = append(candidate.Conditions, spec.Note)
		}
		hasCap := spec.Capped || (len(sourceRule.Cap) > 0 && strings.TrimSpace(string(sourceRule.Cap)) != "null")
		if hasCap {
			candidate.Conditions = append(candidate.Conditions, "Only while eligible spending remains below the source's cap.")
		}
		if len(sourceRule.Cap) > 0 && string(sourceRule.Cap) != "null" {
			candidate.Conditions = append(candidate.Conditions, "Source spending cap: "+string(sourceRule.Cap))
		}
		if spec.Conditional || (hasCap && !settings.CapsAvailable) || (len(spec.Modes) > 0 && !contains(spec.Modes, settings.TravelMode)) {
			if candidate.Rate > base.Rate {
				conditional = append(conditional, candidate)
			}
			continue
		}
		if candidate.Rate > base.Rate {
			base = candidate
		}
	}
	return base, conditional, true
}
