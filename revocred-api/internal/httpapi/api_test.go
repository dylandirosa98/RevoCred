package httpapi

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/revocred/revocred-api/internal/auth"
	"github.com/revocred/revocred-api/internal/chat"
	"github.com/revocred/revocred-api/internal/domain"
)

type fakeAuthenticator struct {
	user  auth.User
	err   error
	token string
}

func (a *fakeAuthenticator) Authenticate(_ context.Context, token string) (auth.User, error) {
	a.token = token
	return a.user, a.err
}

type fakeRepository struct {
	cards      []domain.CatalogCard
	wallet     []domain.WalletCard
	savedInput domain.RecommendationInput
}

func (f *fakeRepository) Ping(context.Context) error { return nil }
func (f *fakeRepository) Bootstrap(context.Context, string) (domain.Bootstrap, error) {
	return domain.Bootstrap{Wallet: []domain.WalletCard{}, Catalog: []domain.CatalogCard{}, QuickPrompts: []string{}}, nil
}
func (f *fakeRepository) ListCatalog(context.Context) ([]domain.CatalogCard, error) {
	if f.cards == nil {
		return []domain.CatalogCard{}, nil
	}
	return f.cards, nil
}
func (f *fakeRepository) GetProfile(context.Context, string) (*domain.Profile, error) {
	return nil, nil
}
func (f *fakeRepository) UpsertProfile(_ context.Context, userID string, profile domain.Profile) (domain.Profile, error) {
	profile.UserID = userID
	return profile, nil
}
func (f *fakeRepository) ListWallet(context.Context, string) ([]domain.WalletCard, error) {
	return f.wallet, nil
}
func (f *fakeRepository) CreateWalletCard(context.Context, string, domain.CreateWalletCard) (domain.WalletCard, error) {
	return domain.WalletCard{}, nil
}
func (f *fakeRepository) DeleteWalletCard(context.Context, string, string) error { return nil }
func (f *fakeRepository) SaveRecommendation(_ context.Context, _ string, input domain.RecommendationInput, result domain.RecommendationResult) (domain.RecommendationResult, error) {
	f.savedInput = input
	return result, nil
}
func (f *fakeRepository) ListMessages(context.Context, string, int) ([]domain.ChatMessage, error) {
	return []domain.ChatMessage{}, nil
}
func (f *fakeRepository) AppendChatExchange(context.Context, string, string, string) ([]domain.ChatMessage, error) {
	return []domain.ChatMessage{}, nil
}

type fakeRecommender struct{}

func (fakeRecommender) Recommend(domain.RecommendationInput, []domain.CatalogCard) domain.RecommendationResult {
	return domain.RecommendationResult{EngineVersion: "test", DatasetVersion: "test", Items: []domain.RecommendationItem{}, Exclusions: []domain.RecommendationExclusion{}}
}

type fakeChatProvider struct{}

func (fakeChatProvider) Reply(context.Context, string, chat.Context) (string, error) {
	return "reply", nil
}

func testHandler(authenticator auth.Authenticator) http.Handler {
	return New(
		&fakeRepository{}, authenticator, fakeRecommender{}, fakeChatProvider{},
		slog.New(slog.NewTextHandler(io.Discard, nil)), []string{"https://app.example.test"}, time.Second,
	)
}

func TestPublicAndProtectedRouting(t *testing.T) {
	authenticator := &fakeAuthenticator{user: auth.User{ID: "11111111-1111-4111-8111-111111111111"}}
	handler := testHandler(authenticator)

	healthRequest := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	healthResponse := httptest.NewRecorder()
	handler.ServeHTTP(healthResponse, healthRequest)
	if healthResponse.Code != http.StatusOK {
		t.Fatalf("health status = %d, body = %s", healthResponse.Code, healthResponse.Body.String())
	}
	if healthResponse.Header().Get("X-Request-ID") == "" {
		t.Fatal("health response missing request ID")
	}

	unauthorizedRequest := httptest.NewRequest(http.MethodGet, "/v1/cards", nil)
	unauthorizedResponse := httptest.NewRecorder()
	handler.ServeHTTP(unauthorizedResponse, unauthorizedRequest)
	if unauthorizedResponse.Code != http.StatusUnauthorized || !strings.Contains(unauthorizedResponse.Body.String(), `"code":"unauthorized"`) {
		t.Fatalf("protected route without token: status = %d, body = %s", unauthorizedResponse.Code, unauthorizedResponse.Body.String())
	}

	authorizedRequest := httptest.NewRequest(http.MethodGet, "/v1/cards", nil)
	authorizedRequest.Header.Set("Authorization", "Bearer valid-token")
	authorizedResponse := httptest.NewRecorder()
	handler.ServeHTTP(authorizedResponse, authorizedRequest)
	if authorizedResponse.Code != http.StatusOK || authenticator.token != "valid-token" {
		t.Fatalf("protected route with token: status = %d, token = %q, body = %s", authorizedResponse.Code, authenticator.token, authorizedResponse.Body.String())
	}
}

