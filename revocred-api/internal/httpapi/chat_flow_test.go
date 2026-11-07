package httpapi

import (
	"bufio"
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/revocred/revocred-api/internal/auth"
	"github.com/revocred/revocred-api/internal/chat"
)

const testUser = "11111111-1111-4111-8111-111111111111"

// progressSpy is an external provider that reports progress like the real one.
type progressSpy struct {
	consentSpy
	basic bool
	block chan struct{}
}

func (p *progressSpy) Reply(ctx context.Context, prompt string, grounded chat.Context) (chat.Reply, error) {
	p.calls++
	chat.ReportProgress(ctx, "searching", "Searching the web…")
	if p.block != nil {
		select {
		case <-p.block:
		case <-ctx.Done():
		}
	}
	return chat.Reply{Text: "External answer", Basic: p.basic}, nil
}

func chatFlowHandler(repo *fakeRepository, provider chat.Provider, limit int) http.Handler {
	return New(repo, &fakeAuthenticator{user: auth.User{ID: testUser}}, fakeRecommender{}, provider,
		slog.New(slog.NewTextHandler(io.Discard, nil)), nil, 5*time.Second, Options{ChatDailyAILimit: limit})
}

func chatRequest(method, path, body string) *http.Request {
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	req.Header.Set("Authorization", "Bearer test-token")
	return req
}

func TestStoredConsentEnablesAIAndRecordsMode(t *testing.T) {
	provider := &progressSpy{consentSpy: consentSpy{version: strings.Repeat("a", 64)}}
	repo := &fakeRepository{}
	handler := chatFlowHandler(repo, provider, 60)

	send := func() map[string]any {
		response := httptest.NewRecorder()
		handler.ServeHTTP(response, chatRequest(http.MethodPost, "/v1/chat/messages", `{"content":"Explain my plan"}`))
		if response.Code != http.StatusCreated {
			t.Fatalf("status=%d body=%s", response.Code, response.Body)
		}
		var payload struct{ Data []map[string]any }
		_ = json.Unmarshal(response.Body.Bytes(), &payload)
		return payload.Data[1]
	}
	if reply := send(); reply["mode"] != "basic" || provider.calls != 0 {
		t.Fatalf("no stored consent must answer basically: %v calls=%d", reply, provider.calls)
	}

	// Grant, read back, then chat without a per-message version.
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, chatRequest(http.MethodPut, "/v1/chat/consent", `{"version":"`+provider.version+`"}`))
	if response.Code != http.StatusOK || !strings.Contains(response.Body.String(), `"granted":true`) {
		t.Fatalf("grant failed: %d %s", response.Code, response.Body)
	}
	if reply := send(); reply["mode"] != "ai" || provider.calls != 1 {
		t.Fatalf("stored consent not used: %v calls=%d", reply, provider.calls)
	}

	// A provider-side fallback is still a basic answer.
	provider.basic = true
	if reply := send(); reply["mode"] != "basic" {
		t.Fatalf("fallback reply recorded as %v", reply["mode"])
	}
	provider.basic = false

	// A changed notice makes the stored permission stale: basic, not AI.
	provider.version = strings.Repeat("b", 64)
	calls := provider.calls
	if reply := send(); reply["mode"] != "basic" || provider.calls != calls {
		t.Fatal("stale stored consent reached the AI provider")
	}
	response = httptest.NewRecorder()
	handler.ServeHTTP(response, chatRequest(http.MethodGet, "/v1/chat/consent", ""))
	if !strings.Contains(response.Body.String(), `"granted":false`) {
		t.Fatalf("stale consent reported as granted: %s", response.Body)
	}

	// A mismatched grant is refused, and revoke clears the stored version.
	response = httptest.NewRecorder()
	handler.ServeHTTP(response, chatRequest(http.MethodPut, "/v1/chat/consent", `{"version":"`+strings.Repeat("a", 64)+`"}`))
	if response.Code != http.StatusConflict || !strings.Contains(response.Body.String(), "ai_consent_changed") {
		t.Fatalf("stale grant accepted: %d %s", response.Code, response.Body)
	}
	response = httptest.NewRecorder()
	handler.ServeHTTP(response, chatRequest(http.MethodDelete, "/v1/chat/consent", ""))
	if response.Code != http.StatusNoContent || repo.chatConsent != "" {
		t.Fatalf("revoke failed: %d consent=%q", response.Code, repo.chatConsent)
	}
}

func TestConsentUnavailableWithoutExternalAI(t *testing.T) {
	response := httptest.NewRecorder()
	chatFlowHandler(&fakeRepository{}, fakeChatProvider{}, 60).ServeHTTP(response,
		chatRequest(http.MethodPut, "/v1/chat/consent", `{"version":"`+strings.Repeat("a", 64)+`"}`))
	if response.Code != http.StatusServiceUnavailable {
		t.Fatalf("status=%d", response.Code)
	}
}

