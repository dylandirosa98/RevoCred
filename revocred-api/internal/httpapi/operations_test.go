package httpapi

import (
	"context"
	"errors"
	"github.com/revocred/revocred-api/internal/auth"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
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
