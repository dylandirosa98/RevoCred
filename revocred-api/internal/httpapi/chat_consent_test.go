package httpapi

import (
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

type consentSpy struct {
	calls   int
	version string
}

func (*consentSpy) Mode() string { return "openai" }
func (p *consentSpy) SharingDisclosure() (chat.SharingDisclosure, error) {
	return chat.SharingDisclosure{
		External: true, Version: p.version, Recipient: "OpenAI", Model: "test-model", DataUse: "Test disclosure",
	}, nil
}
func (p *consentSpy) Reply(context.Context, string, chat.Context) (chat.Reply, error) {
	p.calls++
	return chat.Reply{Text: "External answer"}, nil
}

func consentHandler(provider chat.Provider) http.Handler {
	return New(&fakeRepository{},
		&fakeAuthenticator{user: auth.User{ID: "11111111-1111-4111-8111-111111111111"}},
		fakeRecommender{}, provider, slog.New(slog.NewTextHandler(io.Discard, nil)), nil, time.Second)
}

func TestChatRequiresCurrentPermissionForEachExternalRequest(t *testing.T) {
	for _, path := range []string{"/v1/public/explain", "/v1/chat/messages"} {
		t.Run(path, func(t *testing.T) {
			provider := &consentSpy{version: strings.Repeat("a", 64)}
			handler := consentHandler(provider)
			for _, tc := range []struct {
				name, consent string
				status, calls int
			}{
				{"no permission", "", http.StatusCreated, 0},
				{"stale permission", "old-version", http.StatusConflict, 0},
				{"explicit permission", provider.version, http.StatusCreated, 1},
				{"no carried permission", "", http.StatusCreated, 1},
			} {
				t.Run(tc.name, func(t *testing.T) {
					payload := map[string]string{"content": "Explain my plan"}
					if tc.consent != "" {
						payload["ai_consent_version"] = tc.consent
					}
					body, _ := json.Marshal(payload)
					req := httptest.NewRequest(http.MethodPost, path, strings.NewReader(string(body)))
					req.Header.Set("Authorization", "Bearer test-token")
					response := httptest.NewRecorder()
					handler.ServeHTTP(response, req)
					if response.Code != tc.status || provider.calls != tc.calls {
						t.Fatalf("status=%d calls=%d, want %d/%d; body=%s", response.Code, provider.calls, tc.status, tc.calls, response.Body.String())
					}
				})
			}
			// A deployment/model change between disclosure and send is fail-closed.
			previous := provider.version
			provider.version = strings.Repeat("b", 64)
			body := `{"content":"Explain","ai_consent_version":"` + previous + `"}`
			req := httptest.NewRequest(http.MethodPost, path, strings.NewReader(body))
			req.Header.Set("Authorization", "Bearer test-token")
			response := httptest.NewRecorder()
			handler.ServeHTTP(response, req)
			if response.Code != http.StatusConflict || provider.calls != 1 {
				t.Fatal("provider change reused old permission")
			}
		})
	}
}

func TestDisclosureIsPublicUncachedAndDoesNotInvokeProvider(t *testing.T) {
	provider := &consentSpy{version: strings.Repeat("a", 64)}
	response := httptest.NewRecorder()
	consentHandler(provider).ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/v1/public/chat-disclosure", nil))
	if response.Code != http.StatusOK || provider.calls != 0 || response.Header().Get("Cache-Control") != "no-store" {
		t.Fatalf("status=%d calls=%d body=%s", response.Code, provider.calls, response.Body.String())
	}
	if !strings.Contains(response.Body.String(), `"recipient":"OpenAI"`) || !strings.Contains(response.Body.String(), provider.version) {
		t.Fatal("disclosure missing actual recipient/version")
	}
}

func TestBasicModeNeedsNoAIConsent(t *testing.T) {
	response := httptest.NewRecorder()
	consentHandler(chat.NewDeterministicProvider()).ServeHTTP(response,
		httptest.NewRequest(http.MethodGet, "/v1/public/chat-disclosure", nil))
	if response.Code != http.StatusOK || !strings.Contains(response.Body.String(), `"external":false`) {
		t.Fatalf("unexpected basic disclosure: %s", response.Body.String())
	}
}
