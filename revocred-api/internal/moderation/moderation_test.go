package moderation

import (
	"bytes"
	"encoding/json"
	"io"
	"log/slog"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

func TestListFilterNormalize(t *testing.T) {
	got, err := (ListFilter{}).Normalize()
	if err != nil {
		t.Fatal(err)
	}
	if got.Status != StatusOpen || got.Rating != "down" || got.Limit != DefaultListLimit {
		t.Fatalf("unexpected defaults: %+v", got)
	}

	since := time.Date(2026, 11, 20, 5, 0, 0, 0, time.FixedZone("EST", -5*3600))
	got, err = (ListFilter{Status: "ALL", Rating: "ALL", Reason: " Harmful ", Since: &since, Limit: 25}).Normalize()
	if err != nil {
		t.Fatal(err)
	}
	if got.Status != "all" || got.Rating != "all" || got.Reason != "Harmful" || got.Limit != 25 || got.Since.Location() != time.UTC {
		t.Fatalf("unexpected normalized filter: %+v", got)
	}

	for name, filter := range map[string]ListFilter{
		"bad status": {Status: "closed"},
		"bad rating": {Rating: "meh"},
		"bad limit":  {Limit: MaxListLimit + 1},
		"neg limit":  {Limit: -1},
		"long text":  {Reason: strings.Repeat("a", 201)},
	} {
		if _, err := filter.Normalize(); err == nil {
			t.Fatalf("%s unexpectedly accepted", name)
		}
	}
}

func TestResolutionNormalize(t *testing.T) {
	validID := "11111111-1111-4111-8111-111111111111"
	got, err := (Resolution{
		MessageID:  " " + validID + " ",
		Status:     "ACTIONED",
		ReviewedBy: "  ops-alice  ",
		Note:       "  tightened guardrail prompt  ",
	}).Normalize()
	if err != nil {
		t.Fatal(err)
	}
	if got.MessageID != validID || got.Status != StatusActioned || got.ReviewedBy != "ops-alice" || got.Note != "tightened guardrail prompt" {
		t.Fatalf("unexpected normalized resolution: %+v", got)
	}

	for name, res := range map[string]Resolution{
		"bad uuid":     {MessageID: "not-a-uuid", Status: StatusReviewed, ReviewedBy: "ops"},
		"open status":  {MessageID: validID, Status: StatusOpen, ReviewedBy: "ops"},
		"bad status":   {MessageID: validID, Status: "deleted", ReviewedBy: "ops"},
		"empty by":     {MessageID: validID, Status: StatusReviewed, ReviewedBy: "   "},
		"multiline by": {MessageID: validID, Status: StatusReviewed, ReviewedBy: "ops\nadmin"},
		"long by":      {MessageID: validID, Status: StatusReviewed, ReviewedBy: strings.Repeat("a", MaxReviewedBy+1)},
		"long note":    {MessageID: validID, Status: StatusDismissed, ReviewedBy: "ops", Note: strings.Repeat("x", MaxNoteLength+1)},
	} {
		if _, err := res.Normalize(); err == nil {
			t.Fatalf("%s unexpectedly accepted", name)
		}
	}
}

func TestRedactSensitiveAndSnippet(t *testing.T) {
	raw := "Contact alice.smith@example.com or use Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3OCJ9.signature12345 " +
		"with postgresql://admin:supersecret@db.example.com:5432/app and sk-live-1234567890abcdef " +
		"card 4111-2222-3333-4444 SSN 123-45-6789 spend $1,200 on 2026-11-23"
	got := RedactSensitive(raw)
	for _, forbidden := range []string{
		"alice.smith@example.com",
		"eyJhbGciOiJIUzI1NiJ9",
		"supersecret",
		"sk-live-1234567890abcdef",
		"4111-2222-3333-4444",
		"123-45-6789",
	} {
		if strings.Contains(got, forbidden) {
			t.Fatalf("redaction leaked %q in %q", forbidden, got)
		}
	}
	for _, preserved := range []string{"$1,200", "2026-11-23"} {
		if !strings.Contains(got, preserved) {
			t.Fatalf("redaction stripped benign text %q from %q", preserved, got)
		}
	}

	snippet := Snippet("  Line one\n\tline two\r\n   alice@example.com  ", 24)
	if strings.Contains(snippet, "alice@example.com") || strings.ContainsAny(snippet, "\n\r\t") || !strings.HasSuffix(snippet, "...") {
		t.Fatalf("unexpected snippet: %q", snippet)
	}
	if len([]rune(snippet)) > 24 {
		t.Fatalf("snippet exceeded max length: %q", snippet)
	}
}

func TestAlertReasonCategory(t *testing.T) {
	cases := []struct {
		rating, reason, want string
	}{
		{"down", "Harmful or offensive", "harmful_or_offensive"},
		{"down", "Harmful or offensive: my email is user@example.com", "harmful_or_offensive"},
		{"down", "Harmful advice", "harmful"},
		{"down", "OFFENSIVE language", "offensive"},
		{"down", "Inaccurate", ""},
		{"down", "Not helpful", ""},
		{"down", "", ""},
		{"up", "Harmful or offensive", ""},
	}
	for _, tc := range cases {
		if got := AlertReasonCategory(tc.rating, tc.reason); got != tc.want {
			t.Fatalf("AlertReasonCategory(%q, %q) = %q, want %q", tc.rating, tc.reason, got, tc.want)
		}
	}
}

func TestValidWebhookURL(t *testing.T) {
	for _, valid := range []string{
		"https://hooks.slack.com/services/T000/B000/secret",
		"https://alerts.revocred.example:443/v1/moderation",
	} {
		if err := ValidWebhookURL(valid); err != nil {
			t.Fatalf("expected valid webhook URL %q, got %v", valid, err)
		}
	}
	for _, invalid := range []string{
		"",
		"http://hooks.slack.com/services/abc",
		"https://user:pass@hooks.slack.com/services/abc",
		"https://hooks.slack.com/services/abc#frag",
		"https://hooks.slack.com:8443/services/abc",
		"https://127.0.0.1/hook",
		"https://169.254.169.254/latest/meta-data",
		"https://[::1]/hook",
		"https://localhost/hook",
		"https://api.localhost/hook",
		"https://internal.local/hook",
		"https://webhook.railway.internal/hook",
		"https://hooks.slack.com/services/abc\nX-Injected: 1",
	} {
		if err := ValidWebhookURL(invalid); err == nil {
			t.Fatalf("accepted unsafe webhook URL %q", invalid)
		}
	}
}

func TestIsPublicIP(t *testing.T) {
	for _, blocked := range []string{"127.0.0.1", "10.0.0.1", "172.16.0.1", "192.168.1.1", "169.254.169.254", "100.64.0.1", "::1", "fc00::1"} {
		if isPublicIP(net.ParseIP(blocked)) {
			t.Fatalf("expected %s to be non-public", blocked)
		}
	}
	if !isPublicIP(net.ParseIP("93.184.216.34")) {
		t.Fatal("expected public IPv4 to be allowed")
	}
}

func TestWebhookNotifierDeliveryAndLogHygiene(t *testing.T) {
	var received atomic.Int32
	var payload Alert
	secretPath := "/hooks/super-secret-token-xyz"
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost || r.URL.Path != secretPath {
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		defer r.Body.Close()
		raw, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(raw, &payload)
		received.Add(1)
		w.WriteHeader(http.StatusAccepted)
	}))
	defer server.Close()

	var logs bytes.Buffer
	logger := slog.New(slog.NewJSONHandler(&logs, nil))
	notifier, err := newWebhookNotifier(server.URL+secretPath, server.Client(), 2*time.Second, 2, logger)
	if err != nil {
		t.Fatal(err)
	}
	when := time.Date(2026, 11, 23, 7, 30, 0, 0, time.UTC)
	notifier.NotifyReport(Alert{
		ReportID:    "11111111-1111-4111-8111-111111111111",
		Reason:      "harmful_or_offensive",
		SubmittedAt: when,
	})
	notifier.Wait()

	if received.Load() != 1 {
		t.Fatalf("received = %d, want 1", received.Load())
	}
	if payload.Event != AlertEventName || payload.ReportID != "11111111-1111-4111-8111-111111111111" || payload.Reason != "harmful_or_offensive" || !payload.SubmittedAt.Equal(when) {
		t.Fatalf("unexpected payload: %+v", payload)
	}

	// Failure path must log a warning without leaking the secret webhook path.
	failing := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer failing.Close()
	failNotifier, err := newWebhookNotifier(failing.URL+secretPath, failing.Client(), 2*time.Second, 2, logger)
	if err != nil {
		t.Fatal(err)
	}
	failNotifier.NotifyReport(Alert{ReportID: "22222222-2222-4222-8222-222222222222", Reason: "harmful"})
	failNotifier.Wait()
	if !strings.Contains(logs.String(), "non-2xx") {
		t.Fatalf("expected warning log on 500, got %q", logs.String())
	}
	if strings.Contains(logs.String(), "super-secret-token-xyz") {
		t.Fatalf("webhook secret token leaked into logs: %q", logs.String())
	}
}
