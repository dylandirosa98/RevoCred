-- +goose Up
-- Re-source the quicksilver row to the base Quicksilver (excellent credit).
-- The prior version pointed at the Good Credit product page, which does not
-- match the base-card strategy roles (S01/S03) or the OpenCard base product.
-- Never rewrite the historical version; publish new evidence as a new version.
-- Scoring inputs are unchanged: $0 fee, 1.5% other, no bonuses or credits.
INSERT INTO revocred.catalog_sources (id, name, url, disclaimer, published_at) VALUES
 ('10000000-0000-4000-8000-000000000005', 'Capital One Quicksilver benefit snapshot 2026-10-26', 'https://www.capitalone.com/credit-cards/quicksilver/', 'Benefits read from the issuer 2026-10-26. Base Quicksilver requires excellent credit; verify current terms and eligibility. Scoring rates retain the prior conservative model. Promotional bonuses are excluded from estimated value.', '2026-10-26T00:00:00Z');

INSERT INTO revocred.card_catalog_versions (
 catalog_card_id, source_id, dataset_version, summary, best_use, annual_fee_cents,
 reward_rates, benefits, transferable_points, travel_scope, minimum_credit_tier,
 rewards_type, first_year_bonus_estimate_cents, annual_benefit_estimate_cents
)
SELECT c.id,
 '10000000-0000-4000-8000-000000000005'::uuid,
 'benefit-display-2026-10-26-v1',
 'Sourced 2026-10-26 from https://www.capitalone.com/credit-cards/quicksilver/ (base Quicksilver; excellent credit)',
 v.best_use, 0,
 '{"other": 1.5}'::jsonb,
 '["$0 annual fee", "1.5% cash back on every purchase", "No foreign transaction fees", "Requires excellent credit; verify eligibility with Capital One", "Promotional cash bonuses may be offered; bonuses are excluded from reward estimates", "Verify current terms with Capital One; conditional bonuses are not included in reward estimates"]'::jsonb,
 false, 'both', 'excellent',
 'cash_back', 0, 0
FROM revocred.catalog_cards c
JOIN LATERAL (SELECT * FROM revocred.card_catalog_versions WHERE catalog_card_id = c.id ORDER BY created_at DESC, id DESC LIMIT 1) v ON true
WHERE c.slug = 'quicksilver' AND c.owner_user_id IS NULL
ON CONFLICT (catalog_card_id, dataset_version) DO NOTHING;

-- +goose Down
DELETE FROM revocred.card_catalog_versions WHERE dataset_version = 'benefit-display-2026-10-26-v1';
DELETE FROM revocred.catalog_sources WHERE id = '10000000-0000-4000-8000-000000000005';
