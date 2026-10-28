-- +goose Up
-- Add the Discover it Cash Back row and bind it to the OpenCard base product.
-- Scoring uses the conservative standing rates: 1% base; the rotating 5%
-- quarterly categories require activation and are display-only, not modeled.
-- The first-year Cashback Match is a welcome bonus and excluded from estimates.
INSERT INTO revocred.catalog_sources (id, name, url, disclaimer, published_at) VALUES
 ('10000000-0000-4000-8000-000000000006', 'Discover it Cash Back snapshot 2026-10-28', 'https://www.discover.com/credit-cards/cash-back/it-card.html', 'Terms from Discover product page via OpenCard DB snapshot verified 2026-07-25. Verify current terms and eligibility; quarterly categories require activation. Scoring rates retain the prior conservative model. Welcome bonuses are excluded from estimated value.', '2026-10-28T00:00:00Z');

INSERT INTO revocred.catalog_cards (id, slug, issuer, network, name, data_kind) VALUES
 ('20000000-0000-4000-8000-000000000021', 'discover-it-cash-back', 'Discover', 'Discover', 'Discover it Cash Back', 'issuer_snapshot')
ON CONFLICT (id) DO NOTHING;

INSERT INTO revocred.card_catalog_versions (
 catalog_card_id, source_id, dataset_version, summary, best_use, annual_fee_cents,
 reward_rates, benefits, transferable_points, travel_scope, minimum_credit_tier,
 rewards_type, first_year_bonus_estimate_cents, annual_benefit_estimate_cents
) VALUES (
 '20000000-0000-4000-8000-000000000021',
 '10000000-0000-4000-8000-000000000006',
 'sourced-2026-10-28-v1',
 'Sourced 2026-10-28 from https://www.discover.com/credit-cards/cash-back/it-card.html via OpenCard snapshot verified 2026-07-25',
 'Rotating quarterly categories and 1% base',
 0,
 '{"other": 1}'::jsonb,
 '["$0 annual fee", "1% cash back on all other purchases", "5% in rotating quarterly categories up to $1,500 per quarter; activation required", "Unlimited Cashback Match doubles first-year cash back; welcome bonuses are excluded from reward estimates", "No foreign transaction fee", "Good credit typically required; verify eligibility with Discover", "Verify current terms with Discover"]'::jsonb,
 false, 'none', 'good',
 'cash_back', 0, 0
);

-- +goose Down
DELETE FROM revocred.card_catalog_versions WHERE catalog_card_id = '20000000-0000-4000-8000-000000000021';
DELETE FROM revocred.catalog_cards WHERE id = '20000000-0000-4000-8000-000000000021';
DELETE FROM revocred.catalog_sources WHERE id = '10000000-0000-4000-8000-000000000006';
