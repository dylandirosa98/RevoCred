package httpapi

import (
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/revocred/revocred-api/internal/auth"
	"github.com/revocred/revocred-api/internal/domain"
	"github.com/revocred/revocred-api/internal/recommendation"
	"github.com/revocred/revocred-api/internal/reminders"
	"github.com/revocred/revocred-api/internal/strategy"
)

func TestRemindersEndpointsAndRenewalMonth(t *testing.T) {
	walletCardID := "11111111-1111-4111-8111-111111111111"
	repo := &fakeRepository{
		wallet: []domain.WalletCard{
			{
				ID:            walletCardID,
				CatalogCardID: "20000000-0000-4000-8000-000000000016",
				Status:        "active",
				Card: &domain.CatalogCard{
					ID:             "20000000-0000-4000-8000-000000000016",
					Name:           "American Express Gold Card",
					AnnualFeeCents: 32500,
				},
			},
		},
	}
	repo.bootstrapData = &domain.Bootstrap{
		Wallet:   repo.wallet,
		Playbook: &strategy.Playbook{Code: "S04", NextCard: "Chase Freedom Flex"},
	}

	handler := New(
		repo,
		&fakeAuthenticator{user: auth.User{ID: "member-1", Email: "member@example.test"}},
		recommendation.New(),
		fakeChatProvider{},
		slog.New(slog.NewTextHandler(io.Discard, nil)),
		nil,
		5*time.Second,
	)

	// 1. GET /v1/reminders returns sourced Gold credits + renewal month prompt + strategy nudge.
	req := httptest.NewRequest(http.MethodGet, "/v1/reminders", nil)
	req.Header.Set("Authorization", "Bearer tok")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("GET /v1/reminders status=%d body=%s", rec.Code, rec.Body.String())
	}
	var feedResp struct {
		Data reminders.Feed `json:"data"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &feedResp); err != nil {
		t.Fatal(err)
	}
	if feedResp.Data.ActiveCount < 5 {
		t.Fatalf("expected >=5 active reminders (4 Gold credits + renewal prompt + strategy), got %d", feedResp.Data.ActiveCount)
	}
	firstKey := feedResp.Data.Reminders[0].Key
	initialActive := feedResp.Data.ActiveCount

	// 2. PUT /v1/reminders/{key} marks reminder completed and lowers active_count.
	putReq := httptest.NewRequest(http.MethodPut, "/v1/reminders/"+firstKey, strings.NewReader(`{"status":"completed"}`))
	putReq.Header.Set("Authorization", "Bearer tok")
	putRec := httptest.NewRecorder()
	handler.ServeHTTP(putRec, putReq)
	if putRec.Code != http.StatusOK {
		t.Fatalf("PUT reminder status=%d body=%s", putRec.Code, putRec.Body.String())
	}
	var updatedResp struct {
		Data reminders.Feed `json:"data"`
	}
	if err := json.Unmarshal(putRec.Body.Bytes(), &updatedResp); err != nil {
		t.Fatal(err)
	}
	if updatedResp.Data.ActiveCount != initialActive-1 {
		t.Fatalf("expected active_count=%d after complete, got %d", initialActive-1, updatedResp.Data.ActiveCount)
	}

	// 3. POST /v1/reminders/{key}/dismiss dismisses a second reminder.
	secondKey := feedResp.Data.Reminders[1].Key
	dismissReq := httptest.NewRequest(http.MethodPost, "/v1/reminders/"+secondKey+"/dismiss", nil)
	dismissReq.Header.Set("Authorization", "Bearer tok")
	dismissRec := httptest.NewRecorder()
	handler.ServeHTTP(dismissRec, dismissReq)
	if dismissRec.Code != http.StatusOK {
		t.Fatalf("POST dismiss status=%d body=%s", dismissRec.Code, dismissRec.Body.String())
	}
	if err := json.Unmarshal(dismissRec.Body.Bytes(), &updatedResp); err != nil {
		t.Fatal(err)
	}
	if updatedResp.Data.ActiveCount != initialActive-2 {
		t.Fatalf("expected active_count=%d after dismiss, got %d", initialActive-2, updatedResp.Data.ActiveCount)
	}

	// 4. PUT /v1/reminders/{key} with status=active restores it.
	restoreReq := httptest.NewRequest(http.MethodPut, "/v1/reminders/"+firstKey, strings.NewReader(`{"status":"active"}`))
	restoreReq.Header.Set("Authorization", "Bearer tok")
	restoreRec := httptest.NewRecorder()
	handler.ServeHTTP(restoreRec, restoreReq)
	if restoreRec.Code != http.StatusOK {
		t.Fatalf("restore status=%d body=%s", restoreRec.Code, restoreRec.Body.String())
	}
	if err := json.Unmarshal(restoreRec.Body.Bytes(), &updatedResp); err != nil {
		t.Fatal(err)
	}
	if updatedResp.Data.ActiveCount != initialActive-1 {
		t.Fatalf("expected active_count=%d after restore, got %d", initialActive-1, updatedResp.Data.ActiveCount)
	}

	// 5. Validation checks: invalid status and invalid snooze_days.
	badStatus := httptest.NewRequest(http.MethodPut, "/v1/reminders/"+firstKey, strings.NewReader(`{"status":"bogus"}`))
	badStatus.Header.Set("Authorization", "Bearer tok")
	badStatusRec := httptest.NewRecorder()
	handler.ServeHTTP(badStatusRec, badStatus)
	if badStatusRec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("expected 422 on bad status, got %d", badStatusRec.Code)
	}

	badSnooze := httptest.NewRequest(http.MethodPut, "/v1/reminders/"+firstKey, strings.NewReader(`{"status":"snoozed","snooze_days":120}`))
	badSnooze.Header.Set("Authorization", "Bearer tok")
	badSnoozeRec := httptest.NewRecorder()
	handler.ServeHTTP(badSnoozeRec, badSnooze)
	if badSnoozeRec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("expected 422 on bad snooze_days, got %d", badSnoozeRec.Code)
	}

	// 6. PUT /v1/wallet/{id}/renewal-month updates renewal month and clears renewal prompt.
	monthReq := httptest.NewRequest(http.MethodPut, "/v1/wallet/"+walletCardID+"/renewal-month", strings.NewReader(`{"renewal_month":6}`))
	monthReq.Header.Set("Authorization", "Bearer tok")
	monthRec := httptest.NewRecorder()
	handler.ServeHTTP(monthRec, monthReq)
	if monthRec.Code != http.StatusOK {
		t.Fatalf("PUT renewal-month status=%d body=%s", monthRec.Code, monthRec.Body.String())
	}
	if repo.wallet[0].RenewalMonth == nil || *repo.wallet[0].RenewalMonth != 6 {
		t.Fatalf("renewal month not persisted: %+v", repo.wallet[0])
	}

	// Out-of-range renewal month returns 422; unknown UUID returns 404.
	badMonth := httptest.NewRequest(http.MethodPut, "/v1/wallet/"+walletCardID+"/renewal-month", strings.NewReader(`{"renewal_month":13}`))
	badMonth.Header.Set("Authorization", "Bearer tok")
	badMonthRec := httptest.NewRecorder()
	handler.ServeHTTP(badMonthRec, badMonth)
	if badMonthRec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("expected 422 on month 13, got %d", badMonthRec.Code)
	}

	missingCard := httptest.NewRequest(http.MethodPut, "/v1/wallet/99999999-9999-4999-8999-999999999999/renewal-month", strings.NewReader(`{"renewal_month":6}`))
	missingCard.Header.Set("Authorization", "Bearer tok")
	missingCardRec := httptest.NewRecorder()
	handler.ServeHTTP(missingCardRec, missingCard)
	if missingCardRec.Code != http.StatusNotFound {
		t.Fatalf("expected 404 on unknown wallet card, got %d", missingCardRec.Code)
	}

	// 7. GET /v1/bootstrap embeds reminders feed.
	bootReq := httptest.NewRequest(http.MethodGet, "/v1/bootstrap", nil)
	bootReq.Header.Set("Authorization", "Bearer tok")
	bootRec := httptest.NewRecorder()
	handler.ServeHTTP(bootRec, bootReq)
	if bootRec.Code != http.StatusOK {
		t.Fatalf("GET /v1/bootstrap status=%d body=%s", bootRec.Code, bootRec.Body.String())
	}
	var bootResp struct {
		Data struct {
			Reminders reminders.Feed `json:"reminders"`
		} `json:"data"`
	}
	if err := json.Unmarshal(bootRec.Body.Bytes(), &bootResp); err != nil {
		t.Fatal(err)
	}
	if len(bootResp.Data.Reminders.Reminders) == 0 {
		t.Fatal("bootstrap did not embed reminders feed")
	}
}
