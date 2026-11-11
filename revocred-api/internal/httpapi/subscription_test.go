package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/revocred/revocred-api/internal/auth"
	"github.com/revocred/revocred-api/internal/revenuecat"
)

const testWebhookAuth = "Bearer test-only-revenuecat-webhook-secret-0123"

type fakeSubscribers struct {
	state revenuecat.Subscriber
	err   error
	asked []string
}

func (f *fakeSubscribers) Entitlement(_ context.Context, appUserID, entitlement string) (revenuecat.Subscriber, error) {
	f.asked = append(f.asked, appUserID+"/"+entitlement)
	return f.state, f.err
}

func subscriptionHandler(repo *fakeRepository, options Options) http.Handler {
	free := 3
	options.ChatDailyAILimit, options.ChatFreeDailyAILimit = 60, &free
	return New(repo, &fakeAuthenticator{user: auth.User{ID: testUser}}, fakeRecommender{}, fakeChatProvider{},
		slog.New(slog.NewTextHandler(io.Discard, nil)), nil, 5*time.Second, options)
}

func webhook(handler http.Handler, authorization, body string) *httptest.ResponseRecorder {
	request := httptest.NewRequest(http.MethodPost, "/v1/webhooks/revenuecat", strings.NewReader(body))
	if authorization != "" {
		request.Header.Set("Authorization", authorization)
	}
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	return response
}

func eventBody(fields string) string {
	return `{"api_version":"1.0","event":{"id":"evt-1","event_timestamp_ms":1762000000000,` + fields + `}}`
}

func TestRevenueCatWebhookIsDisabledWithoutSecret(t *testing.T) {
	repo := &fakeRepository{}
	response := webhook(subscriptionHandler(repo, Options{}), testWebhookAuth, eventBody(`"type":"INITIAL_PURCHASE"`))
	if response.Code != http.StatusNotFound || len(repo.entitlements) != 0 {
		t.Fatalf("disabled webhook: %d %s", response.Code, response.Body.String())
	}
}

func TestRevenueCatWebhookRequiresExactAuthorization(t *testing.T) {
	repo := &fakeRepository{}
	handler := subscriptionHandler(repo, Options{RevenueCatWebhookAuth: testWebhookAuth})
	body := eventBody(`"type":"INITIAL_PURCHASE","app_user_id":"` + testUser + `","expiration_at_ms":1764000000000,"entitlement_ids":["revo_ai"]`)
	for _, header := range []string{"", "Bearer wrong", testWebhookAuth + "x", strings.TrimPrefix(testWebhookAuth, "Bearer ")} {
		if response := webhook(handler, header, body); response.Code != http.StatusUnauthorized {
			t.Fatalf("authorization %q: %d", header, response.Code)
		}
	}
	if len(repo.entitlements) != 0 {
		t.Fatal("unauthorized webhook changed entitlements")
	}
}

func TestRevenueCatWebhookGrantsAndExpires(t *testing.T) {
	repo := &fakeRepository{}
	handler := subscriptionHandler(repo, Options{RevenueCatWebhookAuth: testWebhookAuth})
	response := webhook(handler, testWebhookAuth, eventBody(`"type":"INITIAL_PURCHASE","app_user_id":"`+testUser+`","expiration_at_ms":1764000000000,"product_id":"com.revocred.app.revo_ai_monthly","entitlement_ids":["revo_ai"],"environment":"PRODUCTION","unknown_field":{"kept":"ignored"}`))
	if response.Code != http.StatusOK || len(repo.entitlements) != 1 {
		t.Fatalf("purchase: %d %s", response.Code, response.Body.String())
	}
	got := repo.entitlements[0]
	if got.UserID != testUser || got.EventID != "evt-1:"+testUser || !got.ExpiresAt.Equal(time.UnixMilli(1764000000000)) ||
		!got.EventAt.Equal(time.UnixMilli(1762000000000)) || got.ProductID != "com.revocred.app.revo_ai_monthly" {
		t.Fatalf("purchase update: %+v", got)
	}
	// EXPIRATION never leaves access open past the event.
	response = webhook(handler, testWebhookAuth, eventBody(`"type":"EXPIRATION","app_user_id":"`+testUser+`","expiration_at_ms":1769000000000,"entitlement_ids":["revo_ai"]`))
	if response.Code != http.StatusOK || len(repo.entitlements) != 2 || !repo.entitlements[1].ExpiresAt.Equal(time.UnixMilli(1762000000000)) {
		t.Fatalf("expiration: %d %+v", response.Code, repo.entitlements)
	}
}

