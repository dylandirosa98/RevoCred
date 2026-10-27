package chat

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/revocred/revocred-api/internal/domain"
)

func TestNewWithoutKeyUsesDeterministicMode(t *testing.T) {
	provider, err := New(Options{})
	if err != nil {
		t.Fatal(err)
	}
	if provider.Mode() != "deterministic" {
		t.Fatalf("mode = %s", provider.Mode())
	}
}

func TestGoProviderSendsGroundedFactsAndSession(t *testing.T) {
	var captured struct {
		auth, ua, session, model, system string
	}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		captured.auth = r.Header.Get("Authorization")
		captured.ua = r.Header.Get("User-Agent")
		captured.session = r.Header.Get("X-Opencode-Session")
		body, _ := io.ReadAll(r.Body)
		var payload struct {
			Model    string `json:"model"`
			Messages []struct {
				Role, Content string
			} `json:"messages"`
		}
		_ = json.Unmarshal(body, &payload)
		captured.model = payload.Model
		if len(payload.Messages) > 0 {
			captured.system = payload.Messages[0].Content
		}
		_, _ = w.Write([]byte(`{"choices":[{"message":{"content":"Use Freedom Unlimited for everyday spend in your wallet. The server ranks it next."}}]}`))
	}))
	defer server.Close()

	provider, err := New(Options{APIKey: "test-key", BaseURL: server.URL, Client: server.Client()})
	if err != nil {
		t.Fatal(err)
	}
	reply, err := provider.Reply(context.Background(), "What should I use?", Context{
		SessionID: "11111111-1111-4111-8111-111111111111",
		Wallet: []domain.WalletCard{{Status: "active", Card: &domain.CatalogCard{
			Name: "Freedom Unlimited", RewardRates: map[string]float64{"other": 1.5},
		}}},
		Recommendations: &domain.RecommendationResult{
			StrategyCode: "S04",
			Items:        []domain.RecommendationItem{{CardName: "Freedom Unlimited", Reasons: []string{"Highest modeled improvement"}}},
		},
		Questionnaire: &domain.RecommendationInput{MonthlyCategorySpend: map[string]int64{"food": 50000}, CreditTier: "good"},
		Metrics:       domain.WalletMetrics{Score: 64, Rating: "Fair", YearlyValue: 48},
	})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(reply.Text, "Freedom Unlimited") {
		t.Fatalf("reply = %q", reply.Text)
	}
	if captured.auth != "Bearer test-key" || captured.ua != userAgent || captured.session != "11111111-1111-4111-8111-111111111111" {
		t.Fatalf("headers = %+v", captured)
	}
	if captured.model != defaultGoModel || !strings.Contains(captured.system, `"food":500`) || !strings.Contains(captured.system, "Freedom Unlimited") {
		t.Fatalf("payload = %+v", captured)
	}
}

func TestGoProviderAllowsDiscussingCardsOutsideCatalog(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`{"choices":[{"message":{"content":"The Sapphire Reserve is an alternative, not the app recommendation."}}]}`))
	}))
	defer server.Close()
	provider, err := New(Options{APIKey: "test-key", BaseURL: server.URL, Client: server.Client()})
	if err != nil {
		t.Fatal(err)
	}
	reply, err := provider.Reply(context.Background(), "What next?", Context{
		Wallet: []domain.WalletCard{{Status: "active", Card: &domain.CatalogCard{Name: "Quicksilver", RewardRates: map[string]float64{"other": 1.5}}}},
		Recommendations: &domain.RecommendationResult{Items: []domain.RecommendationItem{{
			CardName: "Quicksilver", Reasons: []string{"Highest modeled improvement"},
		}}},
	})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(reply.Text, "Sapphire Reserve") {
		t.Fatalf("alternative discussion missing: %q", reply.Text)
	}
}

func TestSnapshotIncludesWalletSpendAndNextCard(t *testing.T) {
	got := Snapshot(Context{
		Wallet: []domain.WalletCard{
			{Status: "active", Card: &domain.CatalogCard{Name: "SavorOne", AnnualFeeCents: 0, RewardRates: map[string]float64{"dining": 3, "other": 1}}},
			{Status: "inactive", Card: &domain.CatalogCard{Name: "Hidden"}},
		},
		Recommendations: &domain.RecommendationResult{StrategyCode: "S03", Items: []domain.RecommendationItem{{CardName: "Quicksilver", Reasons: []string{"catch-all"}}}},
		Questionnaire:   &domain.RecommendationInput{MonthlyCategorySpend: map[string]int64{"food": 40000}, CreditTier: "fair", RewardsGoal: "cash_back"},
		Metrics:         domain.WalletMetrics{Score: 40, YearlyValue: 12},
	})
	if got.NextCard != "Quicksilver" || got.CreditTier != "fair" || got.MonthlySpend["food"] != 40000 || got.YearlyValueUSD != 12 {
		t.Fatalf("%+v", got)
	}
	if len(got.Wallet) != 1 || got.Wallet[0]["name"] != "SavorOne" {
		t.Fatalf("wallet = %#v", got.Wallet)
	}
}

