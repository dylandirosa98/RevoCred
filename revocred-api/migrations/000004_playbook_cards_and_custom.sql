-- +goose Up
ALTER TABLE revocred.catalog_cards
    ADD COLUMN owner_user_id UUID REFERENCES auth.users (id) ON DELETE CASCADE;

CREATE INDEX catalog_cards_owner_idx ON revocred.catalog_cards (owner_user_id);

INSERT INTO revocred.catalog_sources (id, name, url, disclaimer, published_at)
VALUES (
    '10000000-0000-4000-8000-000000000002',
    'User-supplied card terms',
    NULL,
    'Entered by the user. Not verified against issuer documents. Educational use only.',
    NULL
);

INSERT INTO revocred.catalog_cards (id, slug, issuer, network, name) VALUES
    ('20000000-0000-4000-8000-000000000007', 'savor-for-students', 'Capital One', 'Mastercard', 'Savor for Students'),
    ('20000000-0000-4000-8000-000000000008', 'quicksilver', 'Capital One', 'Visa', 'Quicksilver'),
    ('20000000-0000-4000-8000-000000000009', 'freedom-rise', 'Chase', 'Visa', 'Freedom Rise'),
    ('20000000-0000-4000-8000-000000000010', 'freedom-flex', 'Chase', 'Mastercard', 'Freedom Flex'),
    ('20000000-0000-4000-8000-000000000011', 'freedom-unlimited', 'Chase', 'Visa', 'Freedom Unlimited'),
    ('20000000-0000-4000-8000-000000000012', 'sapphire-preferred', 'Chase', 'Visa', 'Sapphire Preferred'),
    ('20000000-0000-4000-8000-000000000013', 'sapphire-reserve', 'Chase', 'Visa', 'Sapphire Reserve'),
    ('20000000-0000-4000-8000-000000000014', 'savorone', 'Capital One', 'Mastercard', 'SavorOne'),
    ('20000000-0000-4000-8000-000000000015', 'venture-x', 'Capital One', 'Visa', 'Venture X'),
    ('20000000-0000-4000-8000-000000000016', 'amex-gold', 'American Express', 'Amex', 'Amex Gold'),
    ('20000000-0000-4000-8000-000000000017', 'amex-platinum', 'American Express', 'Amex', 'Platinum'),
    ('20000000-0000-4000-8000-000000000018', 'double-cash', 'Citi', 'Mastercard', 'Double Cash'),
    ('20000000-0000-4000-8000-000000000019', 'strata', 'Citi', 'Mastercard', 'Strata'),
    ('20000000-0000-4000-8000-000000000020', 'strata-elite', 'Citi', 'Mastercard', 'Strata Elite');

