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

func (p *Postgres) ChatAICount(ctx context.Context, userID string) (int, error) {
	var count int
	err := p.pool.QueryRow(ctx, "SELECT count(*) FROM revocred.chat_messages WHERE user_id=$1 AND role='assistant' AND mode='ai' AND created_at>now()-interval '24 hours'", userID).Scan(&count)
	return count, err
}

func (p *Postgres) ChatFeedback(ctx context.Context, userID, messageID, rating, reason string) (bool, error) {
	tag, err := p.pool.Exec(ctx, `INSERT INTO revocred.chat_feedback(message_id,user_id,rating,reason)
 SELECT id,user_id,$3,NULLIF($4, '') FROM revocred.chat_messages WHERE id::text=$2 AND user_id=$1 AND role='assistant'
 ON CONFLICT(message_id) DO UPDATE SET rating=excluded.rating,reason=excluded.reason,updated_at=now()`, userID, messageID, rating, reason)
	return tag.RowsAffected() > 0, err
}
