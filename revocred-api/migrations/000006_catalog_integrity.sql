-- +goose Up
-- Forward-only repair: earlier deployed migrations are deliberately preserved.
ALTER TABLE revocred.catalog_cards ADD COLUMN data_kind TEXT NOT NULL DEFAULT 'demo'
    CHECK (data_kind IN ('demo', 'issuer_snapshot', 'user_supplied'));
UPDATE revocred.catalog_cards SET data_kind = 'user_supplied' WHERE owner_user_id IS NOT NULL;
UPDATE revocred.catalog_cards SET data_kind = 'issuer_snapshot'
WHERE owner_user_id IS NULL AND id BETWEEN '20000000-0000-4000-8000-000000000007' AND '20000000-0000-4000-8000-000000000020';
UPDATE revocred.catalog_cards SET is_active = false WHERE data_kind = 'demo';
UPDATE revocred.wallet_cards w SET status='inactive'
FROM revocred.catalog_cards c WHERE w.catalog_card_id=c.id AND c.data_kind='demo';

-- Separate sources before repairing the shared demo source. These are snapshots,
-- not a claim that offers have been independently reviewed or remain current.
INSERT INTO revocred.catalog_sources (id, name, url, disclaimer, published_at)
SELECT c.id, c.issuer || ' product snapshot',
       substring(v.summary from '(https://[^ ]+)'),
       'Issuer snapshot captured 2026-09-23; independently review before public launch. Conservative model: one cent per point; no bonuses, statement credits, portal multipliers, capped-category uplift, or housing rewards. Verify current issuer terms.',
       '2026-09-23T00:00:00Z'
FROM revocred.catalog_cards c
JOIN LATERAL (SELECT * FROM revocred.card_catalog_versions WHERE catalog_card_id = c.id ORDER BY created_at DESC, id DESC LIMIT 1) v ON true
WHERE c.data_kind = 'issuer_snapshot';

INSERT INTO revocred.card_catalog_versions (
    catalog_card_id, source_id, dataset_version, summary, best_use, annual_fee_cents,
    reward_rates, benefits, transferable_points, travel_scope, minimum_credit_tier,
    rewards_type, first_year_bonus_estimate_cents, annual_benefit_estimate_cents)
SELECT c.id, c.id, 'conservative-2026-09-23-v1', v.summary, v.best_use, v.annual_fee_cents,
       CASE c.slug
         WHEN 'freedom-unlimited' THEN '{"dining":3,"drugstores":3,"other":1.5}'::jsonb
         WHEN 'freedom-flex' THEN '{"dining":3,"drugstores":3,"other":1}'::jsonb
         WHEN 'sapphire-preferred' THEN '{"dining":3,"travel":2,"other":1}'::jsonb
         WHEN 'sapphire-reserve' THEN '{"dining":3,"flights":4,"hotels":4,"other":1}'::jsonb
         WHEN 'venture-x' THEN '{"other":2}'::jsonb
         WHEN 'amex-gold' THEN '{"flights":3,"other":1}'::jsonb
         WHEN 'amex-platinum' THEN '{"other":1}'::jsonb
         WHEN 'strata-elite' THEN '{"dining":3,"other":1.5}'::jsonb
         ELSE v.reward_rates END,
       v.benefits, v.transferable_points, 'both', v.minimum_credit_tier,
       v.rewards_type, 0, 0
FROM revocred.catalog_cards c
JOIN LATERAL (SELECT * FROM revocred.card_catalog_versions WHERE catalog_card_id = c.id ORDER BY created_at DESC, id DESC LIMIT 1) v ON true
WHERE c.data_kind = 'issuer_snapshot';

UPDATE revocred.catalog_sources SET name = 'RevoCred unverified legacy demonstration dataset', url = NULL,
    disclaimer = 'Unverified legacy demo data. Excluded from new recommendations. Earlier migrations modified these rows; historical terms before this repair cannot be reconstructed.'
WHERE id = '10000000-0000-4000-8000-000000000001';

ALTER TABLE revocred.recommendation_runs ADD COLUMN catalog_snapshot JSONB NOT NULL DEFAULT '[]';

-- Custom names are unique within an account, not across all accounts.
ALTER TABLE revocred.catalog_cards DROP CONSTRAINT catalog_cards_slug_key;
CREATE UNIQUE INDEX catalog_public_slug_key ON revocred.catalog_cards(slug) WHERE owner_user_id IS NULL;
CREATE UNIQUE INDEX catalog_owner_slug_key ON revocred.catalog_cards(owner_user_id, slug) WHERE owner_user_id IS NOT NULL;

-- Repair any cross-account references before enforcing ownership in the database.
DELETE FROM revocred.wallet_cards w USING revocred.catalog_cards c
WHERE w.catalog_card_id = c.id AND c.owner_user_id IS NOT NULL AND c.owner_user_id <> w.user_id;

-- +goose StatementBegin
CREATE FUNCTION revocred.check_wallet_owner() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM revocred.catalog_cards WHERE id = NEW.catalog_card_id
        AND is_active AND (owner_user_id IS NULL OR owner_user_id = NEW.user_id)) THEN
        RAISE EXCEPTION 'card is unavailable' USING ERRCODE = '23503';
    END IF;
    RETURN NEW;
END;
$$;
-- +goose StatementEnd
CREATE TRIGGER wallet_owner BEFORE INSERT OR UPDATE OF catalog_card_id, user_id ON revocred.wallet_cards
FOR EACH ROW EXECUTE FUNCTION revocred.check_wallet_owner();

-- +goose StatementBegin
CREATE FUNCTION revocred.reject_catalog_update() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'catalog versions and sources are immutable; insert a new version';
END;
$$;
-- +goose StatementEnd
CREATE TRIGGER immutable_catalog_version BEFORE UPDATE ON revocred.card_catalog_versions
FOR EACH ROW EXECUTE FUNCTION revocred.reject_catalog_update();
CREATE TRIGGER immutable_catalog_source BEFORE UPDATE ON revocred.catalog_sources
FOR EACH ROW EXECUTE FUNCTION revocred.reject_catalog_update();

-- Supabase's browser roles must not access this server-owned schema directly.
REVOKE ALL ON SCHEMA revocred FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA revocred FROM PUBLIC;

-- +goose Down
-- +goose StatementBegin
DO $$ BEGIN RAISE EXCEPTION 'Catalog integrity repair is forward-only; restore a tested backup or deploy a corrective migration'; END $$;
-- +goose StatementEnd