func TestSnapshotRanksOwnedCardsForPurchaseCategories(t *testing.T) {
	got := Snapshot(Context{Wallet: []domain.WalletCard{
		{Status: "active", Card: &domain.CatalogCard{
			Name: "Points Card", AnnualFeeCents: 9500, TransferablePoints: true,
			RewardRates: map[string]float64{"groceries": 4, "other": 1},
		}},
		{Status: "active", Card: &domain.CatalogCard{
			Name: "Cash Card", RewardRates: map[string]float64{"groceries": 3, "other": 2},
		}},
	}})
	var groceries categoryRanking
	for _, category := range got.PurchaseGuide {
		if category.Category == "groceries" {
			groceries = category
			break
		}
	}
	if len(groceries.Options) != 2 {
		t.Fatalf("groceries ranking = %+v", groceries.Options)
	}
	if groceries.Options[0].Card != "Points Card" || groceries.Options[0].Rank != 1 || groceries.Options[0].EarnLabel != "4 points per dollar" {
		t.Fatalf("winner = %+v", groceries.Options[0])
	}
	if groceries.Options[1].Card != "Cash Card" || groceries.Options[1].EarnLabel != "3% cash back" {
		t.Fatalf("runner-up = %+v", groceries.Options[1])
	}
}

func TestSystemPromptSeparatesPurchaseAndApplicationDecisions(t *testing.T) {
	prompt := systemPrompt(Snapshot(DemoBrowseContext()))
	for _, rule := range []string{
		"Distinguish purchase decisions from application decisions",
		"best_cards_by_purchase_category",
		"For the app's next application use next_card",
		"booking direct versus a travel portal",
		"including cards outside the catalog",
		"deterministic, read-only",
		"NEVER send the member's name",
	} {
		if !strings.Contains(prompt, rule) {
			t.Fatalf("system prompt missing %q", rule)
		}
	}
}

func TestDemoRecommendationMatchesTheRoadmap(t *testing.T) {
	facts := Snapshot(DemoBrowseContext())
	if facts.NextCard != "Freedom Flex" || facts.Strategy == nil || len(facts.Strategy.Roadmap) == 0 {
		t.Fatalf("demo recommendation is incomplete: %+v", facts)
	}
	var roadmapNext string
	for _, step := range facts.Strategy.Roadmap {
		if step.Status == "recommended next" {
			roadmapNext = step.Card
			break
		}
	}
	if roadmapNext != facts.NextCard {
		t.Fatalf("ranking next = %q, roadmap next = %q", facts.NextCard, roadmapNext)
	}
}

func TestGoProviderSendsRecentHistoryAndCatalog(t *testing.T) {
	var roles []string
	var system string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		var payload struct {
			Messages []struct{ Role, Content string } `json:"messages"`
		}
		_ = json.Unmarshal(body, &payload)
		for _, message := range payload.Messages {
			roles = append(roles, message.Role)
		}
		system = payload.Messages[0].Content
		_, _ = w.Write([]byte(`{"choices":[{"message":{"content":"Amex Gold earns more on dining, but it is not in your ranking."}}]}`))
	}))
	defer server.Close()
	provider, _ := New(Options{APIKey: "k", BaseURL: server.URL, Client: server.Client()})
	history := []Turn{}
	for i := 0; i < 12; i++ {
		role := "user"
		if i%2 == 1 {
			role = "assistant"
		}
		history = append(history, Turn{Role: role, Content: "turn"})
	}
	reply, err := provider.Reply(context.Background(), "What about Amex Gold?", Context{
		History: history,
		Catalog: []domain.CatalogCard{{ID: "c1", Name: "Amex Gold", Issuer: "American Express", AnnualFeeCents: 32500, RewardRates: map[string]float64{"dining": 4}}},
	})
	if err != nil {
		t.Fatal(err)
	}
	// system + the last 8 turns + the new question
	if len(roles) != 10 || roles[0] != "system" || roles[9] != "user" {
		t.Fatalf("roles = %v", roles)
	}
	if !strings.Contains(system, `"annual_fee_usd":325`) || !strings.Contains(system, "Amex Gold") {
		t.Fatalf("catalog missing from context: %s", system)
	}
	if strings.Contains(system, "FACTS_JSON") || strings.Contains(system, "deepseek") {
		t.Fatal("the prompt still carries an internal label or model name")
	}
	// A catalog card is covered, so this is not treated as invented.
	if !strings.Contains(reply.Text, "Amex Gold") {
		t.Fatalf("catalog card answer was blocked: %q", reply.Text)
	}
}

func TestUnfamiliarCardReplyIsNotReplaced(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`{"choices":[{"message":{"content":"The Orbit card may be worth comparing."}}]}`))
	}))
	defer server.Close()
	provider, _ := New(Options{APIKey: "k", BaseURL: server.URL, Client: server.Client()})
	reply, _ := provider.Reply(context.Background(), "next?", Context{})
	if !strings.Contains(reply.Text, "Orbit card") {
		t.Fatalf("unfamiliar card was blocked: %+v", reply.Blocks)
	}
}

