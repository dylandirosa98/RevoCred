-- +goose Up
-- Shared fixed-window rate-limit counters for multi-replica deployments
-- (RATE_LIMIT_BACKEND=postgres). UNLOGGED avoids WAL overhead for ephemeral
-- 1-minute windows; a PostgreSQL crash safely resets active windows just like
-- an in-process restart.
CREATE UNLOGGED TABLE revocred.rate_limit_windows (
    key TEXT PRIMARY KEY CHECK (char_length(key) BETWEEN 1 AND 256),
    window_until TIMESTAMPTZ NOT NULL,
    count INTEGER NOT NULL CHECK (count >= 1)
);

CREATE INDEX rate_limit_windows_until ON revocred.rate_limit_windows(window_until);

REVOKE ALL ON revocred.rate_limit_windows FROM PUBLIC;
-- +goose StatementBegin
DO $$ DECLARE r TEXT; BEGIN
    FOREACH r IN ARRAY ARRAY['anon','authenticated'] LOOP
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname=r) THEN
            EXECUTE format('REVOKE ALL ON revocred.rate_limit_windows FROM %I', r);
        END IF;
    END LOOP;
END $$;
-- +goose StatementEnd
GRANT SELECT, INSERT, UPDATE, DELETE ON revocred.rate_limit_windows TO revocred_runtime;

-- +goose Down
DROP TABLE revocred.rate_limit_windows;
