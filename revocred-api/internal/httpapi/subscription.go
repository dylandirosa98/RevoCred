package httpapi

import (
	"context"
	"crypto/subtle"
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"github.com/revocred/revocred-api/internal/revenuecat"
	"github.com/revocred/revocred-api/internal/store"
)

// SubscriberLookup reads current RevenueCat state; *revenuecat.Client
// implements it.
type SubscriberLookup interface {
	Entitlement(ctx context.Context, appUserID, entitlement string) (revenuecat.Subscriber, error)
}

type aiPlanResponse struct {
	Plan        string     `json:"plan"`
	Source      *string    `json:"source"`
	Used        int        `json:"used"`
	Limit       int        `json:"limit"`
	Remaining   int        `json:"remaining"`
	ExpiresAt   *time.Time `json:"expires_at"`
	NextResetAt *time.Time `json:"next_reset_at"`
	// AIAvailable is false when the server runs basic answers only.
	AIAvailable bool `json:"ai_available"`
	// PurchasesEnabled is true when the server accepts RevenueCat events, so
	// the app may offer the subscription.
	PurchasesEnabled bool   `json:"purchases_enabled"`
	EntitlementID    string `json:"entitlement_id"`
}

func (a *API) aiPlan(w http.ResponseWriter, r *http.Request) {
	a.writeAIPlan(w, r, authenticatedUser(r.Context()).ID)
}

// refreshAIPlan re-reads the caller's subscription from RevenueCat, so a
// purchase or restore unlocks at once instead of waiting for the webhook.
func (a *API) refreshAIPlan(w http.ResponseWriter, r *http.Request) {
	userID := authenticatedUser(r.Context()).ID
	if !a.limits.allow("ai-plan-refresh:"+userID, 10, time.Now()) {
		a.tooMany(w, r)
		return
	}
	if a.subscribers != nil && revenuecat.ValidUserID(userID) {
		if err := a.refreshSubscriber(r.Context(), userID, "", time.Now().UTC()); err != nil {
			// The stored plan is still a correct answer; the webhook catches up.
			a.logger.WarnContext(r.Context(), "revenuecat refresh failed", "request_id", requestIDFromContext(r.Context()), "error", err)
		}
	}
	a.writeAIPlan(w, r, userID)
}

func (a *API) writeAIPlan(w http.ResponseWriter, r *http.Request, userID string) {
	plan, err := a.repository.AIPlan(r.Context(), userID, a.chatFreeDailyAILimit, a.chatDailyAILimit)
	if err != nil {
		a.internalError(w, r, err)
		return
	}
	response := aiPlanResponse{
		Plan: "free", Used: plan.Used, Limit: plan.Limit, Remaining: max(plan.Limit-plan.Used, 0),
		NextResetAt: plan.NextResetAt, AIAvailable: a.chatProvider.Mode() != "deterministic",
		PurchasesEnabled: a.revenueCatAuth != "", EntitlementID: a.revenueCatEntitlement,
	}
	if plan.Subscriber {
		response.Plan, response.ExpiresAt = "subscriber", plan.ExpiresAt
		source := plan.Source
		response.Source = &source
	}
	writeData(w, http.StatusOK, response)
}

func (a *API) refreshSubscriber(ctx context.Context, userID, eventID string, at time.Time) error {
	state, err := a.subscribers.Entitlement(ctx, userID, a.revenueCatEntitlement)
	if err != nil {
		return err
	}
	now := time.Now().UTC()
	expires := state.ExpiresAt
	if state.Sandbox && !a.revenueCatAllowSandbox {
		return nil
	}
	if !state.Active {
		expires = now
	}
	if expires.After(now.AddDate(0, 13, 0)) {
		return errors.New("RevenueCat expiry is implausibly far away")
	}
	_, err = a.repository.ApplyRevenueCatEntitlement(ctx, store.EntitlementUpdate{
		EventID: eventID, UserID: userID, EventAt: at, ExpiresAt: expires, ProductID: state.ProductID,
	})
	return err
}

// revenueCatWebhook applies RevenueCat subscription events. RevenueCat sends
// the configured Authorization value verbatim and retries on non-2xx, so
// events that intentionally change nothing still answer 200.
func (a *API) revenueCatWebhook(w http.ResponseWriter, r *http.Request) {
	if a.revenueCatAuth == "" {
		writeError(w, r, http.StatusNotFound, "not_found", "not found", nil)
		return
	}
	if subtle.ConstantTimeCompare([]byte(r.Header.Get("Authorization")), []byte(a.revenueCatAuth)) != 1 {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "invalid webhook authorization", nil)
		return
	}
	var payload revenuecat.Webhook
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, maxRequestBodyBytes)).Decode(&payload); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_json", "request body must be a RevenueCat webhook", nil)
		return
	}
	event := payload.Event
	log := func(outcome string) {
		a.logger.InfoContext(r.Context(), "revenuecat webhook", "request_id", requestIDFromContext(r.Context()),
			"event_id", event.ID, "type", event.Type, "environment", event.Environment, "outcome", outcome)
	}
	if event.Sandbox() && !a.revenueCatAllowSandbox {
		log("sandbox_ignored")
		writeData(w, http.StatusOK, map[string]string{"status": "ignored"})
		return
	}
	actions, refresh, err := revenuecat.Plan(event, a.revenueCatEntitlement)
	if errors.Is(err, revenuecat.ErrIgnored) {
		log("ignored")
		writeData(w, http.StatusOK, map[string]string{"status": "ignored"})
		return
	}
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_event", err.Error(), nil)
		return
	}
	if len(refresh) > 0 && a.subscribers == nil {
		writeError(w, r, http.StatusServiceUnavailable, "subscription_lookup_unavailable", "transfer requires RevenueCat subscriber lookup", nil)
		return
	}
	for _, action := range actions {
		outcome, err := a.repository.ApplyRevenueCatEntitlement(r.Context(), store.EntitlementUpdate{
			// One idempotency key per account, so a TRANSFER retry after a
			// partial failure finishes the remaining accounts.
			EventID: event.ID + ":" + action.UserID, UserID: action.UserID,
			EventAt: event.EventAt(), ExpiresAt: action.ExpiresAt, ProductID: action.ProductID,
		})
		if err != nil {
			a.internalError(w, r, err)
			return
		}
		log(outcome)
	}
	for _, userID := range refresh {
		if err := a.refreshSubscriber(r.Context(), userID, event.ID+":to:"+userID, event.EventAt()); err != nil {
			a.internalError(w, r, err)
			return
		}
		log("transfer_refreshed")
	}
	writeData(w, http.StatusOK, map[string]string{"status": "processed"})
}
