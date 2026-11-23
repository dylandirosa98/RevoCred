package store

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

type fakeRateLimitRow struct {
	allowed bool
	err     error
}

func (r fakeRateLimitRow) Scan(dest ...any) error {
	if r.err != nil {
		return r.err
	}
	if len(dest) == 1 {
		if target, ok := dest[0].(*bool); ok {
			*target = r.allowed
			return nil
		}
	}
	return errors.New("unexpected scan target")
}

type fakeRateLimitDB struct {
	queryRow func(context.Context, string, ...any) pgx.Row
	exec     func(context.Context, string, ...any) (pgconn.CommandTag, error)
}

func (f *fakeRateLimitDB) QueryRow(ctx context.Context, sql string, args ...any) pgx.Row {
	return f.queryRow(ctx, sql, args...)
}

func (f *fakeRateLimitDB) Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error) {
	return f.exec(ctx, sql, args...)
}

func TestNormalizeRateLimitKey(t *testing.T) {
	if got := normalizeRateLimitKey(""); got != "empty" {
		t.Fatalf("empty key -> %q", got)
	}
	short := "ip:203.0.113.10"
	if got := normalizeRateLimitKey(short); got != short {
		t.Fatalf("short key changed -> %q", got)
	}
	long := strings.Repeat("a", 300)
	got := normalizeRateLimitKey(long)
	if !strings.HasPrefix(got, "sha256:") || len(got) != len("sha256:")+64 {
		t.Fatalf("long key not hashed: %q (len=%d)", got, len(got))
	}
	if got != normalizeRateLimitKey(long) {
		t.Fatal("hashed key is not deterministic")
	}
}

func TestPostgresRateLimiterZeroLimitSkipsDB(t *testing.T) {
	called := false
	limiter := newPostgresRateLimiter(&fakeRateLimitDB{
		queryRow: func(context.Context, string, ...any) pgx.Row {
			called = true
			return fakeRateLimitRow{allowed: true}
		},
	}, PostgresRateLimiterOptions{Logger: slog.New(slog.NewTextHandler(io.Discard, nil))})

	allowed, err := limiter.Allow(context.Background(), "ip:1.2.3.4", 0, time.Now())
	if err != nil || allowed || called {
		t.Fatalf("zero limit: allowed=%v err=%v called=%v", allowed, err, called)
	}
}

func TestPostgresRateLimiterEnforcesQueryTimeoutAndConcurrency(t *testing.T) {
	var calls atomic.Int32
	limiter := newPostgresRateLimiter(&fakeRateLimitDB{
		queryRow: func(ctx context.Context, _ string, _ ...any) pgx.Row {
			calls.Add(1)
			<-ctx.Done()
			return fakeRateLimitRow{err: ctx.Err()}
		},
	}, PostgresRateLimiterOptions{
		QueryTimeout: 25 * time.Millisecond,
		Logger:       slog.New(slog.NewTextHandler(io.Discard, nil)),
	})

	var wg sync.WaitGroup
	for i := 0; i < 8; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			allowed, err := limiter.Allow(context.Background(), "ip:slow", 10, time.Now())
			if allowed || !errors.Is(err, context.DeadlineExceeded) {
				t.Errorf("expected DeadlineExceeded, got allowed=%v err=%v", allowed, err)
			}
		}()
	}
	wg.Wait()
	if calls.Load() != 8 {
		t.Fatalf("calls=%d want 8", calls.Load())
	}
}

func TestPostgresRateLimiterRunCleanupStopsOnCancel(t *testing.T) {
	var sweeps atomic.Int32
	limiter := newPostgresRateLimiter(&fakeRateLimitDB{
		exec: func(context.Context, string, ...any) (pgconn.CommandTag, error) {
			sweeps.Add(1)
			return pgconn.NewCommandTag("DELETE 0"), nil
		},
	}, PostgresRateLimiterOptions{
		CleanupInterval: 10 * time.Millisecond,
		Logger:          slog.New(slog.NewTextHandler(io.Discard, nil)),
	})

	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		defer close(done)
		limiter.RunCleanup(ctx)
	}()

	deadline := time.Now().Add(time.Second)
	for sweeps.Load() < 2 && time.Now().Before(deadline) {
		time.Sleep(5 * time.Millisecond)
	}
	cancel()
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("RunCleanup did not stop on context cancellation")
	}
	if sweeps.Load() < 2 {
		t.Fatalf("expected at least 2 cleanup sweeps, got %d", sweeps.Load())
	}
}

