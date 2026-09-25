-- +goose Up
-- +goose StatementBegin
CREATE FUNCTION revocred.limit_account_cards() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE account_id UUID; n BIGINT;
BEGIN
    IF TG_TABLE_NAME = 'catalog_cards' THEN account_id := NEW.owner_user_id;
    ELSE account_id := NEW.user_id; END IF;
    IF account_id IS NULL THEN RETURN NEW; END IF;
    PERFORM pg_advisory_xact_lock(hashtextextended(account_id::text, 0));
    IF TG_TABLE_NAME = 'catalog_cards' THEN
        SELECT count(*) INTO n FROM revocred.catalog_cards WHERE owner_user_id=account_id;
    ELSE
        SELECT count(*) INTO n FROM revocred.wallet_cards WHERE user_id=account_id;
    END IF;
    IF n >= 100 THEN RAISE EXCEPTION 'account card limit reached' USING ERRCODE='54000'; END IF;
    RETURN NEW;
END;
$$;
-- +goose StatementEnd
CREATE TRIGGER custom_card_limit BEFORE INSERT ON revocred.catalog_cards FOR EACH ROW EXECUTE FUNCTION revocred.limit_account_cards();
CREATE TRIGGER wallet_card_limit BEFORE INSERT ON revocred.wallet_cards FOR EACH ROW EXECUTE FUNCTION revocred.limit_account_cards();

-- Serialize history writes per account to enforce bounds under concurrency.
-- +goose StatementBegin
CREATE FUNCTION revocred.lock_account_history() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    PERFORM pg_advisory_xact_lock(hashtextextended(NEW.user_id::text, 0));
    RETURN NEW;
END;
$$;
-- +goose StatementEnd
CREATE TRIGGER chat_history_lock BEFORE INSERT ON revocred.chat_messages FOR EACH ROW EXECUTE FUNCTION revocred.lock_account_history();
CREATE TRIGGER recommendation_history_lock BEFORE INSERT ON revocred.recommendation_runs FOR EACH ROW EXECUTE FUNCTION revocred.lock_account_history();

-- +goose StatementBegin
CREATE FUNCTION revocred.trim_account_history() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_TABLE_NAME = 'chat_messages' THEN
        DELETE FROM revocred.chat_messages WHERE user_id=NEW.user_id AND sequence IN (
            SELECT sequence FROM revocred.chat_messages WHERE user_id=NEW.user_id ORDER BY sequence DESC OFFSET 1000);
    ELSE
        DELETE FROM revocred.questionnaire_responses WHERE user_id=NEW.user_id AND id IN (
            SELECT questionnaire_response_id FROM revocred.recommendation_runs WHERE user_id=NEW.user_id ORDER BY created_at DESC, id DESC OFFSET 100);
    END IF;
    RETURN NEW;
END;
$$;
-- +goose StatementEnd
CREATE TRIGGER chat_history_retention AFTER INSERT ON revocred.chat_messages FOR EACH ROW EXECUTE FUNCTION revocred.trim_account_history();
CREATE TRIGGER recommendation_history_retention AFTER INSERT ON revocred.recommendation_runs FOR EACH ROW EXECUTE FUNCTION revocred.trim_account_history();

-- A group role to grant to a separately provisioned API login. Never grant it
-- to anon/authenticated or use the migration-owner login in a public deployment.
-- +goose StatementBegin
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='revocred_runtime') THEN
        CREATE ROLE revocred_runtime NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE;
    END IF;
END $$;
-- +goose StatementEnd
GRANT USAGE ON SCHEMA revocred TO revocred_runtime;
GRANT SELECT ON ALL TABLES IN SCHEMA revocred TO revocred_runtime;
GRANT INSERT, UPDATE, DELETE ON revocred.profiles, revocred.wallet_cards TO revocred_runtime;
GRANT INSERT, DELETE ON revocred.catalog_cards, revocred.card_catalog_versions,
    revocred.questionnaire_responses, revocred.recommendation_runs,
    revocred.recommendation_items, revocred.chat_messages TO revocred_runtime;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA revocred TO revocred_runtime;
GRANT EXECUTE ON FUNCTION revocred.delete_account(UUID) TO revocred_runtime;

-- +goose StatementBegin
DO $$ DECLARE r TEXT; BEGIN
    FOREACH r IN ARRAY ARRAY['anon','authenticated'] LOOP
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname=r) THEN
            EXECUTE format('REVOKE ALL ON SCHEMA revocred FROM %I', r);
            EXECUTE format('REVOKE ALL ON ALL TABLES IN SCHEMA revocred FROM %I', r);
            EXECUTE format('REVOKE ALL ON ALL FUNCTIONS IN SCHEMA revocred FROM %I', r);
        END IF;
    END LOOP;
END $$;
-- +goose StatementEnd

-- +goose Down
DROP TRIGGER chat_history_retention ON revocred.chat_messages;
DROP TRIGGER recommendation_history_retention ON revocred.recommendation_runs;
DROP TRIGGER chat_history_lock ON revocred.chat_messages;
DROP TRIGGER recommendation_history_lock ON revocred.recommendation_runs;
DROP TRIGGER custom_card_limit ON revocred.catalog_cards;
DROP TRIGGER wallet_card_limit ON revocred.wallet_cards;
DROP FUNCTION revocred.trim_account_history();
DROP FUNCTION revocred.lock_account_history();
DROP FUNCTION revocred.limit_account_cards();
