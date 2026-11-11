package chat

import (
	"context"
	"fmt"
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
		blocks = append([]Block{{Type: "note", Text: "Basic answer — this comes straight from your plan, without AI."}}, blocks...)
		return Reply{Basic: true, Blocks: blocks, Text: RenderText(blocks)}, nil
	}
	if strings.Contains(normalized, "score") {
		return finish([]Block{{Type: "paragraph", Text: fmt.Sprintf("Your wallet score is %d. It measures reward coverage and optimization, not creditworthiness. The saved plan does not provide an exact score breakdown.", facts.WalletScore)}})
	}
	if strings.Contains(normalized, "total annual") || strings.Contains(normalized, "fees") &&
		(strings.Contains(normalized, "wallet") || strings.Contains(normalized, "my cards") || strings.Contains(normalized, "my total")) {
		total := 0
		unknown := false
		for _, w := range groundedContext.Wallet {
			if w.Status == "active" && w.Card != nil {
				if w.Card.TermsUnknown {
					unknown = true
				} else {
					total += w.Card.AnnualFeeCents
				}
			}
		}
		text := fmt.Sprintf("Known active-wallet annual fees total $%.2f.", float64(total)/100)
		if unknown {
			text += " Cards with unknown terms are excluded."
		}
		return finish([]Block{{Type: "paragraph", Text: text}})
	}
	if strings.Contains(normalized, "strategy") || strings.Contains(normalized, "playbook") || strings.Contains(normalized, "roadmap") {
		if facts.Strategy != nil {
			items := []string{}
			for _, step := range facts.Strategy.Roadmap {
				items = append(items, step.Card+": "+step.Status+". "+step.Use+" "+step.Note)
			}
			return finish([]Block{{Type: "heading", Text: facts.Strategy.Title}, {Type: "bullets", Items: items}})
		}
	}
	if entry := matchCard(normalized, facts); entry != nil {
		name, _ := entry["name"].(string)
		items := []string{}
		if fee, ok := entry["annual_fee_usd"].(float64); ok {
			items = append(items, fmt.Sprintf("Annual fee: $%.0f", fee))
		}
		if rates, ok := entry["reward_rates"].(map[string]float64); ok {
			keys := make([]string, 0, len(rates))
			for key := range rates {
				keys = append(keys, key)
			}
			sort.Strings(keys)
			for _, key := range keys {
				value, _ := entry["point_value_cents"].(float64)
				if value <= 0 {
					value = 1
				}
				items = append(items, fmt.Sprintf("%s: %g nominal units per dollar; %g%% modeled return (%g cents per unit)", titleCase(key), rates[key], rates[key]*value, value))
			}
		}
		if benefits, ok := entry["benefits"].([]string); ok {
			items = append(items, benefits...)
		}
		if len(items) > 0 {
			return finish([]Block{{Type: "heading", Text: name}, {Type: "bullets", Items: items}, {Type: "note", Text: "Saved catalog terms. Verify conditions and current issuer terms before relying on them."}})
		}
	}
	if groundedContext.Recommendations != nil && len(groundedContext.Recommendations.Items) > 0 &&
		(strings.Contains(normalized, "recommend") || strings.Contains(normalized, "next") || strings.Contains(normalized, "apply")) {
		item := groundedContext.Recommendations.Items[0]
		blocks := []Block{{Type: "heading", Text: "The app’s server-ranked next application: " + item.CardName}}
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
	for _, candidate := range basicCategories(facts) {
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
			if item.Status != "active" || item.Card == nil || item.Card.TermsUnknown {
				continue
			}
			candidateRate := valuation.CardRate(*item.Card, category)
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
					Note:  "Per-card point values (1 cent by default). Caps and merchant eligibility can reduce rewards.",
					Bars:  []Bar{{Label: best.Name, Value: rate, Caption: category}},
				}},
				{Type: "paragraph", Text: "This is the highest conservative modeled rate in your active wallet. Verify current issuer terms."},
			})
		}
	}

	blocks := []Block{{Type: "paragraph", Text: "Basic mode can explain saved card fees and benefits, wallet reward rates by category, total annual fees, wallet score, your strategy and the server-ranked next application. Ask about a card or spending category."}}
	if len(facts.MonthlySpend) > 0 {
		blocks = append(blocks, Block{Type: "chart", Chart: &Chart{
			Title: "Your monthly spending",
			Unit:  "usd",
			Note:  "Entered in the questionnaire. Housing is excluded from reward estimates.",
			Bars:  spendBars(facts),
		}})
	}
	blocks = append(blocks, Block{Type: "note", Text: estimateNotice})
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

// cardNameNoise lists words too common in card names to identify a card on
// their own: issuers, networks, spending categories and marketing words.
var cardNameNoise = map[string]bool{
	"card": true, "credit": true, "rewards": true, "reward": true, "travel": true, "cash": true, "back": true,
	"plus": true, "everyday": true, "business": true, "signature": true, "visa": true, "mastercard": true,
	"world": true, "elite": true, "bank": true, "american": true, "express": true, "capital": true, "chase": true,
	"citi": true, "discover": true, "wells": true, "fargo": true, "america": true, "dining": true, "groceries": true,
	"grocery": true, "hotel": true, "hotels": true, "airline": true, "airlines": true, "miles": true, "points": true,
	"gold": true, "platinum": true, "reserve": true, "preferred": true, "premium": true, "amex": true,
	"with": true, "from": true, "your": true, "card's": true,
}

// matchCard finds the wallet or catalog card a question names. A full-name
// mention wins; otherwise the card with the most distinctive name words
// matched wins, wallet cards first on ties. Generic words never match alone.
func matchCard(normalized string, facts snapshot) map[string]any {
	words := map[string]bool{}
	for _, word := range strings.FieldsFunc(normalized, func(r rune) bool {
		return !(r >= 'a' && r <= 'z' || r >= '0' && r <= '9' || r == '\'')
	}) {
		words[word] = true
	}
	var best map[string]any
	bestScore := 0
	for _, entry := range append(append([]map[string]any{}, facts.Wallet...), facts.Catalog...) {
		name, _ := entry["name"].(string)
		lower := strings.ToLower(strings.TrimSpace(name))
		if lower == "" {
			continue
		}
		score := 0
		if strings.Contains(normalized, lower) {
			score = 100
		}
		for _, word := range strings.Fields(lower) {
			if len(word) >= 4 && !cardNameNoise[word] && words[word] {
				score++
			}
		}
		if score > bestScore {
			best, bestScore = entry, score
		}
	}
	return best
}

func basicCategories(f snapshot) []string {
	out := []string{"dining", "groceries", "grocery", "travel", "gas", "rent"}
	for _, g := range f.PurchaseGuide {
		if g.Category != "" {
			out = append(out, strings.ToLower(g.Category))
		}
	}
	return out
}
