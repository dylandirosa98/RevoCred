package recommendation

import (
	"fmt"
	"math"
	"slices"
	"sort"
	"strings"

	"github.com/revocred/revocred-api/internal/domain"
)

const EngineVersion = "v1.0.0"

var creditTierRank = map[string]int{
	"building":  0,
	"fair":      1,
	"good":      2,
	"excellent": 3,
}

type Engine struct{}

func New() Engine { return Engine{} }

func (Engine) Recommend(input domain.RecommendationInput, cards []domain.CatalogCard) domain.RecommendationResult {
	existing := make(map[string]struct{}, len(input.ExistingCardIDs))
	for _, id := range input.ExistingCardIDs {
		existing[id] = struct{}{}
	}

	result := domain.RecommendationResult{
		EngineVersion: EngineVersion,
		Items:         make([]domain.RecommendationItem, 0, len(cards)),
		Exclusions:    make([]domain.RecommendationExclusion, 0),
	}
	for _, card := range cards {
		if result.DatasetVersion == "" || card.DatasetVersion > result.DatasetVersion {
			result.DatasetVersion = card.DatasetVersion
		}
		if reason := exclusionReason(input, card, existing); reason != "" {
			result.Exclusions = append(result.Exclusions, domain.RecommendationExclusion{
				CardID: card.ID, CardSlug: card.Slug, Reason: reason,
			})
			continue
		}

		ongoing, categoryValue, strongestCategory := estimateOngoing(input, card)
		reasons := []string{fmt.Sprintf("Estimated ongoing value is $%.2f after the annual fee", float64(ongoing)/100)}
		if strongestCategory != "" {
			reasons = append(reasons, fmt.Sprintf("Strongest modeled value comes from %s ($%.2f/year)", strongestCategory, float64(categoryValue)/100))
		}
		score := float64(ongoing) / 100
		if goalMatches(input.RewardsGoal, card.RewardsType) {
			score += 20
			reasons = append(reasons, "Rewards type aligns with the selected goal")
		}
		if travelMatches(input.TravelScope, card.TravelScope) && input.TravelScope != "none" {
			score += 10
			reasons = append(reasons, "Travel coverage aligns with the selected scope")
		}
		result.Items = append(result.Items, domain.RecommendationItem{
			CardID:            card.ID,
			CardSlug:          card.Slug,
			CardName:          card.Name,
			Score:             math.Round(score*100) / 100,
			FirstYearEstimate: ongoing + int64(card.FirstYearBonusCents),
			OngoingEstimate:   ongoing,
			Reasons:           reasons,
		})
	}

	sort.SliceStable(result.Items, func(i, j int) bool {
		if result.Items[i].Score == result.Items[j].Score {
			return result.Items[i].CardSlug < result.Items[j].CardSlug
		}
		return result.Items[i].Score > result.Items[j].Score
	})
	for i := range result.Items {
		result.Items[i].Rank = i + 1
	}
	sort.Slice(result.Exclusions, func(i, j int) bool {
		return result.Exclusions[i].CardSlug < result.Exclusions[j].CardSlug
	})
	return result
}

func exclusionReason(input domain.RecommendationInput, card domain.CatalogCard, existing map[string]struct{}) string {
	if _, ok := existing[card.ID]; ok {
		return "already in wallet"
	}
	if _, ok := existing[card.Slug]; ok {
		return "already in wallet"
	}
	if card.AnnualFeeCents > input.FeeToleranceCents {
		return fmt.Sprintf("annual fee of $%.2f exceeds tolerance", float64(card.AnnualFeeCents)/100)
	}
	if creditTierRank[input.CreditTier] < creditTierRank[card.MinimumCreditTier] {
		return "selected credit tier is below the catalog minimum"
	}
	if !travelMatches(input.TravelScope, card.TravelScope) && card.TravelScope != "none" && input.TravelScope != "none" {
		return "travel scope does not match"
	}
	return ""
}

func estimateOngoing(input domain.RecommendationInput, card domain.CatalogCard) (total, strongestValue int64, strongestCategory string) {
	total = int64(card.AnnualBenefitValue - card.AnnualFeeCents)
	keys := make([]string, 0, len(input.MonthlyCategorySpend))
	for category := range input.MonthlyCategorySpend {
		keys = append(keys, category)
	}
	slices.Sort(keys)
	for _, category := range keys {
		rate := rateForCategory(card.RewardRates, category)
		value := int64(math.Round(float64(input.MonthlyCategorySpend[category]) * 12 * rate / 100))
		total += value
		if value > strongestValue {
			strongestValue = value
			strongestCategory = strings.ReplaceAll(category, "_", " ")
		}
	}
	return total, strongestValue, strongestCategory
}

func rateForCategory(rates map[string]float64, category string) float64 {
	if rate, ok := rates[category]; ok {
		return rate
	}
	switch category {
	case "food":
		return max(rates["dining"], rates["groceries"])
	case "everyday":
		return rates["other"]
	case "housing":
		return max(rates["rent"], rates["other"])
	default:
		return rates["other"]
	}
}

func goalMatches(goal, rewardsType string) bool {
	return goal == rewardsType || rewardsType == "hybrid" || goal == "hybrid"
}

func travelMatches(wanted, offered string) bool {
	if wanted == "none" {
		return offered == "none" || offered == "both"
	}
	return offered == wanted || offered == "both"
}
