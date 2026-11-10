package store

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
)

func (p *Postgres) ChatConsent(ctx context.Context, userID string) (string, error) {
	var version string
	err := p.pool.QueryRow(ctx, "SELECT version FROM revocred.chat_ai_consents WHERE user_id=$1", userID).Scan(&version)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", nil
	}
	return version, err
}

func (p *Postgres) SetChatConsent(ctx context.Context, userID, version string) error {
	if version == "" {
		_, err := p.pool.Exec(ctx, "DELETE FROM revocred.chat_ai_consents WHERE user_id=$1", userID)
		return err
	}
	_, err := p.pool.Exec(ctx, "INSERT INTO revocred.chat_ai_consents(user_id,version) VALUES($1,$2) ON CONFLICT(user_id) DO UPDATE SET version=excluded.version, granted_at=now()", userID, version)
	return err
}

func (p *Postgres) ClearChat(ctx context.Context, userID string) error {
	_, err := p.pool.Exec(ctx, "DELETE FROM revocred.chat_messages WHERE user_id=$1", userID)
	return err
}

// ReserveAIUse records one AI answer against the rolling 24-hour allowance
// before the AI is called. A per-account lock serializes parallel sends, and
// usage lives apart from chat history so clearing the chat never resets it.
func (p *Postgres) ReserveAIUse(ctx context.Context, userID string, freeLimit, paidLimit int) (AIUse, error) {
	tx, err := p.pool.Begin(ctx)
	if err != nil {
		return AIUse{}, err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	if _, err = tx.Exec(ctx, "SELECT pg_advisory_xact_lock(hashtextextended($1::text, 1))", userID); err != nil {
		return AIUse{}, err
	}
	var use AIUse
	if err = tx.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM revocred.ai_entitlements
		WHERE user_id=$1 AND (expires_at IS NULL OR expires_at > now()))`, userID).Scan(&use.Subscriber); err != nil {
		return AIUse{}, err
	}
	use.Limit = freeLimit
	if use.Subscriber {
		use.Limit = paidLimit
	}
	var used int
	if err = tx.QueryRow(ctx, "SELECT count(*) FROM revocred.chat_ai_usage WHERE user_id=$1 AND created_at > now() - interval '24 hours'", userID).Scan(&used); err != nil {
		return AIUse{}, err
	}
	if used >= use.Limit {
		return use, tx.Commit(ctx)
	}
	if err = tx.QueryRow(ctx, "INSERT INTO revocred.chat_ai_usage(user_id) VALUES($1) RETURNING id", userID).Scan(&use.ID); err != nil {
		return AIUse{}, err
	}
	if _, err = tx.Exec(ctx, "DELETE FROM revocred.chat_ai_usage WHERE user_id=$1 AND created_at < now() - interval '2 days'", userID); err != nil {
		return AIUse{}, err
	}
	use.Allowed = true
	return use, tx.Commit(ctx)
}

// ReleaseAIUse returns a reserved use when no AI answer was delivered, e.g.
// the provider failed and a basic answer was given instead.
func (p *Postgres) ReleaseAIUse(ctx context.Context, userID, useID string) error {
	_, err := p.pool.Exec(ctx, "DELETE FROM revocred.chat_ai_usage WHERE id=$1 AND user_id=$2", useID, userID)
	return err
}

func (p *Postgres) ChatFeedback(ctx context.Context, userID, messageID, rating, reason string) (bool, error) {
	tag, err := p.pool.Exec(ctx, `INSERT INTO revocred.chat_feedback(message_id,user_id,rating,reason)
 SELECT id,user_id,$3,NULLIF($4, '') FROM revocred.chat_messages WHERE id::text=$2 AND user_id=$1 AND role='assistant'
 ON CONFLICT(message_id) DO UPDATE SET rating=excluded.rating,reason=excluded.reason,updated_at=now()`, userID, messageID, rating, reason)
	return tag.RowsAffected() > 0, err
}
