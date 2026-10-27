-- +goose Up
-- A large, search-only index of cards a person might already own. These rows
-- are reference data for identification, never recommendation candidates and
-- never eligible for an Apply link. A chosen card becomes an owned
-- user_supplied catalog card, so it can never be recommended back.

-- Marks a card whose terms the user chose not to supply. Such a card is shown
-- as owned but never scored, because a missing rate would otherwise read as a
-- bad rate. The flag is inverted on purpose: an unset column must mean "terms
-- known" so no future caller can silently drop a card from scoring.
ALTER TABLE revocred.catalog_cards
    ADD COLUMN terms_unknown BOOLEAN NOT NULL DEFAULT false;

CREATE TABLE revocred.card_reference_index (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug TEXT NOT NULL CHECK (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
    issuer TEXT NOT NULL CHECK (length(issuer) BETWEEN 1 AND 100),
    name TEXT NOT NULL CHECK (length(name) BETWEEN 1 AND 150),
    network TEXT NOT NULL DEFAULT 'Unknown' CHECK (length(network) BETWEEN 1 AND 60),
    rewards_type TEXT NOT NULL DEFAULT 'unknown'
        CHECK (rewards_type IN ('cash_back','points','hybrid','unknown')),
    annual_fee_cents INTEGER NOT NULL DEFAULT 0 CHECK (annual_fee_cents >= 0),
    reward_rates JSONB NOT NULL DEFAULT '{}'::jsonb,
    -- verified: read from the issuer page on the captured date.
    -- partial: identity only, with no usable rates.
    terms_status TEXT NOT NULL DEFAULT 'partial' CHECK (terms_status IN ('verified','partial')),
    source_url TEXT NOT NULL,
    source_captured_on DATE NOT NULL,
    disclaimer TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true
);
CREATE UNIQUE INDEX card_reference_issuer_name ON revocred.card_reference_index(lower(issuer), lower(name)) WHERE is_active;
CREATE INDEX card_reference_issuer ON revocred.card_reference_index(issuer) WHERE is_active;
COMMENT ON TABLE revocred.card_reference_index IS
    'Search-only card identity index for onboarding. Not recommendable. Terms are a dated snapshot and must be verified with the issuer.';

-- When a person already holds an approved alternative to a strategy card, it
-- can cover that roadmap role. Unowned alternatives are never suggested.
CREATE TABLE revocred.card_substitutions (
    strategy_card_id UUID NOT NULL REFERENCES revocred.catalog_cards(id),
    substitute_card_id UUID NOT NULL REFERENCES revocred.catalog_cards(id),
    rationale TEXT NOT NULL CHECK (length(rationale) BETWEEN 1 AND 400),
    reviewed_by TEXT NOT NULL CHECK (length(reviewed_by) BETWEEN 1 AND 200),
    approved BOOLEAN NOT NULL DEFAULT false,
    PRIMARY KEY (strategy_card_id, substitute_card_id),
    CHECK (strategy_card_id <> substitute_card_id)
);

REVOKE ALL ON revocred.card_reference_index, revocred.card_substitutions FROM PUBLIC;
GRANT SELECT ON revocred.card_reference_index, revocred.card_substitutions TO revocred_runtime;
CREATE UNIQUE INDEX catalog_cards_slug_owner_unique ON revocred.catalog_cards(owner_user_id, slug) WHERE owner_user_id IS NOT NULL;

-- +goose Down
DROP TABLE revocred.card_substitutions;
DROP TABLE revocred.card_reference_index;
ALTER TABLE revocred.catalog_cards DROP COLUMN terms_unknown;
