-- +goose Up
-- Remember which search-index product a member's own card is, so the API can
-- score a card added without typed terms with conservative community earning
-- rates (OpenCard DB, mapped in internal/carddata). The link identifies the
-- product only: terms the member typed always win, and a linked card is still
-- owned user_supplied data that can never be recommended.
ALTER TABLE revocred.catalog_cards
    ADD COLUMN reference_card_id UUID REFERENCES revocred.card_reference_index(id) ON DELETE SET NULL,
    ADD CONSTRAINT catalog_cards_reference_owned
        CHECK (reference_card_id IS NULL OR (owner_user_id IS NOT NULL AND data_kind = 'user_supplied'));
CREATE INDEX catalog_cards_reference_card ON revocred.catalog_cards(reference_card_id)
    WHERE reference_card_id IS NOT NULL;
COMMENT ON COLUMN revocred.catalog_cards.reference_card_id IS
    'Search-index product this owned card was added as (exact issuer + name). Identity only; never overrides member-entered terms.';

-- Existing owned cards were created from index rows with the row's exact
-- issuer and name, so an exact case-insensitive match recovers the link.
UPDATE revocred.catalog_cards c
SET reference_card_id = r.id
FROM revocred.card_reference_index r
WHERE c.owner_user_id IS NOT NULL
  AND c.data_kind = 'user_supplied'
  AND c.reference_card_id IS NULL
  AND r.is_active
  AND lower(r.issuer) = lower(c.issuer)
  AND lower(r.name) = lower(c.name);

-- The runtime role keeps its existing table-level INSERT/DELETE/SELECT on
-- catalog_cards (000008), which covers the new column. No UPDATE is granted:
-- the link is written only when the card is created.

-- +goose Down
ALTER TABLE revocred.catalog_cards
    DROP CONSTRAINT catalog_cards_reference_owned,
    DROP COLUMN reference_card_id;
