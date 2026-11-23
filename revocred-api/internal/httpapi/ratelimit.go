package httpapi

import (
	"context"
	"strings"
	"sync"
	"time"
)

const (
	defaultMemoryRateLimitWindow  = time.Minute
	defaultMemoryRateLimitMaxKeys = 10000
)

// RateLimiter decides whether a request identified by key may proceed within
// the current fixed 1-minute window.
type RateLimiter interface {
	Allow(ctx context.Context, key string, limit int, now time.Time) (bool, error)
}

type window struct {
	until time.Time
	count int
}

// MemoryRateLimiter enforces bounded per-process fixed-window rate limits.
// It is the zero-overhead default for single-replica deployments and tests.
type MemoryRateLimiter struct {
	mu      sync.Mutex
	entries map[string]window
	window  time.Duration
	maxKeys int
}

// NewMemoryRateLimiter creates a bounded in-memory fixed-window rate limiter.
func NewMemoryRateLimiter() *MemoryRateLimiter {
	return &MemoryRateLimiter{
		entries: make(map[string]window),
		window:  defaultMemoryRateLimitWindow,
		maxKeys: defaultMemoryRateLimitMaxKeys,
	}
}

func (l *MemoryRateLimiter) Allow(_ context.Context, key string, limit int, now time.Time) (bool, error) {
	if limit <= 0 {
		return false, nil
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.entries == nil {
		l.entries = map[string]window{}
	}
	windowLen := l.window
	if windowLen <= 0 {
		windowLen = defaultMemoryRateLimitWindow
	}
	maxKeys := l.maxKeys
	if maxKeys <= 0 {
		maxKeys = defaultMemoryRateLimitMaxKeys
	}
	current, exists := l.entries[key]
	if !exists && len(l.entries) >= maxKeys {
		for k, v := range l.entries {
			if !now.Before(v.until) {
				delete(l.entries, k)
			}
		}
		if len(l.entries) >= maxKeys {
			return false, nil
		}
	}
	if !now.Before(current.until) {
		current = window{until: now.Add(windowLen)}
	}
	if current.count >= limit {
		return false, nil
	}
	current.count++
	l.entries[key] = current
	return true, nil
}

// rateLimitBucket extracts only the key's bucket prefix (for example "ip",
// "read", or "write") so backend failure logs avoid recording raw IPs or IDs.
func rateLimitBucket(key string) string {
	if prefix, _, ok := strings.Cut(key, ":"); ok && prefix != "" {
		return prefix
	}
	return "unknown"
}
