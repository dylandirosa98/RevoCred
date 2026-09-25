package httpapi

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/revocred/revocred-api/internal/store"
)

type offerRepository struct {
	fakeRepository
	destination string
	err         error
	clicks      int
}

func (f *offerRepository) RecordOfferClick(context.Context, string, string) (string, error) {
	f.clicks++
	return f.destination, f.err
}

func TestOfferNavigation(t *testing.T) {
	const link = "/v1/offers/11111111-1111-4111-8111-111111111111/apply?placement=strategy"
	for _, test := range []struct {
		name, path, method, destination, purpose string
		err                                      error
		status, calls                            int
	}{
		{name: "redirect", path: link, destination: "https://partner.example/apply?publisher=123", status: 302, calls: 1},
		{name: "expired", path: link, err: store.ErrNotFound, status: 404, calls: 1},
		{name: "storage failure", path: link, err: errors.New("offline"), status: 500, calls: 1},
		{name: "invalid destination", path: link, destination: "javascript:alert(1)", status: 404, calls: 1},
		{name: "open redirect", path: link + "&url=https://evil.example", status: 400},
		{name: "invalid placement", path: link + "x", status: 400},
		{name: "duplicate placement", path: link + "&placement=report", status: 400},
		{name: "head", path: link, method: "HEAD", status: 405},
		{name: "prefetch", path: link, purpose: "prefetch", status: 204},
		{name: "prerender", path: link, purpose: "prefetch;prerender", status: 204},
	} {
		t.Run(test.name, func(t *testing.T) {
			repo := &offerRepository{destination: test.destination, err: test.err}
			h := New(repo, &fakeAuthenticator{}, fakeRecommender{}, fakeChatProvider{}, slog.New(slog.NewTextHandler(io.Discard, nil)), nil, time.Second)
			method := test.method
			if method == "" {
				method = "GET"
			}
			r := httptest.NewRequest(method, test.path, nil)
			r.Header.Set("Purpose", test.purpose)
			if test.name == "prerender" {
				r.Header.Del("Purpose")
				r.Header.Set("Sec-Purpose", test.purpose)
			}
			w := httptest.NewRecorder()
			h.ServeHTTP(w, r)
			if w.Code != test.status || repo.clicks != test.calls {
				t.Fatalf("status %d calls %d: %s", w.Code, repo.clicks, w.Body.String())
			}
			if w.Header().Get("Referrer-Policy") != "no-referrer" || w.Header().Get("Cache-Control") != "no-store" {
				t.Fatal("missing privacy/cache headers")
			}
			if w.Code == http.StatusFound && w.Header().Get("Location") != test.destination {
				t.Fatal("lost publisher query parameters")
			}
			if w.Code != http.StatusFound && w.Header().Get("Location") != "" {
				t.Fatal("unexpected redirect")
			}
		})
	}
}
