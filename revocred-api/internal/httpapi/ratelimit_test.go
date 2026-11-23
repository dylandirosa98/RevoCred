package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

func TestMemoryRateLimiterWindowAndExpiry(t *testing.T) {
	limiter := NewMemoryRateLimiter()
	now := time.Date(2026, 11, 23, 12, 0, 0, 0, time.UTC)

	if allowed, err := limiter.Allow(context.Background(), "ip:1.2.3.4", 0, now); err != nil || allowed {
		t.Fatalf("zero limit allowed=%v err=%v", allowed, err)
	}
	for i := 0; i < 3; i++ {
		if allowed, err := limiter.Allow(context.Background(), "ip:1.2.3.4", 3, now); err != nil || !allowed {
			t.Fatalf("request %d denied: allowed=%v err=%v", i+1, allowed, err)
		}
	}
	if allowed, err := limiter.Allow(context.Background(), "ip:1.2.3.4", 3, now.Add(30*time.Second)); err != nil || allowed {
		t.Fatalf("request above limit allowed: allowed=%v err=%v", allowed, err)
	}
	if allowed, err := limiter.Allow(context.Background(), "ip:1.2.3.4", 3, now.Add(time.Minute)); err != nil || !allowed {
		t.Fatalf("request after window reset denied: allowed=%v err=%v", allowed, err)
	}
}

func TestMemoryRateLimiterBoundedEviction(t *testing.T) {
	limiter := &MemoryRateLimiter{entries: map[string]window{}, window: time.Minute, maxKeys: 2}
	now := time.Date(2026, 11, 23, 12, 0, 0, 0, time.UTC)

	for _, key := range []string{"ip:1", "ip:2"} {
		if allowed, err := limiter.Allow(context.Background(), key, 5, now); err != nil || !allowed {
			t.Fatalf("key %s denied: %v %v", key, allowed, err)
		}
	}
	if allowed, err := limiter.Allow(context.Background(), "ip:3", 5, now.Add(10*time.Second)); err != nil || allowed {
		t.Fatalf("expected cap rejection while entries active: allowed=%v err=%v", allowed, err)
	}
	if allowed, err := limiter.Allow(context.Background(), "ip:3", 5, now.Add(time.Minute)); err != nil || !allowed {
		t.Fatalf("expected expired entries to be evicted: allowed=%v err=%v", allowed, err)
	}
}

func TestMemoryRateLimiterConcurrent(t *testing.T) {
	limiter := NewMemoryRateLimiter()
	now := time.Now().UTC()
	const workers = 32
	const limit = 10

	var allowed atomic.Int32
	var wg sync.WaitGroup
	wg.Add(workers)
	for i := 0; i < workers; i++ {
		go func() {
			defer wg.Done()
			ok, err := limiter.Allow(context.Background(), "ip:concurrent", limit, now)
			if err != nil {
				t.Errorf("unexpected error: %v", err)
				return
			}
			if ok {
				allowed.Add(1)
			}
		}()
	}
	wg.Wait()
	if got := allowed.Load(); got != limit {
		t.Fatalf("concurrent allowed=%d want %d", got, limit)
	}
}

type failingRateLimiter struct {
	err error
}

func (f failingRateLimiter) Allow(context.Context, string, int, time.Time) (bool, error) {
	return false, f.err
}

func TestAPIRateLimiterFailOpenLogsAndCounts(t *testing.T) {
	var logs bytes.Buffer
	logger := slog.New(slog.NewJSONHandler(&logs, nil))
	failOpen := true
	h := New(
		&fakeRepository{},
		&fakeAuthenticator{},
		fakeRecommender{},
		fakeChatProvider{},
		logger,
		nil,
		time.Second,
		Options{
			MetricsToken:      "private-token",
			ClientIPHeader:    "X-Real-IP",
			RateLimiter:       failingRateLimiter{err: context.DeadlineExceeded},
			RateLimitFailOpen: &failOpen,
		},
	)

	req := httptest.NewRequest(http.MethodGet, "/v1/public/cards", nil)
	req.Header.Set("X-Real-IP", "203.0.113.42")
	res := httptest.NewRecorder()
	h.ServeHTTP(res, req)
	if res.Code != http.StatusOK {
		t.Fatalf("fail-open status=%d want 200: %s", res.Code, res.Body.String())
	}

	logOutput := logs.String()
	if !strings.Contains(logOutput, `"msg":"rate limiter backend failed"`) || !strings.Contains(logOutput, `"bucket":"ip"`) || !strings.Contains(logOutput, `"fail_open":true`) {
		t.Fatalf("missing structured warning in logs: %s", logOutput)
	}
	if strings.Contains(logOutput, "203.0.113.42") {
		t.Fatalf("logs must not record raw client IP: %s", logOutput)
	}

	metricsReq := httptest.NewRequest(http.MethodGet, "/metrics", nil)
	metricsReq.Header.Set("Authorization", "Bearer private-token")
	metricsRes := httptest.NewRecorder()
	h.ServeHTTP(metricsRes, metricsReq)
	body := metricsRes.Body.String()
	if !strings.Contains(body, "revocred_rate_limit_errors_total 1\n") {
		t.Fatalf("missing rate limit error metric:\n%s", body)
	}
	if !strings.Contains(body, "revocred_rate_limited_total 0\n") {
		t.Fatalf("unexpected rate limited counter:\n%s", body)
	}
}

func TestAPIRateLimiterFailClosedReturns503AndCounts(t *testing.T) {
	var logs bytes.Buffer
	logger := slog.New(slog.NewJSONHandler(&logs, nil))
	failOpen := false
	h := New(
		&fakeRepository{},
		&fakeAuthenticator{},
		fakeRecommender{},
		fakeChatProvider{},
		logger,
		nil,
		time.Second,
		Options{
			MetricsToken:      "private-token",
			RateLimiter:       failingRateLimiter{err: errors.New("connection pool exhausted")},
			RateLimitFailOpen: &failOpen,
		},
	)

	req := httptest.NewRequest(http.MethodGet, "/v1/public/cards", nil)
	res := httptest.NewRecorder()
	h.ServeHTTP(res, req)
	if res.Code != http.StatusServiceUnavailable {
		t.Fatalf("fail-closed status=%d want 503: %s", res.Code, res.Body.String())
	}
	if res.Header().Get("Retry-After") == "" {
		t.Fatal("expected Retry-After header on fail-closed 503")
	}
	var payload struct {
		Error struct {
			Code string `json:"code"`
		} `json:"error"`
	}
	if err := json.Unmarshal(res.Body.Bytes(), &payload); err != nil {
		t.Fatal(err)
	}
	if payload.Error.Code != "rate_limit_unavailable" {
		t.Fatalf("error code=%q want rate_limit_unavailable", payload.Error.Code)
	}
	if !strings.Contains(logs.String(), `"fail_open":false`) {
		t.Fatalf("missing fail_open=false log: %s", logs.String())
	}

	metricsReq := httptest.NewRequest(http.MethodGet, "/metrics", nil)
	metricsReq.Header.Set("Authorization", "Bearer private-token")
	metricsRes := httptest.NewRecorder()
	h.ServeHTTP(metricsRes, metricsReq)
	body := metricsRes.Body.String()
	if !strings.Contains(body, "revocred_rate_limit_errors_total 1\n") || !strings.Contains(body, "revocred_errors_total 1\n") {
		t.Fatalf("unexpected metrics:\n%s", body)
	}
}