func TestRevenueCatWebhookIgnoresWhatItShould(t *testing.T) {
	for name, fields := range map[string]string{
		"anonymous user":        `"type":"INITIAL_PURCHASE","app_user_id":"$RCAnonymousID:abc","expiration_at_ms":1764000000000,"entitlement_ids":["revo_ai"]`,
		"other entitlement":     `"type":"RENEWAL","app_user_id":"` + testUser + `","expiration_at_ms":1764000000000,"entitlement_ids":["other"]`,
		"no entitlement":        `"type":"RENEWAL","app_user_id":"` + testUser + `","expiration_at_ms":1764000000000`,
		"no expiry":             `"type":"RENEWAL","app_user_id":"` + testUser + `","entitlement_ids":["revo_ai"]`,
		"test event":            `"type":"TEST","app_user_id":"` + testUser + `"`,
		"billing issue":         `"type":"BILLING_ISSUE","app_user_id":"` + testUser + `","entitlement_ids":["revo_ai"],"expiration_at_ms":1764000000000`,
		"sandbox in production": `"type":"INITIAL_PURCHASE","environment":"SANDBOX","app_user_id":"` + testUser + `","expiration_at_ms":1764000000000,"entitlement_ids":["revo_ai"]`,
	} {
		repo := &fakeRepository{}
		response := webhook(subscriptionHandler(repo, Options{RevenueCatWebhookAuth: testWebhookAuth}), testWebhookAuth, eventBody(fields))
		if response.Code != http.StatusOK || len(repo.entitlements) != 0 || !strings.Contains(response.Body.String(), "ignored") {
			t.Fatalf("%s: %d %s %+v", name, response.Code, response.Body.String(), repo.entitlements)
		}
	}
	repo := &fakeRepository{}
	response := webhook(subscriptionHandler(repo, Options{RevenueCatWebhookAuth: testWebhookAuth, RevenueCatAllowSandbox: true}), testWebhookAuth,
		eventBody(`"type":"INITIAL_PURCHASE","environment":"SANDBOX","app_user_id":"`+testUser+`","expiration_at_ms":1764000000000,"entitlement_ids":["revo_ai"]`))
	if response.Code != http.StatusOK || len(repo.entitlements) != 1 {
		t.Fatalf("allowed sandbox: %d %+v", response.Code, repo.entitlements)
	}
	response = webhook(subscriptionHandler(repo, Options{RevenueCatWebhookAuth: testWebhookAuth}), testWebhookAuth, `{"event":`)
	if response.Code != http.StatusBadRequest {
		t.Fatalf("malformed body: %d", response.Code)
	}
	response = webhook(subscriptionHandler(repo, Options{RevenueCatWebhookAuth: testWebhookAuth}), testWebhookAuth, `{"event":{"type":"RENEWAL"}}`)
	if response.Code != http.StatusBadRequest {
		t.Fatalf("event without id: %d", response.Code)
	}
}

func TestRevenueCatRefundCancellationEndsAccessNow(t *testing.T) {
	repo := &fakeRepository{}
	handler := subscriptionHandler(repo, Options{RevenueCatWebhookAuth: testWebhookAuth})
	webhook(handler, testWebhookAuth, eventBody(`"type":"CANCELLATION","cancel_reason":"UNSUBSCRIBE","app_user_id":"`+testUser+`","expiration_at_ms":1764000000000,"entitlement_ids":["revo_ai"]`))
	webhook(handler, testWebhookAuth, eventBody(`"type":"CANCELLATION","cancel_reason":"CUSTOMER_SUPPORT","app_user_id":"`+testUser+`","expiration_at_ms":1764000000000,"entitlement_ids":["revo_ai"]`))
	if len(repo.entitlements) != 2 || !repo.entitlements[0].ExpiresAt.Equal(time.UnixMilli(1764000000000)) || !repo.entitlements[1].ExpiresAt.Equal(time.UnixMilli(1762000000000)) {
		t.Fatalf("cancellations: %+v", repo.entitlements)
	}
}

func TestRevenueCatTransferMovesAccess(t *testing.T) {
	const newOwner = "22222222-2222-4222-8222-222222222222"
	body := eventBody(`"type":"TRANSFER","transferred_from":["` + testUser + `","$RCAnonymousID:x"],"transferred_to":["` + newOwner + `"]`)
	// Without a secret key only the previous owner changes.
	repo := &fakeRepository{}
	if response := webhook(subscriptionHandler(repo, Options{RevenueCatWebhookAuth: testWebhookAuth}), testWebhookAuth, body); response.Code != http.StatusOK || len(repo.entitlements) != 1 || repo.entitlements[0].UserID != testUser {
		t.Fatalf("transfer without lookup: %d %+v", response.Code, repo.entitlements)
	}
	expires := time.Now().Add(20 * 24 * time.Hour).UTC().Truncate(time.Second)
	subscribers := &fakeSubscribers{state: revenuecat.Subscriber{Active: true, ExpiresAt: expires, ProductID: "com.revocred.app.revo_ai_monthly"}}
	repo = &fakeRepository{}
	handler := subscriptionHandler(repo, Options{RevenueCatWebhookAuth: testWebhookAuth, RevenueCatSubscribers: subscribers})
	if response := webhook(handler, testWebhookAuth, body); response.Code != http.StatusOK || len(repo.entitlements) != 2 {
		t.Fatalf("transfer with lookup: %d %+v", response.Code, repo.entitlements)
	}
	if got := repo.entitlements[1]; got.UserID != newOwner || got.EventID != "" || !got.ExpiresAt.Equal(expires) || len(subscribers.asked) != 1 || subscribers.asked[0] != newOwner+"/revo_ai" {
		t.Fatalf("new owner: %+v %v", got, subscribers.asked)
	}
	subscribers.err = errors.New("unavailable")
	if response := webhook(handler, testWebhookAuth, body); response.Code != http.StatusInternalServerError {
		t.Fatalf("lookup failure must be retried: %d", response.Code)
	}
}

