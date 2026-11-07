-- +goose Up
-- Backend-issued next steps, not all ranked alternatives or all owned cards.
-- Keep this provenance independently of the rolling recommendation-run limit.
CREATE TABLE revocred.issued_recommendations (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    strategy_code TEXT NOT NULL CHECK (strategy_code ~ '^S0[1-9]$'),
    catalog_card_id UUID NOT NULL REFERENCES revocred.catalog_cards(id),
    issued_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    source TEXT NOT NULL CHECK (source IN ('bootstrap_next', 'saved_rank1', 'legacy_questionnaire_rank1')),
    source_run_id UUID REFERENCES revocred.recommendation_runs(id) ON DELETE SET NULL,
    PRIMARY KEY (user_id, strategy_code, catalog_card_id)
);
COMMENT ON TABLE revocred.issued_recommendations IS
    'Exact server-issued recommendations. Completion means the same product is now in the active wallet, not approval, an application date, or proof of a viewed screen.';
REVOKE ALL ON revocred.issued_recommendations FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT ON revocred.issued_recommendations TO revocred_runtime;

-- +goose Down
DROP TABLE revocred.issued_recommendations;