func TestSlowModelFallsBackBeforeTheRequestDeadline(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		select {
		case <-time.After(5 * time.Second):
		case <-r.Context().Done():
		}
	}))
	defer server.Close()
	provider, _ := New(Options{APIKey: "k", BaseURL: server.URL, Client: server.Client()})
	// 8.5s left: the reserve leaves the model about 1.5s, then the fallback.
	ctx, cancel := context.WithTimeout(context.Background(), 8500*time.Millisecond)
	defer cancel()
	started := time.Now()
	reply, err := provider.Reply(ctx, "next?", Context{})
	if err != nil {
		t.Fatal(err)
	}
	if elapsed := time.Since(started); elapsed > 3*time.Second {
		t.Fatalf("waited %s for a slow model; the reply would miss the deadline", elapsed)
	}
	if ctx.Err() != nil {
		t.Fatal("no time was left to save the reply")
	}
	if len(reply.Blocks) == 0 || !strings.Contains(reply.Blocks[0].Text, "unavailable right now") {
		t.Fatalf("slow model gave no honest fallback: %+v", reply.Blocks)
	}
}

func TestOpenAIRequestShape(t *testing.T) {
	provider, err := New(Options{APIKey: "sk-test", BaseURL: "https://api.openai.com/v1", Model: "gpt-6-luna", ReasoningEffort: "None"})
	if err != nil {
		t.Fatal(err)
	}
	if provider.Mode() != "openai" {
		t.Fatalf("mode = %s", provider.Mode())
	}
	openAI := provider.(goProvider)
	for _, tc := range []struct {
		effort         string
		wantTokens     int
		wantTemp, sent bool
	}{{"none", 1400, true, true}, {"low", 4000, false, true}, {"", 4000, false, false}} {
		openAI.effort = tc.effort
		body := openAI.requestBody(nil)
		if body["store"] != false {
			t.Fatal("OpenAI requests must not opt into stored completions")
		}
		if _, ok := body["max_tokens"]; ok {
			t.Fatalf("effort %q: OpenAI rejects max_tokens", tc.effort)
		}
		if body["max_completion_tokens"] != tc.wantTokens {
			t.Fatalf("effort %q: max_completion_tokens = %v", tc.effort, body["max_completion_tokens"])
		}
		if _, ok := body["temperature"]; ok != tc.wantTemp {
			t.Fatalf("effort %q: temperature sent = %v", tc.effort, ok)
		}
		if _, ok := body["reasoning_effort"]; ok != tc.sent {
			t.Fatalf("effort %q: reasoning_effort sent = %v", tc.effort, ok)
		}
	}
}

func TestOpenCodeRequestShapeIsUnchanged(t *testing.T) {
	provider, err := New(Options{APIKey: "oc_test"})
	if err != nil {
		t.Fatal(err)
	}
	body := provider.(goProvider).requestBody(nil)
	if body["max_tokens"] != 1400 || body["temperature"] != 0.2 || body["model"] != defaultGoModel {
		t.Fatalf("body = %v", body)
	}
	if _, ok := body["reasoning_effort"]; ok {
		t.Fatal("unexpected reasoning_effort")
	}
}

func TestNewRejectsMisroutedProviderSettings(t *testing.T) {
	for name, opts := range map[string]Options{
		"OpenAI key sent to OpenCode": {APIKey: "sk-proj-test"},
		"OpenAI without model":        {APIKey: "sk-test", BaseURL: "https://api.openai.com/v1"},
		"bad reasoning effort":        {APIKey: "sk-test", BaseURL: "https://api.openai.com/v1", Model: "gpt-6-luna", ReasoningEffort: "low; drop"},
		"plain HTTP":                  {APIKey: "sk-test", BaseURL: "http://api.openai.com/v1", Model: "gpt-6-luna"},
	} {
		if _, err := New(opts); err == nil {
			t.Fatalf("%s: accepted", name)
		}
	}
}

func TestProviderErrorsAreLogged(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte(`{"error":{"message":"Unsupported parameter: 'temperature'"}}`))
	}))
	defer server.Close()
	var logs strings.Builder
	provider, err := New(Options{APIKey: "k", BaseURL: server.URL, Client: server.Client(), Logger: slog.New(slog.NewTextHandler(&logs, nil))})
	if err != nil {
		t.Fatal(err)
	}
	reply, err := provider.Reply(context.Background(), "secret question", Context{})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(reply.Text, "unavailable") {
		t.Fatalf("reply = %q", reply.Text)
	}
	if !strings.Contains(logs.String(), "status=400") || !strings.Contains(logs.String(), "Unsupported parameter") || strings.Contains(logs.String(), "secret question") {
		t.Fatalf("logs = %s", logs.String())
	}
}