func decodePlan(t *testing.T, response *httptest.ResponseRecorder) aiPlanResponse {
	t.Helper()
	var envelope struct {
		Data aiPlanResponse `json:"data"`
	}
	if response.Code != http.StatusOK {
		t.Fatalf("plan status %d: %s", response.Code, response.Body.String())
	}
	if err := json.Unmarshal(response.Body.Bytes(), &envelope); err != nil {
		t.Fatal(err)
	}
	return envelope.Data
}

func TestAIPlanReportsUsageAndPurchases(t *testing.T) {
	repo := &fakeRepository{aiUsed: 2}
	response := httptest.NewRecorder()
	subscriptionHandler(repo, Options{}).ServeHTTP(response, chatRequest(http.MethodGet, "/v1/ai-plan", ""))
	plan := decodePlan(t, response)
	if plan.Plan != "free" || plan.Used != 2 || plan.Limit != 3 || plan.Remaining != 1 || plan.Source != nil || plan.PurchasesEnabled || plan.EntitlementID != "revo_ai" {
		t.Fatalf("free plan: %+v", plan)
	}
	expires := time.Now().Add(time.Hour).UTC()
	repo = &fakeRepository{aiUsed: 70, subscriber: true}
	repo.plan.Source, repo.plan.ExpiresAt = "revenuecat", &expires
	response = httptest.NewRecorder()
	subscriptionHandler(repo, Options{RevenueCatWebhookAuth: testWebhookAuth}).ServeHTTP(response, chatRequest(http.MethodGet, "/v1/ai-plan", ""))
	plan = decodePlan(t, response)
	if plan.Plan != "subscriber" || plan.Limit != 60 || plan.Remaining != 0 || plan.Source == nil || *plan.Source != "revenuecat" || plan.ExpiresAt == nil || !plan.PurchasesEnabled {
		t.Fatalf("subscriber plan: %+v", plan)
	}
	response = httptest.NewRecorder()
	subscriptionHandler(repo, Options{}).ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/v1/ai-plan", nil))
	if response.Code != http.StatusUnauthorized {
		t.Fatalf("plan without sign-in: %d", response.Code)
	}
}

func TestAIPlanRefreshReadsRevenueCat(t *testing.T) {
	repo := &fakeRepository{}
	// Without a secret key a refresh is a plain read.
	response := httptest.NewRecorder()
	subscriptionHandler(repo, Options{RevenueCatWebhookAuth: testWebhookAuth}).ServeHTTP(response, chatRequest(http.MethodPost, "/v1/ai-plan/refresh", ""))
	if decodePlan(t, response); len(repo.entitlements) != 0 {
		t.Fatal("refresh wrote without RevenueCat lookup")
	}
	expires := time.Now().Add(24 * time.Hour).UTC()
	subscribers := &fakeSubscribers{state: revenuecat.Subscriber{Active: true, ExpiresAt: expires, Sandbox: true}}
	handler := subscriptionHandler(repo, Options{RevenueCatWebhookAuth: testWebhookAuth, RevenueCatSubscribers: subscribers})
	response = httptest.NewRecorder()
	handler.ServeHTTP(response, chatRequest(http.MethodPost, "/v1/ai-plan/refresh", ""))
	decodePlan(t, response)
	// A sandbox purchase is not honoured unless sandbox is allowed.
	if len(repo.entitlements) != 1 || repo.entitlements[0].UserID != testUser || repo.entitlements[0].ExpiresAt.After(time.Now()) {
		t.Fatalf("sandbox refresh: %+v", repo.entitlements)
	}
	handler = subscriptionHandler(repo, Options{RevenueCatWebhookAuth: testWebhookAuth, RevenueCatSubscribers: subscribers, RevenueCatAllowSandbox: true})
	response = httptest.NewRecorder()
	handler.ServeHTTP(response, chatRequest(http.MethodPost, "/v1/ai-plan/refresh", ""))
	decodePlan(t, response)
	if len(repo.entitlements) != 2 || !repo.entitlements[1].ExpiresAt.Equal(expires) {
		t.Fatalf("allowed sandbox refresh: %+v", repo.entitlements)
	}
	// Lookup failures still answer with the stored plan.
	subscribers.err = errors.New("unavailable")
	response = httptest.NewRecorder()
	handler.ServeHTTP(response, chatRequest(http.MethodPost, "/v1/ai-plan/refresh", ""))
	decodePlan(t, response)
}
