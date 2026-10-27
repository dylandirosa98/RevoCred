-- +goose Up
-- Preserve old questionnaire rows and older clients while accepting the new UI.
ALTER TABLE revocred.questionnaire_responses
    DROP CONSTRAINT questionnaire_responses_ideal_card_count_check;
ALTER TABLE revocred.questionnaire_responses
    ADD CONSTRAINT questionnaire_responses_ideal_card_count_check
    CHECK (ideal_card_count IN ('', '1-2', '2-4', '2-3', '3-4', '4+'));

-- +goose Down
UPDATE revocred.questionnaire_responses SET ideal_card_count = '3-4' WHERE ideal_card_count = '2-4';
ALTER TABLE revocred.questionnaire_responses
    DROP CONSTRAINT questionnaire_responses_ideal_card_count_check;
ALTER TABLE revocred.questionnaire_responses
    ADD CONSTRAINT questionnaire_responses_ideal_card_count_check
    CHECK (ideal_card_count IN ('', '1-2', '2-3', '3-4', '4+'));
