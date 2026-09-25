package chat

import (
	"context"
	"fmt"
	"strings"

	"github.com/revocred/revocred-api/internal/domain"
	"github.com/revocred/revocred-api/internal/strategy"
	"github.com/revocred/revocred-api/internal/valuation"
)

type Context struct {
	SessionID       string
	Catalog         []domain.CatalogCard
	Wallet          []domain.WalletCard
	Recommendations *domain.RecommendationResult
	Profile         *domain.Profile
	Questionnaire   *domain.RecommendationInput
	Metrics         domain.WalletMetrics
	Playbook        *strategy.Playbook
}

type Provider interface {
	Mode() string
	Reply(ctx context.Context, prompt string, groundedContext Context) (string, error)
}

type DeterministicProvider struct{}

func NewDeterministicProvider() DeterministicProvider { return DeterministicProvider{} }

func (DeterministicProvider) Mode() string { return "deterministic" }

func (DeterministicProvider) Reply(_ context.Context, prompt string, groundedContext Context) (string, error) {
	normalized := strings.ToLower(prompt)
	if groundedContext.Recommendations != nil && len(groundedContext.Recommendations.Items) > 0 &&
		(strings.Contains(normalized, "recommend") || strings.Contains(normalized, "next") || strings.Contains(normalized, "apply")) {
		item := groundedContext.Recommendations.Items[0]
		return fmt.Sprintf("Your current server recommendation ranks %s first, with an estimated $%.2f additional annual wallet value after its fee. Bonuses and conditional credits are excluded. Verify eligibility and current issuer terms. Dataset: %s.",
			item.CardName, float64(item.OngoingEstimate)/100, groundedContext.Recommendations.DatasetVersion), nil
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
		for _, item := range groundedContext.Wallet {
			if item.Status != "active" || item.Card == nil {
				continue
			}
			candidateRate := valuation.Rate(item.Card.RewardRates, category)
			if candidateRate > rate {
				best = item.Card
				rate = candidateRate
			}
		}
		if best != nil {
			return fmt.Sprintf("In your active wallet, %s has the highest conservative modeled %s rate at %.1f%% value per dollar (one cent per point). Verify current terms; caps and merchant eligibility can reduce rewards.", best.Name, category, rate), nil
		}
	}

	return "I do not have an eligible card recommendation for that question. Complete or update your questionnaire and wallet. I explain server-calculated estimates, which exclude bonuses, conditional credits and housing rewards; they are not financial advice or approval guarantees.", nil
}
