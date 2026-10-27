-- +goose Up
-- REVO replies are stored as resolved blocks so a replayed conversation shows
-- exactly what was drawn at the time, instead of re-deriving numbers against a
-- newer catalog version. The plain text column is kept for export and search.
ALTER TABLE revocred.chat_messages ADD COLUMN blocks JSONB;
GRANT UPDATE (blocks) ON revocred.chat_messages TO revocred_runtime;

-- +goose Down
ALTER TABLE revocred.chat_messages DROP COLUMN blocks;
