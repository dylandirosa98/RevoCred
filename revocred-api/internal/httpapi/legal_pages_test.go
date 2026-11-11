package httpapi

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/revocred/revocred-api/internal/auth"
)

func TestLegalPagesArePublicHTML(t *testing.T) {
	// Every token is rejected, and an invalid one is sent: the pages need none.
	handler := testHandler(&fakeAuthenticator{err: auth.ErrUnauthorized})
	cases := map[string]string{
		"/privacy": "RevoCred Privacy Policy",
		"/terms":   "RevoCred Terms of Use",
		"/support": "RevoCred Support",
		"/legal":   "RevoCred policies and support",
	}
	for path, title := range cases {
		t.Run(path, func(t *testing.T) {
			request := httptest.NewRequest(http.MethodGet, path, nil)
			request.Header.Set("Authorization", "Bearer invalid")
			response := httptest.NewRecorder()
			handler.ServeHTTP(response, request)
			if response.Code != http.StatusOK {
				t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
			}
			headers := response.Header()
			for name, want := range map[string]string{
				"Content-Type":           "text/html; charset=utf-8",
				"Cache-Control":          "public, max-age=300",
				"X-Content-Type-Options": "nosniff",
				"X-Frame-Options":        "DENY",
			} {
				if got := headers.Get(name); got != want {
					t.Errorf("%s = %q, want %q", name, got, want)
				}
			}
			if csp := headers.Get("Content-Security-Policy"); !strings.HasPrefix(csp, "default-src 'none'; style-src 'sha256-") {
				t.Errorf("Content-Security-Policy = %q", csp)
			}
			if headers.Get("ETag") == "" || headers.Get("X-Request-ID") == "" {
				t.Errorf("missing ETag or request ID: %#v", headers)
			}
			body := response.Body.String()
			for _, want := range []string{"<title>" + title + "</title>", `<html lang="en">`, `name="viewport"`, `<main id="main">`, "mailto:support@revocred.com"} {
				if !strings.Contains(body, want) {
					t.Fatalf("page %s is missing %q:\n%s", path, want, body)
				}
			}
			if path != "/legal" && !strings.Contains(body, `href="`+path+`" aria-current="page"`) {
				t.Fatalf("page %s does not mark its navigation link as current", path)
			}
			if strings.Contains(body, "<script") || strings.Contains(body, "http://") || strings.Contains(body, "<link") {
				t.Fatalf("page must load no scripts or external assets:\n%s", body)
			}

			revalidate := httptest.NewRequest(http.MethodGet, path, nil)
			revalidate.Header.Set("If-None-Match", headers.Get("ETag"))
			cached := httptest.NewRecorder()
			handler.ServeHTTP(cached, revalidate)
			if cached.Code != http.StatusNotModified {
				t.Fatalf("revalidation status = %d", cached.Code)
			}

			head := httptest.NewRecorder()
			handler.ServeHTTP(head, httptest.NewRequest(http.MethodHead, path, nil))
			if head.Code != http.StatusOK || head.Body.Len() != 0 {
				t.Fatalf("HEAD status = %d, body length = %d", head.Code, head.Body.Len())
			}
		})
	}
}

func TestLegalPagesIgnoreCORSOrigins(t *testing.T) {
	handler := testHandler(&fakeAuthenticator{})
	for _, origin := range []string{"https://evil.example.test", "https://app.example.test", "null"} {
		request := httptest.NewRequest(http.MethodGet, "/privacy", nil)
		request.Header.Set("Origin", origin)
		response := httptest.NewRecorder()
		handler.ServeHTTP(response, request)
		if response.Code != http.StatusOK {
			t.Fatalf("origin %s: status = %d", origin, response.Code)
		}
		if got := response.Header().Get("Access-Control-Allow-Origin"); got != "" {
			t.Fatalf("origin %s: legal pages must not grant CORS access, got %q", origin, got)
		}
	}
	// Other routes keep enforcing the origin allowlist.
	request := httptest.NewRequest(http.MethodGet, "/v1/public/cards", nil)
	request.Header.Set("Origin", "https://evil.example.test")
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	if response.Code != http.StatusForbidden {
		t.Fatalf("API route with a blocked origin: status = %d", response.Code)
	}
}

func TestLegalPageAliasesAndMethods(t *testing.T) {
	handler := testHandler(&fakeAuthenticator{})
	for from, to := range map[string]string{"/privacy-policy": "/privacy", "/privacy/": "/privacy", "/terms/": "/terms", "/support/": "/support"} {
		response := httptest.NewRecorder()
		handler.ServeHTTP(response, httptest.NewRequest(http.MethodGet, from, nil))
		if response.Code != http.StatusPermanentRedirect || response.Header().Get("Location") != to {
			t.Fatalf("%s: status = %d, location = %q", from, response.Code, response.Header().Get("Location"))
		}
	}
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, httptest.NewRequest(http.MethodPost, "/privacy", strings.NewReader("x")))
	if response.Code != http.StatusMethodNotAllowed {
		t.Fatalf("POST /privacy status = %d", response.Code)
	}
	response = httptest.NewRecorder()
	handler.ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/privacy/extra", nil))
	// Unknown paths fall through to the API's usual non-page response.
	if response.Code == http.StatusOK {
		t.Fatalf("GET /privacy/extra served a page")
	}
}
