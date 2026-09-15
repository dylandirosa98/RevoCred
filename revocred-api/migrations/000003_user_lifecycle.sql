-- +goose Up
ALTER TABLE revocred.profiles
    ADD CONSTRAINT profiles_auth_user_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE revocred.questionnaire_responses
    ADD CONSTRAINT questionnaire_responses_auth_user_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE revocred.wallet_cards
    ADD CONSTRAINT wallet_cards_auth_user_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE revocred.recommendation_runs
    ADD CONSTRAINT recommendation_runs_auth_user_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE revocred.chat_messages
    ADD CONSTRAINT chat_messages_auth_user_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE revocred.recommendation_runs
    DROP CONSTRAINT recommendation_runs_questionnaire_response_id_fkey,
    ADD CONSTRAINT recommendation_runs_questionnaire_response_id_fkey
    FOREIGN KEY (questionnaire_response_id)
    REFERENCES revocred.questionnaire_responses(id) ON DELETE CASCADE;

-- +goose StatementBegin
CREATE FUNCTION revocred.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;
-- +goose StatementEnd

CREATE TRIGGER profiles_set_updated_at
BEFORE UPDATE ON revocred.profiles
FOR EACH ROW EXECUTE FUNCTION revocred.set_updated_at();

CREATE TRIGGER wallet_cards_set_updated_at
BEFORE UPDATE ON revocred.wallet_cards
FOR EACH ROW EXECUTE FUNCTION revocred.set_updated_at();

-- +goose Down
DROP TRIGGER IF EXISTS wallet_cards_set_updated_at ON revocred.wallet_cards;
DROP TRIGGER IF EXISTS profiles_set_updated_at ON revocred.profiles;
DROP FUNCTION IF EXISTS revocred.set_updated_at();

ALTER TABLE revocred.recommendation_runs
    DROP CONSTRAINT recommendation_runs_questionnaire_response_id_fkey,
    ADD CONSTRAINT recommendation_runs_questionnaire_response_id_fkey
    FOREIGN KEY (questionnaire_response_id)
    REFERENCES revocred.questionnaire_responses(id) ON DELETE RESTRICT;

ALTER TABLE revocred.chat_messages DROP CONSTRAINT chat_messages_auth_user_fkey;
ALTER TABLE revocred.recommendation_runs DROP CONSTRAINT recommendation_runs_auth_user_fkey;
ALTER TABLE revocred.wallet_cards DROP CONSTRAINT wallet_cards_auth_user_fkey;
ALTER TABLE revocred.questionnaire_responses DROP CONSTRAINT questionnaire_responses_auth_user_fkey;
ALTER TABLE revocred.profiles DROP CONSTRAINT profiles_auth_user_fkey;
