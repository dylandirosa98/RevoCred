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
	// basic makes the provider fall back to a basic answer, as when the AI
	// service fails.
	basic bool
}

func (*consentSpy) Mode() string { return "openai" }
func (p *consentSpy) SharingDisclosure() (chat.SharingDisclosure, error) {
	return chat.SharingDisclosure{
		External: true, Version: p.version, Recipient: "OpenAI", Model: "test-model", DataUse: "Test disclosure",
	}, nil
}
func (p *consentSpy) Reply(context.Context, string, chat.Context) (chat.Reply, error) {
	p.calls++
	return chat.Reply{Text: "External answer", Basic: p.basic}, nil
}

func consentHandler(provider chat.Provider) http.Handler {
	return New(&fakeRepository{},
		&fakeAuthenticator{user: auth.User{ID: "11111111-1111-4111-8111-111111111111"}},
		fakeRecommender{}, provider, slog.New(slog.NewTextHandler(io.Discard, nil)), nil, time.Second)
}

func TestBasicChatResponsesDoNotExposeModelInstructions(t *testing.T) {
	for _, path := range []string{"/v1/public/explain", "/v1/chat/messages"} {
		for _, accept := range []string{"application/json", "text/event-stream"} {
			t.Run(path+"/"+accept, func(t *testing.T) {
				provider := &consentSpy{version: strings.Repeat("a", 64)}
				req := httptest.NewRequest(http.MethodPost, path, strings.NewReader(`{"content":"Explain what this app does."}`))
				req.Header.Set("Authorization", "Bearer test-token")
				req.Header.Set("Accept", accept)
				response := httptest.NewRecorder()
				consentHandler(provider).ServeHTTP(response, req)
				wantStatus := http.StatusCreated
				if accept == "text/event-stream" {
					wantStatus = http.StatusOK
				}
				body := response.Body.String()
				if response.Code != wantStatus || provider.calls != 0 {
					t.Fatalf("status=%d external calls=%d body=%s", response.Code, provider.calls, body)
				}
				if !strings.Contains(body, `"mode":"basic"`) || !strings.Contains(body, "issuer terms") {
					t.Fatalf("missing readable basic answer: %s", body)
				}
				for _, instruction := range []string{"Use the supplied breakdown", "Never convert AI", "budget does not prove merchant use"} {
					if strings.Contains(body, instruction) {
						t.Errorf("model instruction %q reached the HTTP response", instruction)
					}
				}
			})
		}
	}
}

func TestGuestsAlwaysGetBasicAnswers(t *testing.T) {
	provider := &consentSpy{version: strings.Repeat("a", 64)}
	handler := consentHandler(provider)
	for _, consent := range []string{"", "old-version", provider.version} {
		body, _ := json.Marshal(map[string]string{"content": "Explain my plan", "ai_consent_version": consent})
		response := httptest.NewRecorder()
		handler.ServeHTTP(response, httptest.NewRequest(http.MethodPost, "/v1/public/explain", strings.NewReader(string(body))))
		if response.Code != http.StatusCreated || provider.calls != 0 || !strings.Contains(response.Body.String(), `"mode":"basic"`) {
			t.Fatalf("consent %q: guest reached the AI: status=%d calls=%d", consent, response.Code, provider.calls)
		}
	}
}

func TestChatRequiresCurrentPermissionForEachExternalRequest(t *testing.T) {
	for _, path := range []string{"/v1/chat/messages"} {
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