func TestAuthenticationMiddlewareMapsProviderResults(t *testing.T) {
	tests := []struct {
		name string
		err  error
		want int
	}{
		{name: "invalid token", err: auth.ErrUnauthorized, want: http.StatusUnauthorized},
		{name: "provider unavailable", err: errors.New("network down"), want: http.StatusServiceUnavailable},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			handler := testHandler(&fakeAuthenticator{err: test.err})
			request := httptest.NewRequest(http.MethodGet, "/v1/bootstrap", nil)
			request.Header.Set("Authorization", "Bearer token")
			response := httptest.NewRecorder()
			handler.ServeHTTP(response, request)
			if response.Code != test.want {
				t.Fatalf("status = %d, want %d, body = %s", response.Code, test.want, response.Body.String())
			}
		})
	}
}

func TestCORSUsesExplicitOrigins(t *testing.T) {
	handler := testHandler(&fakeAuthenticator{})

	allowed := httptest.NewRequest(http.MethodOptions, "/v1/cards", nil)
	allowed.Header.Set("Origin", "https://app.example.test")
	allowedResponse := httptest.NewRecorder()
	handler.ServeHTTP(allowedResponse, allowed)
	if allowedResponse.Code != http.StatusNoContent || allowedResponse.Header().Get("Access-Control-Allow-Origin") != "https://app.example.test" {
		t.Fatalf("allowed preflight failed: status = %d, headers = %#v", allowedResponse.Code, allowedResponse.Header())
	}

	blocked := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	blocked.Header.Set("Origin", "https://evil.example.test")
	blockedResponse := httptest.NewRecorder()
	handler.ServeHTTP(blockedResponse, blocked)
	if blockedResponse.Code != http.StatusForbidden {
		t.Fatalf("blocked origin status = %d, body = %s", blockedResponse.Code, blockedResponse.Body.String())
	}
}

func TestRecommendationUsesPersistedActiveWalletForExclusions(t *testing.T) {
	repository := &fakeRepository{wallet: []domain.WalletCard{
		{CatalogCardID: "active-card", Status: "active"},
		{CatalogCardID: "inactive-card", Status: "inactive"},
	}}
	handler := New(
		repository,
		&fakeAuthenticator{user: auth.User{ID: "11111111-1111-4111-8111-111111111111"}},
		fakeRecommender{}, fakeChatProvider{},
		slog.New(slog.NewTextHandler(io.Discard, nil)), []string{"https://app.example.test"}, time.Second,
	)
	body := `{"monthly_category_spend":{"food":10000},"fee_tolerance_cents":0,"travel_scope":"none","rewards_goal":"cash_back","credit_tier":"good","existing_card_ids":["client-lie"]}`
	request := httptest.NewRequest(http.MethodPost, "/v1/recommendations", strings.NewReader(body))
	request.Header.Set("Authorization", "Bearer token")
	request.Header.Set("Content-Type", "application/json")
	response := httptest.NewRecorder()

	handler.ServeHTTP(response, request)
	if response.Code != http.StatusCreated {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	if len(repository.savedInput.ExistingCardIDs) != 1 || repository.savedInput.ExistingCardIDs[0] != "active-card" {
		t.Fatalf("saved exclusions = %#v", repository.savedInput.ExistingCardIDs)
	}
}

func TestRecommendationHandlerRejectsUnknownFields(t *testing.T) {
	handler := testHandler(&fakeAuthenticator{user: auth.User{ID: "11111111-1111-4111-8111-111111111111"}})
	request := httptest.NewRequest(http.MethodPost, "/v1/recommendations", strings.NewReader(`{"unexpected":true}`))
	request.Header.Set("Authorization", "Bearer token")
	request.Header.Set("Content-Type", "application/json")
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	if response.Code != http.StatusBadRequest || !strings.Contains(response.Body.String(), `"code":"invalid_json"`) {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
}
