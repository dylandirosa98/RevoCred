package store

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
)

func (p *Postgres) LoadCardData(ctx context.Context) ([]byte, time.Time, string, error) {
	var body []byte
	var at time.Time
	var hash string
	err := p.pool.QueryRow(ctx, `SELECT payload,last_checked_at,payload_sha256 FROM revocred.community_card_snapshots ORDER BY last_checked_at DESC LIMIT 1`).Scan(&body, &at, &hash)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, time.Time{}, "", nil
	}
	return body, at, hash, err
}

func (p *Postgres) SaveCardData(ctx context.Context, body []byte, sha string, at time.Time) error {
	_, err := p.pool.Exec(ctx, `INSERT INTO revocred.community_card_snapshots(payload_sha256,payload,first_fetched_at,last_checked_at)
 VALUES ($1,$2,$3,$3) ON CONFLICT(payload_sha256) DO UPDATE SET last_checked_at=EXCLUDED.last_checked_at`, sha, body, at)
	return err
}
