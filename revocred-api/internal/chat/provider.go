package chat

import (
	"context"
	"fmt"
	"strings"

	"github.com/revocred/revocred-api/internal/domain"
)

type Context struct {
	Catalog         []domain.CatalogCard
	Recommendations *domain.RecommendationResult
}

type Provider interface {
	Reply(ctx context.Context, prompt string, groundedContext Context) (string, error)
}

type DeterministicProvider struct{}

func NewDeterministicProvider() DeterministicProvider { return DeterministicProvider{} }

func (DeterministicProvider) Reply(_ context.Context, prompt string, groundedContext Context) (string, error) {
	normalized := strings.ToLower(prompt)
	if groundedContext.Recommendations != nil && len(groundedContext.Recommendations.Items) > 0 &&
		(strings.Contains(normalized, "recommend") || strings.Contains(normalized, "next") || strings.Contains(normalized, "apply")) {
		item := groundedContext.Recommendations.Items[0]
		return fmt.Sprintf("Your latest deterministic recommendation ranks %s first, with an estimated $%.2f in first-year value and $%.2f ongoing annual value. %s. Estimates use dataset %s and are not current-offer guarantees.",
			item.CardName, float64(item.FirstYearEstimate)/100, float64(item.OngoingEstimate)/100, item.Reasons[0], groundedContext.Recommendations.DatasetVersion), nil
	}

	category := ""
	for _, candidate := range []string{"dining", "groceries", "grocery", "travel", "gas", "rent"} {
		if strings.Contains(normalized, candidate) {
			category = strings.TrimSuffix(candidate, "ies")
			if candidate == "groceries" || candidate == "grocery" {
				category = "groceries"
			}
			break
		}
	}
	if category != "" {
		var best *domain.CatalogCard
		var rate float64
		for i := range groundedContext.Catalog {
			candidateRate := groundedContext.Catalog[i].RewardRates[category]
			if candidateRate > rate {
				best = &groundedContext.Catalog[i]
				rate = candidateRate
			}
		}
		if best != nil {
			return fmt.Sprintf("In the demo catalog, %s has the highest modeled %s rate at %.1f%% value per dollar. Check the issuer's current terms before acting; this catalog is demonstrative, not financial advice.", best.Name, category, rate), nil
		}
	}

	return "I can explain the demo catalog or your latest deterministic recommendation. Ask about a spend category or what to consider next. Catalog estimates are illustrative and should be checked against current issuer terms.", nil
}
