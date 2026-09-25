package chat

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

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
	if !strings.Contains(reply, "Freedom Unlimited") {
		t.Fatalf("reply = %q", reply)
	}
	if captured.auth != "Bearer test-key" || captured.ua != userAgent || captured.session != "11111111-1111-4111-8111-111111111111" {
		t.Fatalf("headers = %+v", captured)
	}
	if captured.model != defaultGoModel || !strings.Contains(captured.system, `"food":50000`) || !strings.Contains(captured.system, "Freedom Unlimited") {
		t.Fatalf("payload = %+v", captured)
	}
}

func TestGoProviderFallsBackWhenModelInventsACard(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`{"choices":[{"message":{"content":"Apply for the Sapphire Reserve immediately."}}]}`))
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
	if strings.Contains(reply, "Sapphire Reserve") || !strings.Contains(reply, "Quicksilver") {
		t.Fatalf("fallback missing: %q", reply)
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
