-- +goose Up
-- Older rows and clients have no wallet-size preference, so the empty value is
-- retained as an explicit backwards-compatible state.
ALTER TABLE revocred.questionnaire_responses
    ADD COLUMN ideal_card_count TEXT NOT NULL DEFAULT ''
    CHECK (ideal_card_count IN ('', '1-2', '2-3', '3-4', '4+'));

-- +goose Down
ALTER TABLE revocred.questionnaire_responses DROP COLUMN ideal_card_count;
