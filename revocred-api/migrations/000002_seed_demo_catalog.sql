-- +goose Up
INSERT INTO revocred.catalog_sources (id, name, url, disclaimer, published_at)
VALUES (
    '10000000-0000-4000-8000-000000000001',
    'RevoCred neutral demonstration dataset',
    NULL,
    'Illustrative demo data only. Terms, fees, rewards, eligibility, and benefits are not claimed to be current. Verify all terms directly with the issuer before acting.',
    NULL
);

INSERT INTO revocred.catalog_cards (id, slug, issuer, network, name) VALUES
    ('20000000-0000-4000-8000-000000000001', 'freedom-unlimited-demo', 'Demo Bank A', 'Visa', 'Freedom Unlimited Demo'),
    ('20000000-0000-4000-8000-000000000002', 'savor-demo', 'Demo Bank B', 'Mastercard', 'Savor Demo'),
    ('20000000-0000-4000-8000-000000000003', 'travel-starter-demo', 'Demo Bank A', 'Visa', 'Travel Starter Demo'),
    ('20000000-0000-4000-8000-000000000004', 'venture-demo', 'Demo Bank B', 'Visa', 'Venture Demo'),
    ('20000000-0000-4000-8000-000000000005', 'strata-demo', 'Demo Bank C', 'Mastercard', 'Strata Demo'),
    ('20000000-0000-4000-8000-000000000006', 'bilt-demo', 'Demo Bank D', 'Mastercard', 'Rent Rewards Demo');

INSERT INTO revocred.card_catalog_versions (
    catalog_card_id, source_id, dataset_version, summary, best_use, annual_fee_cents,
    reward_rates, benefits, transferable_points, travel_scope, minimum_credit_tier,
    rewards_type, first_year_bonus_estimate_cents, annual_benefit_estimate_cents
) VALUES
    (
        '20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'demo-2026-01',
        'Illustrative no-fee everyday card.', 'Everyday catch-all', 0,
        '{"dining": 3, "drugstores": 3, "other": 1.5}', '["Illustrative purchase protection", "No modeled annual fee"]',
        false, 'both', 'good', 'cash_back', 15000, 0
    ),
    (
        '20000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000001', 'demo-2026-01',
        'Illustrative dining and entertainment card.', 'Dining and entertainment', 0,
        '{"dining": 3, "entertainment": 3, "groceries": 3, "streaming": 3, "other": 1}', '["Illustrative entertainment access", "No modeled annual fee"]',
        false, 'both', 'good', 'cash_back', 10000, 0
    ),
    (
        '20000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000001', 'demo-2026-01',
        'Illustrative mid-fee transferable travel card.', 'Travel starter', 9500,
        '{"travel": 2, "dining": 3, "groceries": 3, "streaming": 3, "other": 1}', '["Illustrative transfer partners", "Illustrative trip protections"]',
        true, 'both', 'good', 'travel', 50000, 5000
    ),
    (
        '20000000-0000-4000-8000-000000000004', '10000000-0000-4000-8000-000000000001', 'demo-2026-01',
        'Illustrative premium travel catch-all card.', 'Travel and catch-all spend', 39500,
        '{"travel": 5, "other": 2}', '["Illustrative travel credit", "Illustrative lounge access"]',
        true, 'both', 'excellent', 'travel', 75000, 30000
    ),
    (
        '20000000-0000-4000-8000-000000000005', '10000000-0000-4000-8000-000000000001', 'demo-2026-01',
        'Illustrative everyday rewards card.', 'Grocery, dining, and gas', 0,
        '{"groceries": 3, "dining": 3, "gas": 3, "transit": 3, "other": 1}', '["Illustrative entertainment access", "No modeled annual fee"]',
        false, 'both', 'good', 'hybrid', 12000, 0
    ),
    (
        '20000000-0000-4000-8000-000000000006', '10000000-0000-4000-8000-000000000001', 'demo-2026-01',
        'Illustrative rent-focused rewards card.', 'Rent and dining', 0,
        '{"rent": 1, "dining": 3, "travel": 2, "other": 1}', '["Illustrative rent rewards", "Illustrative transfer partners"]',
        true, 'both', 'good', 'travel', 0, 0
    );

-- +goose Down
DELETE FROM revocred.catalog_cards WHERE id IN (
    '20000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000002',
    '20000000-0000-4000-8000-000000000003',
    '20000000-0000-4000-8000-000000000004',
    '20000000-0000-4000-8000-000000000005',
    '20000000-0000-4000-8000-000000000006'
);
DELETE FROM revocred.catalog_sources WHERE id = '10000000-0000-4000-8000-000000000001';
