package store

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/revocred/revocred-api/internal/domain"
)

func (p *Postgres) ListReminderStates(ctx context.Context, userID string) (map[string]domain.ReminderState, error) {
	rows, err := p.pool.Query(ctx, `
SELECT reminder_key, status, snoozed_until, updated_at
FROM revocred.reminder_states
WHERE user_id = $1`, userID)
	if err != nil {
		return nil, fmt.Errorf("list reminder states: %w", err)
	}
	defer rows.Close()

	out := make(map[string]domain.ReminderState)
	for rows.Next() {
		var st domain.ReminderState
		if err := rows.Scan(&st.ReminderKey, &st.Status, &st.SnoozedUntil, &st.UpdatedAt); err != nil {
			return nil, fmt.Errorf("scan reminder state: %w", err)
		}
		out[st.ReminderKey] = st
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate reminder states: %w", err)
	}
	return out, nil
}

func (p *Postgres) UpsertReminderState(ctx context.Context, userID, key, status string, snoozedUntil *time.Time) error {
	_, err := p.pool.Exec(ctx, `
INSERT INTO revocred.reminder_states (user_id, reminder_key, status, snoozed_until, updated_at)
VALUES ($1, $2, $3, $4, now())
ON CONFLICT (user_id, reminder_key) DO UPDATE SET
    status = EXCLUDED.status,
    snoozed_until = EXCLUDED.snoozed_until,
    updated_at = now()`,
		userID, key, status, snoozedUntil,
	)
	if err != nil {
		return fmt.Errorf("upsert reminder state: %w", err)
	}
	return nil
}

func (p *Postgres) DeleteReminderState(ctx context.Context, userID, key string) error {
	_, err := p.pool.Exec(ctx, `
DELETE FROM revocred.reminder_states
WHERE user_id = $1 AND reminder_key = $2`,
		userID, key,
	)
	if err != nil {
		return fmt.Errorf("delete reminder state: %w", err)
	}
	return nil
}

func (p *Postgres) UpdateWalletRenewalMonth(ctx context.Context, userID, walletCardID string, renewalMonth *int) (domain.WalletCard, error) {
	var item domain.WalletCard
	err := p.pool.QueryRow(ctx, `
UPDATE revocred.wallet_cards
SET renewal_month = $3, updated_at = now()
WHERE id = $1 AND user_id = $2
RETURNING id::text, user_id::text, catalog_card_id::text, nickname, status, opened_on, renewal_month, created_at`,
		walletCardID, userID, renewalMonth,
	).Scan(&item.ID, &item.UserID, &item.CatalogCardID, &item.Nickname, &item.Status, &item.OpenedOn, &item.RenewalMonth, &item.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.WalletCard{}, ErrNotFound
		}
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "22P02" {
			return domain.WalletCard{}, ErrNotFound
		}
		return domain.WalletCard{}, fmt.Errorf("update wallet renewal month: %w", err)
	}
	return item, nil
}
