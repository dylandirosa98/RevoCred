package httpapi

import (
	"context"
	"errors"
	"github.com/revocred/revocred-api/internal/auth"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

type unavailableStore struct{ fakeRepository }

func (*unavailableStore) Ping(context.Context) error { return errors.New("database unavailable") }

func TestReadinessAndMetrics(t *testing.T) {
	h := New(&unavailableStore{}, &fakeAuthenticator{}, fakeRecommender{}, fakeChatProvider{}, slog.New(slog.NewTextHandler(io.Discard, nil)), nil, time.Second, Options{MetricsToken: "private-token"})
	for _, tc := range []struct {
		path, token string
		want        int
	}{{"/healthz", "", 200}, {"/readyz", "", 503}, {"/metrics", "", 404}, {"/metrics", "private-token", 200}} {
		r := httptest.NewRequest("GET", tc.path, nil)
		r.Header.Set("Authorization", "Bearer "+tc.token)
		w := httptest.NewRecorder()
		h.ServeHTTP(w, r)
		if w.Code != tc.want {
			t.Fatalf("%s status %d want %d", tc.path, w.Code, tc.want)
		}
	}
}

func TestUserRateLimit(t *testing.T) {
	h := testHandler(&fakeAuthenticator{user: auth.User{ID: "11111111-1111-4111-8111-111111111111"}})
	for i := 0; i < 121; i++ {
		r := httptest.NewRequest("GET", "/v1/cards", nil)
		r.Header.Set("Authorization", "Bearer valid")
		w := httptest.NewRecorder()
		h.ServeHTTP(w, r)
		if i == 120 && (w.Code != http.StatusTooManyRequests || w.Header().Get("Retry-After") == "") {
			t.Fatalf("not limited: %d", w.Code)
		}
	}
}

func TestClientIPTrustsOnlyConfiguredEdgeHeader(t *testing.T) {
	request := func(realIP string) *http.Request {
		r := httptest.NewRequest("GET", "/v1/public/cards", nil)
		r.RemoteAddr = "10.0.0.1:4000"
		if realIP != "" {
			r.Header.Set("X-Real-IP", realIP)
		}
		return r
	}
	direct := &API{}
	if got := direct.clientIP(request("203.0.113.9")); got != "10.0.0.1" {
		t.Fatalf("unconfigured header was trusted: %s", got)
	}
	edge := &API{clientIPHeader: "X-Real-IP"}
	for realIP, want := range map[string]string{"203.0.113.9": "203.0.113.9", " 2001:db8::1 ": "2001:db8::1", "": "10.0.0.1", "not-an-ip": "10.0.0.1"} {
		if got := edge.clientIP(request(realIP)); got != want {
			t.Fatalf("X-Real-IP %q: got %s want %s", realIP, got, want)
		}
	}
}

func TestEdgeClientsHaveSeparateLimits(t *testing.T) {
	h := New(&fakeRepository{}, &fakeAuthenticator{}, fakeRecommender{}, fakeChatProvider{}, slog.New(slog.NewTextHandler(io.Discard, nil)), nil, time.Second, Options{ClientIPHeader: "X-Real-IP"})
	explain := func(ip string) int {
		r := httptest.NewRequest("POST", "/v1/public/explain", strings.NewReader(`{}`))
		r.RemoteAddr = "10.0.0.1:4000"
		r.Header.Set("X-Real-IP", ip)
		w := httptest.NewRecorder()
		h.ServeHTTP(w, r)
		return w.Code
	}
	for i := 0; i < 20; i++ {
		explain("203.0.113.1")
	}
	if code := explain("203.0.113.1"); code != http.StatusTooManyRequests {
		t.Fatalf("first client not limited: %d", code)
	}
	if code := explain("203.0.113.2"); code == http.StatusTooManyRequests {
		t.Fatal("second client shared the first client's limit")
	}
}

func TestDeleteRequiresRecentSignIn(t *testing.T) {
	h := testHandler(&fakeAuthenticator{user: auth.User{ID: "11111111-1111-4111-8111-111111111111"}})
	r := httptest.NewRequest("DELETE", "/v1/account", nil)
	r.Header.Set("Authorization", "Bearer valid")
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	if w.Code != 403 {
		t.Fatalf("status %d", w.Code)
	}
}
