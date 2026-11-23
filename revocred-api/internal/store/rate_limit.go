package store

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

const (
	defaultRateLimitWindow          = time.Minute
	defaultRateLimitQueryTimeout    = 500 * time.Millisecond
	defaultRateLimitCleanupInterval = 5 * time.Minute
	defaultRateLimitCleanupTimeout  = 5 * time.Second
	maxRateLimitKeyLength           = 256
)

type rateLimitDB interface {
	QueryRow(context.Context, string, ...any) pgx.Row
	Exec(context.Context, string, ...any) (pgconn.CommandTag, error)
}

// PostgresRateLimiterOptions configures a PostgresRateLimiter. Zero fields use
// safe defaults (1-minute window, 500ms query timeout, 5-minute cleanup sweep).
type PostgresRateLimiterOptions struct {
	Window          time.Duration
	QueryTimeout    time.Duration
	CleanupInterval time.Duration
	Logger          *slog.Logger
}

// PostgresRateLimiter enforces shared fixed-window rate limits across API
// replicas using the unlogged revocred.rate_limit_windows table.
type PostgresRateLimiter struct {
	db              rateLimitDB
	window          time.Duration
	queryTimeout    time.Duration
	cleanupInterval time.Duration
	logger          *slog.Logger
}

// NewPostgresRateLimiter creates a shared Postgres-backed rate limiter.
func NewPostgresRateLimiter(pool *pgxpool.Pool, opts PostgresRateLimiterOptions) *PostgresRateLimiter {
	return newPostgresRateLimiter(pool, opts)
}

func newPostgresRateLimiter(db rateLimitDB, opts PostgresRateLimiterOptions) *PostgresRateLimiter {
	window := opts.Window
	if window <= 0 {
		window = defaultRateLimitWindow
	}
	queryTimeout := opts.QueryTimeout
	if queryTimeout <= 0 {
		queryTimeout = defaultRateLimitQueryTimeout
	}
	cleanupInterval := opts.CleanupInterval
	if cleanupInterval <= 0 {
		cleanupInterval = defaultRateLimitCleanupInterval
	}
	logger := opts.Logger
	if logger == nil {
		logger = slog.Default()
	}
	return &PostgresRateLimiter{
		db:              db,
		window:          window,
		queryTimeout:    queryTimeout,
		cleanupInterval: cleanupInterval,
		logger:          logger,
	}
}

// CheckReady verifies that revocred.rate_limit_windows exists and is writable
// by the current database role.
func (l *PostgresRateLimiter) CheckReady(ctx context.Context) error {
	var ready bool
	if err := l.db.QueryRow(ctx, `
SELECT to_regclass('revocred.rate_limit_windows') IS NOT NULL
   AND has_table_privilege('revocred.rate_limit_windows', 'SELECT, INSERT, UPDATE, DELETE')
`).Scan(&ready); err != nil {
		return err
	}
	if !ready {
		return errors.New("revocred.rate_limit_windows is missing or lacks runtime privileges")
	}
	return nil
}

// Allow atomically increments the fixed-window counter for key and reports
// whether the request is within limit.
func (l *PostgresRateLimiter) Allow(ctx context.Context, key string, limit int, now time.Time) (bool, error) {
	if limit <= 0 {
		return false, nil
	}
	key = normalizeRateLimitKey(key)
	nowUTC := now.UTC()
	until := nowUTC.Add(l.window)

	queryCtx := ctx
	var cancel context.CancelFunc
	if l.queryTimeout > 0 {
		queryCtx, cancel = context.WithTimeout(ctx, l.queryTimeout)
		defer cancel()
	}

	var allowed bool
	err := l.db.QueryRow(queryCtx, `
INSERT INTO revocred.rate_limit_windows (key, window_until, count)
VALUES ($1, $3, 1)
ON CONFLICT (key) DO UPDATE SET
    window_until = CASE
        WHEN revocred.rate_limit_windows.window_until <= $2 THEN $3
        ELSE revocred.rate_limit_windows.window_until
    END,
    count = CASE
        WHEN revocred.rate_limit_windows.window_until <= $2 THEN 1
        ELSE LEAST(revocred.rate_limit_windows.count + 1, $4 + 1)
    END
RETURNING count <= $4
`, key, nowUTC, until, limit).Scan(&allowed)
	if err != nil {
		return false, err
	}
	return allowed, nil
}

// Cleanup deletes expired rate-limit windows up to now and returns the number
// of rows removed.
func (l *PostgresRateLimiter) Cleanup(ctx context.Context, now time.Time) (int64, error) {
	tag, err := l.db.Exec(ctx, `DELETE FROM revocred.rate_limit_windows WHERE window_until <= $1`, now.UTC())
	if err != nil {
		return 0, err
	}
	return tag.RowsAffected(), nil
}

// RunCleanup periodically removes expired windows until ctx is cancelled.
func (l *PostgresRateLimiter) RunCleanup(ctx context.Context) {
	ticker := time.NewTicker(l.cleanupInterval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case now := <-ticker.C:
			sweepCtx, cancel := context.WithTimeout(ctx, defaultRateLimitCleanupTimeout)
			_, err := l.Cleanup(sweepCtx, now)
			cancel()
			if err != nil && !errors.Is(err, context.Canceled) {
				l.logger.Warn("rate limit cleanup failed", "error", err)
			}
		}
	}
}

func normalizeRateLimitKey(key string) string {
	if key == "" {
		return "empty"
	}
	if len(key) <= maxRateLimitKeyLength {
		return key
	}
	sum := sha256.Sum256([]byte(key))
	return "sha256:" + hex.EncodeToString(sum[:])
}
