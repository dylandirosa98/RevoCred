package store

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
)

// AIPlan reports the account's REVO AI plan and today's usage.
func (p *Postgres) AIPlan(ctx context.Context, userID string, freeLimit, paidLimit int) (AIPlan, error) {
	plan := AIPlan{Limit: freeLimit}
	var source string
	var expires *time.Time
	err := p.pool.QueryRow(ctx, `SELECT source, expires_at FROM revocred.ai_entitlements WHERE user_id=$1`, userID).Scan(&source, &expires)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return AIPlan{}, err
	}
	if err == nil && (expires == nil || expires.After(time.Now())) {
		plan.Subscriber, plan.Source, plan.ExpiresAt, plan.Limit = true, source, expires, paidLimit
	}
	var oldest *time.Time
	if err = p.pool.QueryRow(ctx, `SELECT count(*), min(created_at) FROM revocred.chat_ai_usage
		WHERE user_id=$1 AND created_at > now() - interval '24 hours'`, userID).Scan(&plan.Used, &oldest); err != nil {
		return AIPlan{}, err
	}
	if oldest != nil {
		next := oldest.Add(24 * time.Hour)
		plan.NextResetAt = &next
	}
	return plan, nil
}

// ApplyRevenueCatEntitlement stores RevenueCat subscription state through the
// database's narrow write function. See migration 000030 for its guarantees.
func (p *Postgres) ApplyRevenueCatEntitlement(ctx context.Context, update EntitlementUpdate) (string, error) {
	var eventID *string
	if update.EventID != "" {
		eventID = &update.EventID
	}
	var product *string
	if update.ProductID != "" {
		product = &update.ProductID
	}
	var outcome string
	err := p.pool.QueryRow(ctx, `SELECT revocred.apply_revenuecat_entitlement($1,$2,$3,$4,$5)`,
		eventID, update.UserID, update.EventAt, update.ExpiresAt, product).Scan(&outcome)
	return outcome, err
}
