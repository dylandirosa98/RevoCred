-- +goose Up
-- Publish new immutable evidence; never rewrite the historical catalog version.
-- Conditional credits remain display-only, not guaranteed annual net rewards.
INSERT INTO revocred.catalog_sources (id, name, url, disclaimer, published_at) VALUES
 ('10000000-0000-4000-8000-000000000003', 'Chase Sapphire Preferred benefit snapshot 2026-10-13', 'https://creditcards.chase.com/rewards-credit-cards/sapphire/preferred', 'Benefits read from the issuer 2026-10-13. Verify current terms; eligibility restrictions apply. Scoring rates retain the prior conservative model. Conditional credits and bonuses are excluded from estimated value.', '2026-10-13T00:00:00Z'),
 ('10000000-0000-4000-8000-000000000004', 'American Express Gold benefit snapshot 2026-10-13', 'https://www.americanexpress.com/us/credit-cards/card/gold-card/', 'Benefits read from the issuer 2026-10-13. Verify current terms; enrollment and eligible purchases required where stated. Scoring rates retain the prior conservative model. Conditional credits and bonuses are excluded from estimated value.', '2026-10-13T00:00:00Z');

INSERT INTO revocred.card_catalog_versions (
 catalog_card_id, source_id, dataset_version, summary, best_use, annual_fee_cents,
 reward_rates, benefits, transferable_points, travel_scope, minimum_credit_tier,
 rewards_type, first_year_bonus_estimate_cents, annual_benefit_estimate_cents
)
SELECT c.id,
 CASE c.slug WHEN 'sapphire-preferred' THEN '10000000-0000-4000-8000-000000000003'::uuid ELSE '10000000-0000-4000-8000-000000000004'::uuid END,
 'benefit-display-2026-10-13-v1', v.summary, v.best_use, v.annual_fee_cents,
 v.reward_rates,
 CASE c.slug WHEN 'sapphire-preferred' THEN
 '["Up to $100 Chase Travel hotel credit each account anniversary year; eligible hotel stays must be purchased through Chase Travel", "Up to $120 Global Entry, TSA PreCheck or NEXUS application-fee credit every four years; charge the eligible fee to the card", "Transfer points to participating airline and hotel partners", "Primary rental-car coverage; exclusions and limits apply", "Trip cancellation, interruption and delay coverage; terms apply", "Verify current terms with Chase; conditional credits are not included in reward estimates"]'::jsonb
 ELSE
 '["4x at restaurants worldwide (up to $50,000 per calendar year, then 1x)", "4x at U.S. supermarkets (up to $25,000 per calendar year, then 1x)", "Up to $100 Resy credit per calendar year: $50 January-June and $50 July-December at qualifying U.S. Resy restaurants; enrollment required", "Up to $84 Dunkin credit per year: $7 monthly at U.S. Dunkin locations; enrollment required", "$120 Uber Cash per year: $10 monthly for U.S. rides and orders; add Gold to your Uber account and use an Amex card to pay", "Up to $120 dining credit per year: $10 monthly at participating partners; enrollment required", "$100 property credit on eligible Hotel Collection stays booked through Amex Travel; two-night minimum and property-specific restrictions", "Transfer points to participating airline and hotel partners", "Verify current terms with American Express; conditional credits are not included in reward estimates"]'::jsonb END,
 v.transferable_points, v.travel_scope, v.minimum_credit_tier, v.rewards_type,
 v.first_year_bonus_estimate_cents, 0
FROM revocred.catalog_cards c
JOIN LATERAL (SELECT * FROM revocred.card_catalog_versions WHERE catalog_card_id = c.id ORDER BY created_at DESC, id DESC LIMIT 1) v ON true
WHERE c.slug IN ('sapphire-preferred', 'amex-gold') AND c.owner_user_id IS NULL
ON CONFLICT (catalog_card_id, dataset_version) DO NOTHING;

-- +goose Down
DELETE FROM revocred.card_catalog_versions WHERE dataset_version = 'benefit-display-2026-10-13-v1';
DELETE FROM revocred.catalog_sources WHERE id IN ('10000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000004');