INSERT INTO revocred.card_catalog_versions (
    catalog_card_id, source_id, dataset_version, summary, best_use, annual_fee_cents,
    reward_rates, benefits, transferable_points, travel_scope, minimum_credit_tier,
    rewards_type, first_year_bonus_estimate_cents, annual_benefit_estimate_cents
) VALUES
    ('20000000-0000-4000-8000-000000000007', '10000000-0000-4000-8000-000000000001', 'playbook-demo-2026-01',
     'Unverified demo terms for S01 student cash back.', 'Dining and groceries', 0,
     '{"dining": 3, "groceries": 3, "entertainment": 3, "other": 1}',
     '["Unverified demo data", "No annual fee in this model"]', false, 'none', 'building', 'cash_back', 0, 0),
    ('20000000-0000-4000-8000-000000000008', '10000000-0000-4000-8000-000000000001', 'playbook-demo-2026-01',
     'Unverified demo terms for Capital One catch-all cash back.', 'Everyday catch-all', 0,
     '{"other": 1.5}',
     '["Unverified demo data", "Flat cash back"]', false, 'none', 'building', 'cash_back', 0, 0),
    ('20000000-0000-4000-8000-000000000009', '10000000-0000-4000-8000-000000000001', 'playbook-demo-2026-01',
     'Unverified demo terms for Chase starter card.', 'Build Chase history', 0,
     '{"other": 1.5}',
     '["Unverified demo data"]', false, 'both', 'building', 'cash_back', 0, 0),
    ('20000000-0000-4000-8000-000000000010', '10000000-0000-4000-8000-000000000001', 'playbook-demo-2026-01',
     'Unverified demo terms for Chase rotating/category card.', 'Dining and rotating categories', 0,
     '{"dining": 3, "other": 1}',
     '["Unverified demo data"]', false, 'both', 'fair', 'cash_back', 0, 0),
    ('20000000-0000-4000-8000-000000000011', '10000000-0000-4000-8000-000000000001', 'playbook-demo-2026-01',
     'Unverified demo terms for Chase everyday catch-all.', 'Everyday catch-all', 0,
     '{"dining": 3, "other": 1.5}',
     '["Unverified demo data"]', false, 'both', 'fair', 'cash_back', 0, 0),
    ('20000000-0000-4000-8000-000000000012', '10000000-0000-4000-8000-000000000001', 'playbook-demo-2026-01',
     'Unverified demo terms for Chase travel starter.', 'Travel and dining', 9500,
     '{"dining": 3, "travel": 2, "other": 1}',
     '["Unverified demo data", "Transfer partners in this model"]', true, 'both', 'good', 'travel', 0, 5000),
    ('20000000-0000-4000-8000-000000000013', '10000000-0000-4000-8000-000000000001', 'playbook-demo-2026-01',
     'Unverified demo terms for Chase premium travel.', 'Premium travel', 55000,
     '{"dining": 3, "travel": 3, "flights": 5, "hotels": 5, "other": 1}',
     '["Unverified demo data", "Premium benefits in this model"]', true, 'both', 'excellent', 'travel', 0, 30000),
    ('20000000-0000-4000-8000-000000000014', '10000000-0000-4000-8000-000000000001', 'playbook-demo-2026-01',
     'Unverified demo terms for Capital One dining cash back.', 'Dining and groceries', 0,
     '{"dining": 3, "groceries": 3, "other": 1}',
     '["Unverified demo data"]', false, 'none', 'fair', 'cash_back', 0, 0),
    ('20000000-0000-4000-8000-000000000015', '10000000-0000-4000-8000-000000000001', 'playbook-demo-2026-01',
     'Unverified demo terms for Capital One premium travel.', 'Travel catch-all', 39500,
     '{"travel": 2, "flights": 5, "hotels": 10, "other": 2}',
     '["Unverified demo data", "Premium travel credits in this model"]', true, 'international', 'good', 'travel', 0, 30000),
    ('20000000-0000-4000-8000-000000000016', '10000000-0000-4000-8000-000000000001', 'playbook-demo-2026-01',
     'Unverified demo terms for Amex dining/grocery card.', 'Dining and groceries', 32500,
     '{"dining": 4, "groceries": 4, "flights": 3, "other": 1}',
     '["Unverified demo data", "Transfer partners in this model"]', true, 'international', 'good', 'travel', 0, 10000),
    ('20000000-0000-4000-8000-000000000017', '10000000-0000-4000-8000-000000000001', 'playbook-demo-2026-01',
     'Unverified demo terms for Amex premium travel.', 'Flights and hotels', 69500,
     '{"flights": 5, "hotels": 5, "travel": 5, "other": 1}',
     '["Unverified demo data", "Premium benefits in this model"]', true, 'international', 'excellent', 'travel', 0, 40000),
    ('20000000-0000-4000-8000-000000000018', '10000000-0000-4000-8000-000000000001', 'playbook-demo-2026-01',
     'Unverified demo terms for Citi flat cash back.', 'Everyday catch-all', 0,
     '{"other": 2}',
     '["Unverified demo data"]', false, 'none', 'good', 'cash_back', 0, 0),
    ('20000000-0000-4000-8000-000000000019', '10000000-0000-4000-8000-000000000001', 'playbook-demo-2026-01',
     'Unverified demo terms for Citi category cash back.', 'Groceries and gas', 0,
     '{"groceries": 3, "gas": 3, "dining": 3, "other": 1}',
     '["Unverified demo data"]', false, 'domestic', 'good', 'hybrid', 0, 0),
    ('20000000-0000-4000-8000-000000000020', '10000000-0000-4000-8000-000000000001', 'playbook-demo-2026-01',
     'Unverified demo terms for Citi premium travel.', 'Domestic premium travel', 59500,
     '{"travel": 3, "hotels": 5, "other": 1}',
     '["Unverified demo data", "Premium benefits in this model"]', true, 'domestic', 'excellent', 'travel', 0, 25000);

-- +goose Down
DELETE FROM revocred.catalog_cards WHERE id IN (
    '20000000-0000-4000-8000-000000000007',
    '20000000-0000-4000-8000-000000000008',
    '20000000-0000-4000-8000-000000000009',
    '20000000-0000-4000-8000-000000000010',
    '20000000-0000-4000-8000-000000000011',
    '20000000-0000-4000-8000-000000000012',
    '20000000-0000-4000-8000-000000000013',
    '20000000-0000-4000-8000-000000000014',
    '20000000-0000-4000-8000-000000000015',
    '20000000-0000-4000-8000-000000000016',
    '20000000-0000-4000-8000-000000000017',
    '20000000-0000-4000-8000-000000000018',
    '20000000-0000-4000-8000-000000000019',
    '20000000-0000-4000-8000-000000000020'
);
DELETE FROM revocred.catalog_sources WHERE id = '10000000-0000-4000-8000-000000000002';
DROP INDEX IF EXISTS revocred.catalog_cards_owner_idx;
ALTER TABLE revocred.catalog_cards DROP COLUMN IF EXISTS owner_user_id;
