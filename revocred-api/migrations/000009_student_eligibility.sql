-- +goose Up
ALTER TABLE revocred.questionnaire_responses ADD COLUMN life_stage TEXT NOT NULL DEFAULT '';
-- +goose Down
ALTER TABLE revocred.questionnaire_responses DROP COLUMN life_stage;
