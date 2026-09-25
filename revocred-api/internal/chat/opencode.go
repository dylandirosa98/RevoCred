package chat

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/revocred/revocred-api/internal/valuation"
)

const (
	defaultGoBaseURL = "https://opencode.ai/zen/go/v1"
	defaultGoModel   = "deepseek-v4.1-flash"
	userAgent        = "revocred-api/1.0"
)

type Options struct {
	APIKey   string
	Model    string
	BaseURL  string
	Client   *http.Client
	Fallback Provider
}

func New(opts Options) (Provider, error) {
	if strings.TrimSpace(opts.APIKey) == "" {
		return NewDeterministicProvider(), nil
	}
	base := strings.TrimRight(strings.TrimSpace(opts.BaseURL), "/")
	if base == "" {
		base = defaultGoBaseURL
	}
	parsed, err := url.Parse(base)
	if err != nil || parsed.Host == "" {
		return nil, errors.New("OPENCODE_GO_BASE_URL is invalid")
	}
	if parsed.Scheme != "https" {
		host := parsed.Hostname()
		if parsed.Scheme != "http" || (host != "127.0.0.1" && host != "localhost") {
			return nil, errors.New("OPENCODE_GO_BASE_URL must be HTTPS")
		}
	}
	model := strings.TrimSpace(opts.Model)
	if model == "" {
		model = defaultGoModel
	}
	client := opts.Client
	if client == nil {
		client = &http.Client{Timeout: 35 * time.Second}
	}
	fallback := opts.Fallback
	if fallback == nil {
		fallback = NewDeterministicProvider()
	}
	return goProvider{
		endpoint: base + "/chat/completions",
		apiKey:   strings.TrimSpace(opts.APIKey),
		model:    model,
		client:   client,
		fallback: fallback,
	}, nil
}

type goProvider struct {
	endpoint string
	apiKey   string
	model    string
	client   *http.Client
	fallback Provider
}

func (goProvider) Mode() string { return "opencode-go" }

func (p goProvider) Reply(ctx context.Context, prompt string, groundedContext Context) (string, error) {
	facts := Snapshot(groundedContext)
	body, err := json.Marshal(map[string]any{
		"model":       p.model,
		"temperature": 0.2,
		"max_tokens":  1600,
		"messages": []map[string]string{
			{"role": "system", "content": systemPrompt(facts)},
			{"role": "user", "content": prompt},
		},
	})
	if err != nil {
		return p.fallback.Reply(ctx, prompt, groundedContext)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, p.endpoint, bytes.NewReader(body))
	if err != nil {
		return p.fallback.Reply(ctx, prompt, groundedContext)
	}
	req.Header.Set("Authorization", "Bearer "+p.apiKey)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("User-Agent", userAgent)
	if groundedContext.SessionID != "" {
		req.Header.Set("X-Opencode-Session", groundedContext.SessionID)
	}
	resp, err := p.client.Do(req)
	if err != nil {
		return p.fallback.Reply(ctx, prompt, groundedContext)
	}
	defer resp.Body.Close()
	payload, err := io.ReadAll(io.LimitReader(resp.Body, 64<<10))
	if err != nil || resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return p.fallback.Reply(ctx, prompt, groundedContext)
	}
	var parsed struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}
	if err := json.Unmarshal(payload, &parsed); err != nil || len(parsed.Choices) == 0 {
		return p.fallback.Reply(ctx, prompt, groundedContext)
	}
	reply := strings.TrimSpace(parsed.Choices[0].Message.Content)
	if reply == "" || inventsCard(reply, facts.AllowedCards) {
		return p.fallback.Reply(ctx, prompt, groundedContext)
	}
	return reply, nil
}

func systemPrompt(facts snapshot) string {
	encoded, err := json.Marshal(facts)
	if err != nil {
		encoded = []byte("{}")
	}
	return "You are REVO, an educational explainer for RevoCred. Use only FACTS_JSON. Do not invent cards, rates, fees, bonuses, credits, approval odds, or spending. Card selection is owned by the server: if asked what to apply for or use next, restate next_card and its server reasons. If a fact is missing, say so. Never ask for card numbers, CVV, PINs, or bank credentials. Not financial, tax, or legal advice.\nFACTS_JSON=" + string(encoded)
}

