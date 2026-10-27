-- +goose Up
-- Public community snapshots are independent of immutable issuer/scoring terms.
-- No member data, artwork downloads, or automatic recommendation candidates.
CREATE TABLE revocred.community_card_snapshots (
    payload_sha256 TEXT PRIMARY KEY CHECK (payload_sha256 ~ '^[0-9a-f]{64}$'),
    payload JSONB NOT NULL CHECK (jsonb_typeof(payload) = 'array'),
    first_fetched_at TIMESTAMPTZ NOT NULL,
    last_checked_at TIMESTAMPTZ NOT NULL
);
CREATE INDEX community_card_snapshots_latest ON revocred.community_card_snapshots(last_checked_at DESC);
REVOKE ALL ON revocred.community_card_snapshots FROM PUBLIC;
GRANT SELECT, INSERT ON revocred.community_card_snapshots TO revocred_runtime;
-- Existing payloads are never rewritten. Only the successful check time advances.
GRANT UPDATE(last_checked_at) ON revocred.community_card_snapshots TO revocred_runtime;
COMMENT ON TABLE revocred.community_card_snapshots IS
    'OpenCard DB, CC BY 4.0. Community-maintained public product data, not independently verified issuer/scoring terms.';

-- +goose Down
DROP TABLE revocred.community_card_snapshots;
