package httpapi

import (
	"context"
	"errors"
	"io"
	"net/http"
	"time"

	"github.com/revocred/revocred-api/internal/reminders"
	"github.com/revocred/revocred-api/internal/store"
)

func (a *API) buildReminderFeed(ctx context.Context, userID string) (reminders.Feed, error) {
	boot, err := a.repository.Bootstrap(ctx, userID)
	if err != nil {
		return reminders.Feed{}, err
	}
	states, err := a.repository.ListReminderStates(ctx, userID)
	if err != nil {
		return reminders.Feed{}, err
	}
	return reminders.Build(time.Now().UTC(), boot.Wallet, boot.Playbook, states), nil
}

func (a *API) getReminders(w http.ResponseWriter, r *http.Request) {
	feed, err := a.buildReminderFeed(r.Context(), authenticatedUser(r.Context()).ID)
	if err != nil {
		a.internalError(w, r, err)
		return
	}
	writeData(w, http.StatusOK, feed)
}

func (a *API) putReminderState(w http.ResponseWriter, r *http.Request) {
	key := r.PathValue("key")
	if !validReminderKey(key) {
		writeError(w, r, http.StatusUnprocessableEntity, "validation_error", "request validation failed", map[string]string{"key": "invalid reminder key"})
		return
	}
	var input struct {
		Status     string `json:"status"`
		SnoozeDays *int   `json:"snooze_days,omitempty"`
	}
	if !a.decodeJSON(w, r, &input) {
		return
	}
	if !oneOf(input.Status, reminders.StatusActive, reminders.StatusCompleted, reminders.StatusDismissed, reminders.StatusSnoozed) {
		writeError(w, r, http.StatusUnprocessableEntity, "validation_error", "request validation failed", map[string]string{"status": "must be active, completed, dismissed, or snoozed"})
		return
	}
	var snoozedUntil *time.Time
	if input.Status == reminders.StatusSnoozed {
		days := 7
		if input.SnoozeDays != nil {
			days = *input.SnoozeDays
		}
		if days < 1 || days > 90 {
			writeError(w, r, http.StatusUnprocessableEntity, "validation_error", "request validation failed", map[string]string{"snooze_days": "must be between 1 and 90"})
			return
		}
		until := time.Now().UTC().Add(time.Duration(days) * 24 * time.Hour)
		snoozedUntil = &until
	}

	userID := authenticatedUser(r.Context()).ID
	var err error
	if input.Status == reminders.StatusActive {
		err = a.repository.DeleteReminderState(r.Context(), userID, key)
	} else {
		err = a.repository.UpsertReminderState(r.Context(), userID, key, input.Status, snoozedUntil)
	}
	if err != nil {
		a.internalError(w, r, err)
		return
	}
	feed, err := a.buildReminderFeed(r.Context(), userID)
	if err != nil {
		a.internalError(w, r, err)
		return
	}
	writeData(w, http.StatusOK, feed)
}

func (a *API) dismissReminder(w http.ResponseWriter, r *http.Request) {
	key := r.PathValue("key")
	if !validReminderKey(key) {
		writeError(w, r, http.StatusUnprocessableEntity, "validation_error", "request validation failed", map[string]string{"key": "invalid reminder key"})
		return
	}
	// Accept an empty body or empty JSON object.
	if r.Body != nil {
		_, _ = io.Copy(io.Discard, http.MaxBytesReader(w, r.Body, 1024))
	}
	userID := authenticatedUser(r.Context()).ID
	if err := a.repository.UpsertReminderState(r.Context(), userID, key, reminders.StatusDismissed, nil); err != nil {
		a.internalError(w, r, err)
		return
	}
	feed, err := a.buildReminderFeed(r.Context(), userID)
	if err != nil {
		a.internalError(w, r, err)
		return
	}
	writeData(w, http.StatusOK, feed)
}

func (a *API) putWalletRenewalMonth(w http.ResponseWriter, r *http.Request) {
	walletCardID := r.PathValue("id")
	if !validUUID(walletCardID) {
		writeError(w, r, http.StatusUnprocessableEntity, "validation_error", "request validation failed", map[string]string{"id": "must be a UUID"})
		return
	}
	var input struct {
		RenewalMonth *int `json:"renewal_month"`
	}
	if !a.decodeJSON(w, r, &input) {
		return
	}
	if input.RenewalMonth != nil && (*input.RenewalMonth < 1 || *input.RenewalMonth > 12) {
		writeError(w, r, http.StatusUnprocessableEntity, "validation_error", "request validation failed", map[string]string{"renewal_month": "must be between 1 and 12"})
		return
	}
	item, err := a.repository.UpdateWalletRenewalMonth(r.Context(), authenticatedUser(r.Context()).ID, walletCardID, input.RenewalMonth)
	if errors.Is(err, store.ErrNotFound) {
		writeError(w, r, http.StatusNotFound, "wallet_card_not_found", "wallet card not found", nil)
		return
	}
	if err != nil {
		a.internalError(w, r, err)
		return
	}
	writeData(w, http.StatusOK, item)
}

func validReminderKey(key string) bool {
	if len(key) < 1 || len(key) > 160 {
		return false
	}
	for _, r := range key {
		switch {
		case r >= 'a' && r <= 'z':
		case r >= 'A' && r <= 'Z':
		case r >= '0' && r <= '9':
		case r == '.', r == '_', r == '-', r == ':':
		default:
			return false
		}
	}
	return true
}