func testPostgresRateLimiter(t *testing.T, ctx context.Context, admin, runtimePool *pgxpool.Pool) {
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	limiterA := NewPostgresRateLimiter(runtimePool, PostgresRateLimiterOptions{
		Window:       time.Minute,
		QueryTimeout: 2 * time.Second,
		Logger:       logger,
	})
	limiterB := NewPostgresRateLimiter(runtimePool, PostgresRateLimiterOptions{
		Window:       time.Minute,
		QueryTimeout: 2 * time.Second,
		Logger:       logger,
	})

	if err := limiterA.CheckReady(ctx); err != nil {
		t.Fatalf("CheckReady as revocred_runtime: %v", err)
	}

	base := time.Date(2026, 11, 23, 12, 0, 0, 0, time.UTC)
	key := "ip:203.0.113.10"
	for i := 0; i < 3; i++ {
		ok, err := limiterA.Allow(ctx, key, 3, base.Add(time.Duration(i)*time.Second))
		if err != nil || !ok {
			t.Fatalf("request %d denied: ok=%v err=%v", i+1, ok, err)
		}
	}
	// Second replica sees the shared counter immediately.
	if ok, err := limiterB.Allow(ctx, key, 3, base.Add(10*time.Second)); err != nil || ok {
		t.Fatalf("second replica allowed over limit: ok=%v err=%v", ok, err)
	}
	// Another key is unaffected.
	if ok, err := limiterB.Allow(ctx, "ip:203.0.113.11", 3, base.Add(10*time.Second)); err != nil || !ok {
		t.Fatalf("other key denied: ok=%v err=%v", ok, err)
	}
	// Window expiry resets the counter cleanly.
	if ok, err := limiterB.Allow(ctx, key, 3, base.Add(time.Minute)); err != nil || !ok {
		t.Fatalf("expired window did not reset: ok=%v err=%v", ok, err)
	}
	// Keys exceeding 256 characters are hashed transparently.
	longKey := "ip:" + strings.Repeat("x", 300)
	if ok, err := limiterA.Allow(ctx, longKey, 1, base); err != nil || !ok {
		t.Fatalf("long key first call failed: ok=%v err=%v", ok, err)
	}
	if ok, err := limiterB.Allow(ctx, longKey, 1, base.Add(time.Second)); err != nil || ok {
		t.Fatalf("long key second call allowed: ok=%v err=%v", ok, err)
	}

	// Concurrent requests across two limiter instances observe exact atomic limit.
	const workers = 24
	const concurrentLimit = 7
	var allowed atomic.Int32
	var wg sync.WaitGroup
	wg.Add(workers)
	for i := 0; i < workers; i++ {
		inst := limiterA
		if i%2 == 1 {
			inst = limiterB
		}
		go func(l *PostgresRateLimiter) {
			defer wg.Done()
			ok, err := l.Allow(ctx, "write:concurrent-user", concurrentLimit, base)
			if err != nil {
				t.Errorf("concurrent Allow error: %v", err)
				return
			}
			if ok {
				allowed.Add(1)
			}
		}(inst)
	}
	wg.Wait()
	if got := allowed.Load(); got != concurrentLimit {
		t.Fatalf("concurrent Postgres allowed=%d want %d", got, concurrentLimit)
	}

	// Cleanup removes expired windows while preserving active ones:
	// longKey and write:concurrent-user expire at base+1m; ip:203.0.113.11
	// expires at base+1m10s; key expires at base+2m.
	removed, err := limiterA.Cleanup(ctx, base.Add(time.Minute))
	if err != nil {
		t.Fatalf("Cleanup failed: %v", err)
	}
	if removed != 2 {
		t.Fatalf("expected 2 expired rows removed at base+1m, got %d", removed)
	}
	removed, err = limiterA.Cleanup(ctx, base.Add(time.Minute+15*time.Second))
	if err != nil {
		t.Fatalf("second Cleanup failed: %v", err)
	}
	if removed != 1 {
		t.Fatalf("expected 1 expired row removed at base+1m15s, got %d", removed)
	}
	var remaining int
	if err := runtimePool.QueryRow(ctx, `SELECT count(*) FROM revocred.rate_limit_windows WHERE key = $1`, key).Scan(&remaining); err != nil || remaining != 1 {
		t.Fatalf("active window should remain after cleanup: remaining=%d err=%v", remaining, err)
	}

	// Browser-facing Supabase roles cannot read or mutate rate_limit_windows.
	for _, role := range []string{"anon", "authenticated"} {
		for action, stmt := range map[string]string{
			"select": `SELECT count(*) FROM revocred.rate_limit_windows`,
			"insert": `INSERT INTO revocred.rate_limit_windows(key,window_until,count) VALUES ('evil',now(),1)`,
			"delete": `DELETE FROM revocred.rate_limit_windows`,
		} {
			tx, err := admin.Begin(ctx)
			if err != nil {
				t.Fatal(err)
			}
			if _, err = tx.Exec(ctx, "SET LOCAL ROLE "+role); err != nil {
				t.Fatal(err)
			}
			_, err = tx.Exec(ctx, stmt)
			_ = tx.Rollback(ctx)
			if err == nil {
				t.Fatalf("role %s was allowed to %s revocred.rate_limit_windows", role, action)
			}
		}
	}
}
