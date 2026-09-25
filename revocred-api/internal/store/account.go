package store

import (
	"context"
	"encoding/json"
	"github.com/jackc/pgx/v5"
)

// ExportAccount returns only this account's records, from a consistent snapshot.
func (p *Postgres) ExportAccount(ctx context.Context, userID string) (map[string]json.RawMessage, error) {
	tx, err := p.pool.BeginTx(ctx, pgx.TxOptions{IsoLevel: pgx.RepeatableRead, AccessMode: pgx.ReadOnly})
	if err != nil {
		return nil, err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	out := map[string]json.RawMessage{}
	for _, table := range []string{"profiles", "wallet_cards", "questionnaire_responses", "recommendation_runs", "chat_messages"} {
		var data []byte
		// Table identifiers are a fixed internal allowlist, never request input.
		if err = tx.QueryRow(ctx, "SELECT COALESCE(jsonb_agg(to_jsonb(t)), '[]') FROM revocred."+table+" t WHERE user_id=$1", userID).Scan(&data); err != nil {
			return nil, err
		}
		out[table] = data
	}
	for name, query := range map[string]string{
		"recommendation_items": `SELECT COALESCE(jsonb_agg(to_jsonb(i)), '[]') FROM revocred.recommendation_items i JOIN revocred.recommendation_runs r ON r.id=i.recommendation_run_id WHERE r.user_id=$1`,
		"custom_cards":         `SELECT COALESCE(jsonb_agg(to_jsonb(c)), '[]') FROM revocred.catalog_cards c WHERE owner_user_id=$1`,
		"custom_card_versions": `SELECT COALESCE(jsonb_agg(to_jsonb(v)), '[]') FROM revocred.card_catalog_versions v JOIN revocred.catalog_cards c ON c.id=v.catalog_card_id WHERE c.owner_user_id=$1`,
	} {
		var data []byte
		if err = tx.QueryRow(ctx, query, userID).Scan(&data); err != nil {
			return nil, err
		}
		out[name] = data
	}
	return out, tx.Commit(ctx)
}

func (p *Postgres) DeleteAccount(ctx context.Context, userID string) error {
	_, err := p.pool.Exec(ctx, `SELECT revocred.delete_account($1::uuid)`, userID)
	return err
}