func TestDailyAILimit(t *testing.T) {
	provider := &progressSpy{consentSpy: consentSpy{version: strings.Repeat("a", 64)}}
	repo := &fakeRepository{chatConsent: provider.version, chatAICount: 3}
	handler := chatFlowHandler(repo, provider, 3)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, chatRequest(http.MethodPost, "/v1/chat/messages", `{"content":"Explain"}`))
	if response.Code != http.StatusTooManyRequests || !strings.Contains(response.Body.String(), "chat_daily_limit") || provider.calls != 0 {
		t.Fatalf("limit not enforced: %d %s", response.Code, response.Body)
	}
	// Basic answers are not capped.
	repo.chatConsent = ""
	response = httptest.NewRecorder()
	handler.ServeHTTP(response, chatRequest(http.MethodPost, "/v1/chat/messages", `{"content":"Explain"}`))
	if response.Code != http.StatusCreated {
		t.Fatalf("basic answer blocked by AI limit: %d", response.Code)
	}
}

func readEvents(t *testing.T, body io.Reader) []string {
	t.Helper()
	events := []string{}
	scanner := bufio.NewScanner(body)
	event := ""
	for scanner.Scan() {
		line := scanner.Text()
		switch {
		case strings.HasPrefix(line, "event: "):
			event = strings.TrimPrefix(line, "event: ")
		case strings.HasPrefix(line, "data: "):
			events = append(events, event+" "+strings.TrimPrefix(line, "data: "))
		}
	}
	return events
}

func TestChatStreamsProgressThenDone(t *testing.T) {
	provider := &progressSpy{consentSpy: consentSpy{version: strings.Repeat("a", 64)}}
	repo := &fakeRepository{chatConsent: provider.version}
	server := httptest.NewServer(chatFlowHandler(repo, provider, 60))
	defer server.Close()
	for _, path := range []string{"/v1/chat/messages", "/v1/public/explain"} {
		body := `{"content":"Explain"}`
		if path == "/v1/public/explain" {
			body = `{"content":"Explain","ai_consent_version":"` + provider.version + `"}`
		}
		req, _ := http.NewRequest(http.MethodPost, server.URL+path, strings.NewReader(body))
		req.Header.Set("Authorization", "Bearer test-token")
		req.Header.Set("Accept", "text/event-stream")
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		if !strings.HasPrefix(resp.Header.Get("Content-Type"), "text/event-stream") {
			t.Fatalf("%s content type %q", path, resp.Header.Get("Content-Type"))
		}
		events := readEvents(t, resp.Body)
		resp.Body.Close()
		if len(events) != 3 || !strings.HasPrefix(events[0], "status ") || !strings.Contains(events[1], "Searching the web") ||
			!strings.HasPrefix(events[2], "done ") || !strings.Contains(events[2], `"mode":"ai"`) {
			t.Fatalf("%s events: %q", path, events)
		}
	}
}

func TestChatStreamDisconnectSavesNothing(t *testing.T) {
	provider := &progressSpy{consentSpy: consentSpy{version: strings.Repeat("a", 64)}, block: make(chan struct{})}
	repo := &fakeRepository{chatConsent: provider.version}
	server := httptest.NewServer(chatFlowHandler(repo, provider, 60))
	defer server.Close()
	ctx, cancel := context.WithCancel(context.Background())
	req, _ := http.NewRequestWithContext(ctx, http.MethodPost, server.URL+"/v1/chat/messages", strings.NewReader(`{"content":"Explain"}`))
	req.Header.Set("Authorization", "Bearer test-token")
	req.Header.Set("Accept", "text/event-stream")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	reader := bufio.NewReader(resp.Body)
	if line, _ := reader.ReadString('\n'); !strings.HasPrefix(line, "event: status") {
		t.Fatalf("first line %q", line)
	}
	cancel()
	resp.Body.Close()
	// Close waits for the handler to finish, so the repository is settled.
	server.Close()
	if provider.calls != 1 || len(repo.savedModes) != 0 {
		t.Fatalf("cancelled exchange was saved: %v", repo.savedModes)
	}
}

func TestClearChatAndFeedback(t *testing.T) {
	repo := &fakeRepository{}
	handler := chatFlowHandler(repo, fakeChatProvider{}, 60)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, chatRequest(http.MethodDelete, "/v1/chat/messages", ""))
	if response.Code != http.StatusNoContent || !repo.chatCleared {
		t.Fatalf("clear failed: %d", response.Code)
	}
	for _, tc := range []struct {
		id, body string
		status   int
	}{
		{"a1", `{"rating":"down","reason":"Inaccurate"}`, http.StatusNoContent},
		{"someone-else", `{"rating":"up"}`, http.StatusNotFound},
		{"a1", `{"rating":"meh"}`, http.StatusUnprocessableEntity},
		{"a1", `{"rating":"down","reason":"` + strings.Repeat("x", 501) + `"}`, http.StatusUnprocessableEntity},
	} {
		response := httptest.NewRecorder()
		handler.ServeHTTP(response, chatRequest(http.MethodPost, "/v1/chat/messages/"+tc.id+"/feedback", tc.body))
		if response.Code != tc.status {
			t.Fatalf("%s %s: status %d", tc.id, tc.body, response.Code)
		}
	}
	if repo.feedback != "down:Inaccurate" {
		t.Fatalf("feedback stored as %q", repo.feedback)
	}
}
