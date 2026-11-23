-- +goose Up
-- Forward-only migration: add out-of-band operator moderation triage fields to
-- revocred.chat_feedback and restrict revocred_runtime to user-owned feedback
-- columns so the public API can neither read nor tamper with triage state.
ALTER TABLE revocred.chat_feedback
    ADD COLUMN status TEXT NOT NULL DEFAULT 'open'
        CHECK (status IN ('open', 'reviewed', 'actioned', 'dismissed')),
    ADD COLUMN reviewed_by TEXT
        CHECK (reviewed_by IS NULL OR char_length(btrim(reviewed_by)) BETWEEN 1 AND 200),
    ADD COLUMN reviewed_at TIMESTAMPTZ,
    ADD COLUMN resolution_note TEXT
        CHECK (resolution_note IS NULL OR char_length(resolution_note) <= 2000),
    ADD CONSTRAINT chat_feedback_triage_consistency CHECK (
        (status = 'open' AND reviewed_by IS NULL AND reviewed_at IS NULL AND resolution_note IS NULL)
        OR
        (status IN ('reviewed', 'actioned', 'dismissed') AND reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL)
    );

CREATE INDEX chat_feedback_status_created_idx
    ON revocred.chat_feedback (status, created_at DESC);

-- Reopen a previously triaged feedback row if the user changes their rating or
-- reason (for example escalating a thumbs-up to a harmful-content report).
-- +goose StatementBegin
CREATE FUNCTION revocred.reopen_chat_feedback_on_edit() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.rating IS DISTINCT FROM OLD.rating OR NEW.reason IS DISTINCT FROM OLD.reason THEN
        NEW.status := 'open';
        NEW.reviewed_by := NULL;
        NEW.reviewed_at := NULL;
        NEW.resolution_note := NULL;
    END IF;
    RETURN NEW;
END;
$$;
-- +goose StatementEnd

CREATE TRIGGER chat_feedback_reopen_on_edit
    BEFORE UPDATE ON revocred.chat_feedback
    FOR EACH ROW
    EXECUTE FUNCTION revocred.reopen_chat_feedback_on_edit();

-- Enforce least privilege: revocred_runtime may only read/insert/update user
-- feedback fields, never read or mutate operator triage fields, and never
-- directly delete reports (chat clearing and account deletion still cascade).
REVOKE ALL ON revocred.chat_feedback FROM PUBLIC;
REVOKE ALL ON revocred.chat_feedback FROM revocred_runtime;
GRANT SELECT (message_id, user_id, rating, reason, created_at, updated_at)
    ON revocred.chat_feedback TO revocred_runtime;
GRANT INSERT (message_id, user_id, rating, reason, created_at, updated_at)
    ON revocred.chat_feedback TO revocred_runtime;
GRANT UPDATE (rating, reason, updated_at)
    ON revocred.chat_feedback TO revocred_runtime;

-- +goose StatementBegin
DO $$ DECLARE r TEXT; BEGIN
    FOREACH r IN ARRAY ARRAY['anon','authenticated'] LOOP
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname=r) THEN
            EXECUTE format('REVOKE ALL ON revocred.chat_feedback FROM %I', r);
        END IF;
    END LOOP;
END $$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DO $$ BEGIN RAISE EXCEPTION 'Chat feedback moderation migration is forward-only; restore a tested backup or deploy a corrective migration'; END $$;
-- +goose StatementEnd
