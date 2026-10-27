package chat

import (
	"context"
	"sort"
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
	// History is the recent conversation, oldest first, so follow-up questions
	// can refer back to earlier answers.
	History []Turn
}

type Turn struct {
	Role    string
	Content string
}

// maxHistoryTurns bounds how much of the conversation is resent each time.
const maxHistoryTurns = 8

type Provider interface {
	Mode() string
	Reply(ctx context.Context, prompt string, groundedContext Context) (Reply, error)
}

type DeterministicProvider struct{}

func NewDeterministicProvider() DeterministicProvider { return DeterministicProvider{} }

func (DeterministicProvider) Mode() string { return "deterministic" }

func (DeterministicProvider) Reply(_ context.Context, prompt string, groundedContext Context) (Reply, error) {
	normalized := strings.ToLower(prompt)
	facts := Snapshot(groundedContext)
	finish := func(blocks []Block) (Reply, error) {
		return Reply{Blocks: blocks, Text: RenderText(blocks)}, nil
	}
	if groundedContext.Recommendations != nil && len(groundedContext.Recommendations.Items) > 0 &&
		(strings.Contains(normalized, "recommend") || strings.Contains(normalized, "next") || strings.Contains(normalized, "apply")) {
		item := groundedContext.Recommendations.Items[0]
		blocks := []Block{{Type: "heading", Text: "Your next move: " + item.CardName}}
		if len(item.Reasons) > 0 {
			bullets := make([]string, 0, len(item.Reasons))
			for _, reason := range item.Reasons {
				bullets = append(bullets, reason)
			}
			blocks = append(blocks, Block{Type: "bullets", Items: bullets})
		}
		blocks = append(blocks, Block{Type: "chart", Chart: &Chart{
			Title: "Modeled annual value",
			Unit:  "usd",
			Note:  "Application ranking estimate after the annual fee. Bonuses and conditional credits remain excluded here; Home wallet ongoing value uses a separate reviewed benefit breakdown.",
			Bars:  []Bar{{Label: item.CardName, Value: float64(item.OngoingEstimate) / 100, Caption: "per year"}},
		}})
		blocks = append(blocks, Block{Type: "note", Text: "Verify eligibility and current issuer terms. Dataset: " + groundedContext.Recommendations.DatasetVersion})
		return finish(blocks)
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
		rate := 0.0
		for _, item := range groundedContext.Wallet {
			if item.Status != "active" || item.Card == nil {
				continue
			}
			candidateRate := valuation.Rate(item.Card.RewardRates, category)
			if candidateRate > rate {
				best, rate = item.Card, candidateRate
			}
		}
		if best != nil {
			return finish([]Block{
				{Type: "heading", Text: "Best modeled " + category + " rate"},
				{Type: "chart", Chart: &Chart{
					Title: "Modeled value per dollar",
					Unit:  "percent",
					Note:  "One cent per point. Caps and merchant eligibility can reduce rewards.",
					Bars:  []Bar{{Label: best.Name, Value: rate, Caption: category}},
				}},
				{Type: "paragraph", Text: "This is the highest conservative modeled rate in your active wallet. Verify current issuer terms."},
			})
		}
	}

	blocks := []Block{{Type: "paragraph", Text: "I do not have an eligible card recommendation for that question. Complete or update your questionnaire and wallet so REVO has facts to explain."}}
	if len(facts.MonthlySpend) > 0 {
		blocks = append(blocks, Block{Type: "chart", Chart: &Chart{
			Title: "Your monthly spending",
			Unit:  "usd",
			Note:  "Entered in the questionnaire. Housing is excluded from reward estimates.",
			Bars:  spendBars(facts),
		}})
	}
	blocks = append(blocks, Block{Type: "note", Text: facts.Disclaimer})
	return finish(blocks)
}

func spendBars(facts snapshot) []Bar {
	bars := []Bar{}
	for category, cents := range facts.MonthlySpend {
		if cents <= 0 {
			continue
		}
		bars = append(bars, Bar{Label: titleCase(category), Value: float64(cents) / 100, Caption: "per month"})
	}
	sort.Slice(bars, func(i, j int) bool { return bars[i].Value > bars[j].Value })
	return capBars(Chart{Bars: bars}).Bars
}