type snapshot struct {
	AllowedCards   []string         `json:"allowed_cards"`
	Wallet         []map[string]any `json:"wallet"`
	NextCard       string           `json:"next_card"`
	StrategyCode   string           `json:"strategy_code"`
	PlaybookTitle  string           `json:"playbook_title,omitempty"`
	Reasons        []string         `json:"server_reasons,omitempty"`
	WalletScore    int              `json:"wallet_score"`
	WalletRating   string           `json:"wallet_rating"`
	YearlyValueUSD int              `json:"modeled_annual_wallet_value_usd"`
	MonthlySpend   map[string]int64 `json:"monthly_spend_cents,omitempty"`
	CreditTier     string           `json:"credit_tier,omitempty"`
	RewardsGoal    string           `json:"rewards_goal,omitempty"`
	TravelScope    string           `json:"travel_scope,omitempty"`
	FeeTolerance   int              `json:"fee_tolerance_cents,omitempty"`
	Disclaimer     string           `json:"disclaimer"`
}

func Snapshot(input Context) snapshot {
	facts := snapshot{
		AllowedCards:   []string{},
		Wallet:         []map[string]any{},
		WalletScore:    input.Metrics.Score,
		WalletRating:   input.Metrics.Rating,
		YearlyValueUSD: input.Metrics.YearlyValue,
		Disclaimer:     "Conservative model: 1 cent per point; excludes housing rewards, bonuses, statement credits, and conditional reward uplift. Verify current issuer terms.",
	}
	seen := map[string]bool{}
	add := func(name string) {
		name = strings.TrimSpace(name)
		if name == "" || seen[name] {
			return
		}
		seen[name] = true
		facts.AllowedCards = append(facts.AllowedCards, name)
	}
	for _, item := range input.Wallet {
		if item.Status != "active" || item.Card == nil {
			continue
		}
		card := item.Card
		add(card.Name)
		facts.Wallet = append(facts.Wallet, map[string]any{
			"name":             card.Name,
			"issuer":           card.Issuer,
			"annual_fee_cents": card.AnnualFeeCents,
			"best_use":         card.BestUse,
			"reward_rates":     card.RewardRates,
			"modeled_other":    valuation.Rate(card.RewardRates, "other"),
		})
	}
	if input.Recommendations != nil {
		facts.StrategyCode = input.Recommendations.StrategyCode
		if len(input.Recommendations.Items) > 0 {
			top := input.Recommendations.Items[0]
			facts.NextCard = top.CardName
			facts.Reasons = top.Reasons
			add(top.CardName)
		}
	}
	if input.Playbook != nil {
		if facts.StrategyCode == "" {
			facts.StrategyCode = string(input.Playbook.Code)
		}
		facts.PlaybookTitle = input.Playbook.Title
		if facts.NextCard == "" {
			facts.NextCard = input.Playbook.NextCard
		}
		add(input.Playbook.NextCard)
		for _, step := range input.Playbook.Steps {
			add(step.Name)
		}
	}
	if input.Profile != nil {
		if facts.StrategyCode == "" {
			facts.StrategyCode = input.Profile.CreditCardStrategy
		}
		if facts.NextCard == "" {
			facts.NextCard = input.Profile.NextApplicationTarget
			add(input.Profile.NextApplicationTarget)
		}
	}
	if input.Questionnaire != nil {
		facts.MonthlySpend = input.Questionnaire.MonthlyCategorySpend
		facts.CreditTier = input.Questionnaire.CreditTier
		facts.RewardsGoal = input.Questionnaire.RewardsGoal
		facts.TravelScope = input.Questionnaire.TravelScope
		facts.FeeTolerance = input.Questionnaire.FeeToleranceCents
	}
	return facts
}

func inventsCard(reply string, allowed []string) bool {
	normalized := strings.ToLower(reply)
	allowedSet := map[string]bool{}
	for _, name := range allowed {
		allowedSet[strings.ToLower(name)] = true
	}
	for _, name := range []string{
		"sapphire preferred", "sapphire reserve", "freedom unlimited", "freedom flex",
		"venture x", "amex gold", "platinum", "savorone", "quicksilver",
		"double cash", "strata elite", "bilt",
	} {
		if strings.Contains(normalized, name) && !allowedSet[name] {
			return true
		}
	}
	return false
}
