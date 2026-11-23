package httpapi

import (
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/revocred/revocred-api/internal/auth"
	"github.com/revocred/revocred-api/internal/moderation"
)

type spyModerationNotifier struct {
	mu     sync.Mutex
	alerts []moderation.Alert
}

func (s *spyModerationNotifier) NotifyReport(alert moderation.Alert) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.alerts = append(s.alerts, alert)
}

func (s *spyModerationNotifier) snapshot() []moderation.Alert {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := make([]moderation.Alert, len(s.alerts))
	copy(out, s.alerts)
	return out
}

func TestChatFeedbackModerationAlertHook(t *testing.T) {
	repo := &fakeRepository{}
	notifier := &spyModerationNotifier{}
	handler := New(
		repo,
		&fakeAuthenticator{user: auth.User{ID: "11111111-1111-4111-8111-111111111111", Email: "member@example.test"}},
		fakeRecommender{},
		fakeChatProvider{},
		slog.New(slog.NewTextHandler(io.Discard, nil)),
		nil,
		time.Second,
		Options{ModerationNotifier: notifier},
	)

	send := func(id, body string) int {
		t.Helper()
		req := chatRequest(http.MethodPost, "/v1/chat/messages/"+id+"/feedback", body)
		rec := httptest.NewRecorder()
		handler.ServeHTTP(rec, req)
		return rec.Code
	}

	// Non-safety feedback, thumbs up, 404, and 422 must not trigger alerts.
	if code := send("a1", `{"rating":"up","reason":"Harmful or offensive"}`); code != http.StatusNoContent {
		t.Fatalf("thumbs up status = %d", code)
	}
	if code := send("a1", `{"rating":"down","reason":"Inaccurate: wrong multiplier"}`); code != http.StatusNoContent {
		t.Fatalf("inaccurate status = %d", code)
	}
	if code := send("missing-id", `{"rating":"down","reason":"Harmful or offensive"}`); code != http.StatusNotFound {
		t.Fatalf("missing message status = %d", code)
	}
	if code := send("a1", `{"rating":"bad","reason":"Harmful or offensive"}`); code != http.StatusUnprocessableEntity {
		t.Fatalf("invalid rating status = %d", code)
	}
	if got := notifier.snapshot(); len(got) != 0 {
		t.Fatalf("unexpected alerts fired for non-safety/rejected feedback: %+v", got)
	}

	// Safety report fires privacy-minimized alert with normalized reason (no raw text/email).
	if code := send("a1", `{"rating":"down","reason":"Harmful or offensive: my email is member@example.test"}`); code != http.StatusNoContent {
		t.Fatalf("harmful report status = %d", code)
	}
	if code := send("a1", `{"rating":"down","reason":"Offensive response"}`); code != http.StatusNoContent {
		t.Fatalf("offensive report status = %d", code)
	}

	alerts := notifier.snapshot()
	if len(alerts) != 2 {
		t.Fatalf("alerts count = %d, want 2: %+v", len(alerts), alerts)
	}
	if alerts[0].Event != moderation.AlertEventName || alerts[0].ReportID != "a1" || alerts[0].Reason != "harmful_or_offensive" || alerts[0].SubmittedAt.IsZero() {
		t.Fatalf("unexpected first alert: %+v", alerts[0])
	}
	if strings.Contains(alerts[0].Reason, "member@example.test") {
		t.Fatalf("raw PII leaked into alert reason: %+v", alerts[0])
	}
	if alerts[1].Reason != "offensive" || alerts[1].ReportID != "a1" {
		t.Fatalf("unexpected second alert: %+v", alerts[1])
	}
}
