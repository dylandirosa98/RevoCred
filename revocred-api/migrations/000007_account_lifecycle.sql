-- +goose Up
-- Backend-only entry point: never grant to browser-facing Supabase roles.
-- +goose StatementBegin
CREATE FUNCTION revocred.delete_account(account_id UUID) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
    -- Delete wallet references first, including old inactive custom cards, so
    -- catalog-card RESTRICT constraints cannot obstruct the auth-user cascade.
    DELETE FROM revocred.wallet_cards WHERE user_id = account_id;
    DELETE FROM auth.users WHERE id = account_id;
END;
$$;
-- +goose StatementEnd
REVOKE ALL ON FUNCTION revocred.delete_account(UUID) FROM PUBLIC;

-- Persist chat order independently of identical transaction timestamps/UUIDs.
ALTER TABLE revocred.chat_messages ADD COLUMN sequence BIGINT GENERATED ALWAYS AS IDENTITY;
CREATE INDEX chat_messages_user_sequence_idx ON revocred.chat_messages(user_id, sequence DESC);

-- +goose Down
DROP FUNCTION revocred.delete_account(UUID);
ALTER TABLE revocred.chat_messages DROP COLUMN sequence;
