package revenuecat

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestClientReadsEntitlement(t *testing.T) {
	expires := time.Now().Add(48 * time.Hour).UTC().Truncate(time.Second)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer sk_test" || r.URL.Path != "/v1/subscribers/11111111-1111-4111-8111-111111111111" {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		_, _ = w.Write([]byte(`{"subscriber":{"entitlements":{"revo_ai":{"expires_date":"` + expires.Format(time.RFC3339) + `","product_identifier":"monthly"},"lifetime":{"expires_date":null,"product_identifier":"x"}},"subscriptions":{"monthly":{"is_sandbox":true}}}}`))
	}))
	defer server.Close()
	client := &Client{APIKey: "sk_test", BaseURL: server.URL, HTTP: server.Client()}
	got, err := client.Entitlement(context.Background(), "11111111-1111-4111-8111-111111111111", "revo_ai")
	if err != nil || !got.Active || !got.ExpiresAt.Equal(expires) || got.ProductID != "monthly" || !got.Sandbox {
		t.Fatalf("entitlement: %+v %v", got, err)
	}
	if got, err = client.Entitlement(context.Background(), "11111111-1111-4111-8111-111111111111", "lifetime"); err != nil || got.Active {
		t.Fatalf("open-ended entitlement must not count: %+v %v", got, err)
	}
	if got, err = client.Entitlement(context.Background(), "11111111-1111-4111-8111-111111111111", "missing"); err != nil || got.Active {
		t.Fatalf("missing entitlement: %+v %v", got, err)
	}
	if _, err = (&Client{APIKey: "sk_bad", BaseURL: server.URL}).Entitlement(context.Background(), "11111111-1111-4111-8111-111111111111", "revo_ai"); err == nil {
		t.Fatal("unauthorized lookup succeeded")
	}
}

func TestPlanProductChangeUsesNewProduct(t *testing.T) {
	expires := int64(1764000000000)
	actions, _, err := Plan(Event{ID: "e", Type: "PRODUCT_CHANGE", EventTimestampMS: 1, AppUserID: "11111111-1111-4111-8111-111111111111", ExpirationAtMS: &expires, ProductID: "old", NewProductID: "new", EntitlementIDs: []string{"revo_ai"}}, "revo_ai")
	if err != nil || len(actions) != 1 || actions[0].ProductID != "new" {
		t.Fatalf("product change: %+v %v", actions, err)
	}
	actions, _, err = Plan(Event{ID: "e", Type: "RENEWAL", EventTimestampMS: 1, AppUserID: "11111111-1111-4111-8111-11111111111A", ExpirationAtMS: &expires, EntitlementIDs: []string{"revo_ai"}}, "revo_ai")
	if err != nil || actions[0].UserID != "11111111-1111-4111-8111-11111111111a" {
		t.Fatalf("user ids are normalised: %+v %v", actions, err)
	}
}

func TestPlanSubscriptionLifecycle(t *testing.T) {
	expiry := time.Now().Add(30 * 24 * time.Hour).UnixMilli()
	for _, kind := range []string{"INITIAL_PURCHASE", "RENEWAL", "UNCANCELLATION", "PRODUCT_CHANGE", "CANCELLATION"} {
		t.Run(kind, func(t *testing.T) {
			event := Event{ID: kind, Type: kind, EventTimestampMS: time.Now().UnixMilli(), AppUserID: "11111111-1111-4111-8111-111111111111", ExpirationAtMS: &expiry, EntitlementIDs: []string{"revo_ai"}}
			actions, _, err := Plan(event, "revo_ai")
			if err != nil || len(actions) != 1 || !actions[0].ExpiresAt.Equal(time.UnixMilli(expiry)) {
				t.Fatalf("lifecycle: %+v %v", actions, err)
			}
		})
	}
}
