-- +goose Up
-- AI answers are counted here, not from chat history, so clearing the chat no
-- longer resets the daily allowance. A use is reserved before the AI call.
CREATE TABLE revocred.chat_ai_usage (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX chat_ai_usage_user_time ON revocred.chat_ai_usage(user_id, created_at DESC);

-- Paid AI access. 'manual' rows are granted by an operator (e.g. testers);
-- 'revenuecat' rows will come from the subscription service.
CREATE TABLE revocred.ai_entitlements (
 user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
 source TEXT NOT NULL CHECK (source IN ('manual','revenuecat')),
 expires_at TIMESTAMPTZ,
 updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- AI replies from the last day keep counting after the switch.
INSERT INTO revocred.chat_ai_usage(user_id, created_at)
SELECT user_id, created_at FROM revocred.chat_messages
WHERE role='assistant' AND mode='ai' AND created_at > now() - interval '24 hours';

GRANT SELECT, INSERT, DELETE ON revocred.chat_ai_usage TO revocred_runtime;
GRANT SELECT ON revocred.ai_entitlements TO revocred_runtime;
-- +goose Down
DROP TABLE revocred.ai_entitlements;
DROP TABLE revocred.chat_ai_usage;
