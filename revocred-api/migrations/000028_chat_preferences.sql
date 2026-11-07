-- +goose Up
ALTER TABLE revocred.chat_messages ADD COLUMN mode TEXT CHECK (mode IN ('ai','basic'));
CREATE TABLE revocred.chat_ai_consents (
 user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
 version TEXT NOT NULL CHECK (version ~ '^[0-9a-f]{64}$'),
 granted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE revocred.chat_feedback (
 message_id UUID PRIMARY KEY REFERENCES revocred.chat_messages(id) ON DELETE CASCADE,
 user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 rating TEXT NOT NULL CHECK (rating IN ('up','down')),
 reason TEXT CHECK (char_length(reason)<=500),
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TRIGGER chat_feedback_lock BEFORE INSERT ON revocred.chat_feedback FOR EACH ROW EXECUTE FUNCTION revocred.lock_account_history();
GRANT SELECT, INSERT, UPDATE, DELETE ON revocred.chat_ai_consents, revocred.chat_feedback TO revocred_runtime;
-- +goose Down
DROP TABLE revocred.chat_feedback;
DROP TABLE revocred.chat_ai_consents;
ALTER TABLE revocred.chat_messages DROP COLUMN mode;
