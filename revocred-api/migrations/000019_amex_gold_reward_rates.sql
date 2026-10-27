-- +goose Up
-- The conservative snapshot introduced in 000006 accidentally hid the Gold
-- Card's defining restaurant and U.S. supermarket rates from wallet details.
-- Catalog versions are immutable, so publish a corrected version rather than
-- changing historical evidence in place. Category caps and current terms
-- remain disclosed in the copied benefits/source disclaimer.
INSERT INTO revocred.card_catalog_versions (
    catalog_card_id, source_id, dataset_version, summary, best_use,
    annual_fee_cents, reward_rates, benefits, transferable_points,
    travel_scope, minimum_credit_tier, rewards_type,
    first_year_bonus_estimate_cents, annual_benefit_estimate_cents
)
SELECT v.catalog_card_id, v.source_id, 'issuer-fix-2026-09-30-v1', v.summary,
       v.best_use, v.annual_fee_cents,
       '{"dining":4,"groceries":4,"flights":3,"other":1}'::jsonb,
       v.benefits, v.transferable_points, v.travel_scope,
       v.minimum_credit_tier, v.rewards_type,
       v.first_year_bonus_estimate_cents, v.annual_benefit_estimate_cents
FROM revocred.catalog_cards c
JOIN LATERAL (
    SELECT * FROM revocred.card_catalog_versions
    WHERE catalog_card_id = c.id
    ORDER BY created_at DESC, id DESC
    LIMIT 1
) v ON true
WHERE c.slug = 'amex-gold'
ON CONFLICT (catalog_card_id, dataset_version) DO NOTHING;

-- +goose Down
DELETE FROM revocred.card_catalog_versions
WHERE dataset_version = 'issuer-fix-2026-09-30-v1';
