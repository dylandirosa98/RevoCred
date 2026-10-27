package httpapi

import (
	"context"
	"crypto/subtle"
	"fmt"
	"net"
	"net/http"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

type Options struct {
	MetricsToken string
	// ClientIPHeader names a header set by a trusted edge proxy (for example
	// Railway's X-Real-IP). Leave empty when clients can reach the API directly.
	ClientIPHeader string
}

type window struct {
	until time.Time
	count int
}
type limiter struct {
	mu      sync.Mutex
	entries map[string]window
}

func (l *limiter) allow(key string, limit int, now time.Time) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.entries == nil {
		l.entries = map[string]window{}
	}
	current, exists := l.entries[key]
	if !exists && len(l.entries) >= 10000 {
		for k, v := range l.entries {
			if !now.Before(v.until) {
				delete(l.entries, k)
			}
		}
		if len(l.entries) >= 10000 {
			return false
		}
	}
	if !now.Before(current.until) {
		current = window{until: now.Add(time.Minute)}
	}
	if current.count >= limit {
		return false
	}
	current.count++
	l.entries[key] = current
	return true
}

type counters struct{ requests, failures, limited, clientErrors atomic.Uint64 }

func (a *API) rateLimit(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.HasPrefix(r.URL.Path, "/v1/") {
			if !a.limits.allow("ip:"+a.clientIP(r), 600, time.Now()) {
				a.tooMany(w, r)
				return
			}
		}
		next.ServeHTTP(w, r)
	})
}

// clientIP keys per-client limits. Forwarded headers are untrusted unless a
// trusted edge header is configured; without one, traffic behind a proxy
// shares the proxy's limit.
func (a *API) clientIP(r *http.Request) string {
	if a.clientIPHeader != "" {
		if ip := net.ParseIP(strings.TrimSpace(r.Header.Get(a.clientIPHeader))); ip != nil {
			return ip.String()
		}
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}

func (a *API) tooMany(w http.ResponseWriter, r *http.Request) {
	a.stats.limited.Add(1)
	w.Header().Set("Retry-After", "60")
	writeError(w, r, http.StatusTooManyRequests, "rate_limited", "Too many requests. Please wait a minute.", nil)
}

func (a *API) ready(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()
	if err := a.repository.Ping(ctx); err != nil {
		writeError(w, r, http.StatusServiceUnavailable, "not_ready", "Database or schema is not ready.", nil)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ready"})
}

func (a *API) metrics(w http.ResponseWriter, r *http.Request) {
	token := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
	if a.metricsToken == "" || subtle.ConstantTimeCompare([]byte(token), []byte(a.metricsToken)) != 1 {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("Content-Type", "text/plain; version=0.0.4")
	fmt.Fprintf(w, "# TYPE revocred_requests_total counter\nrevocred_requests_total %d\n# TYPE revocred_errors_total counter\nrevocred_errors_total %d\n# TYPE revocred_rate_limited_total counter\nrevocred_rate_limited_total %d\n", a.stats.requests.Load(), a.stats.failures.Load(), a.stats.limited.Load())
	fmt.Fprintf(w, "# TYPE revocred_client_errors_total counter\nrevocred_client_errors_total %d\n", a.stats.clientErrors.Load())
}

// Client reports intentionally exclude user-entered text, URLs, and stack traces.
func (a *API) clientError(w http.ResponseWriter, r *http.Request) {
	var input struct {
		Kind string `json:"kind"`
	}
	if !a.decodeJSON(w, r, &input) {
		return
	}
	if input.Kind != "flutter" && input.Kind != "platform" {
		writeError(w, r, 422, "validation_error", "Unknown error kind.", nil)
		return
	}
	a.stats.clientErrors.Add(1)
	a.logger.ErrorContext(r.Context(), "client error", "kind", input.Kind, "request_id", requestIDFromContext(r.Context()))
	w.WriteHeader(http.StatusNoContent)
}
