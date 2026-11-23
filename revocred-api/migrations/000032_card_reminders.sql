-- +goose Up
-- Optional renewal month (1-12) for annual-fee check-in reminders and
-- anniversary credit periods.
ALTER TABLE revocred.wallet_cards
    ADD COLUMN renewal_month SMALLINT CHECK (renewal_month BETWEEN 1 AND 12);

-- Per-user state for deterministic, server-computed in-app card reminders.
-- Deleting the auth user cascades cleanly via ON DELETE CASCADE.
CREATE TABLE revocred.reminder_states (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reminder_key TEXT NOT NULL CHECK (char_length(reminder_key) BETWEEN 1 AND 160),
    status TEXT NOT NULL CHECK (status IN ('completed', 'dismissed', 'snoozed')),
    snoozed_until TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, reminder_key),
    CHECK (status <> 'snoozed' OR snoozed_until IS NOT NULL)
);

CREATE INDEX reminder_states_user_updated_idx
    ON revocred.reminder_states (user_id, updated_at DESC);

REVOKE ALL ON revocred.reminder_states FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON revocred.reminder_states TO revocred_runtime;

-- +goose StatementBegin
DO $$ DECLARE r TEXT; BEGIN
    FOREACH r IN ARRAY ARRAY['anon','authenticated'] LOOP
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname=r) THEN
            EXECUTE format('REVOKE ALL ON revocred.reminder_states FROM %I', r);
        END IF;
    END LOOP;
END $$;
-- +goose StatementEnd

-- +goose Down
DROP TABLE revocred.reminder_states;
ALTER TABLE revocred.wallet_cards DROP COLUMN renewal_month;
