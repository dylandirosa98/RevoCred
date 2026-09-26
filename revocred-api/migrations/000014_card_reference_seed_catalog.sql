-- +goose Up
-- Index rows for the vetted catalog. Terms are copied from the current catalog
-- snapshot rather than retyped, and picking one of these resolves to the real
-- catalog card, so the cardholder never re-enters terms we already model.
INSERT INTO revocred.card_reference_index (
    slug, issuer, name, network, rewards_type, annual_fee_cents, reward_rates,
    terms_status, source_url, source_captured_on, disclaimer)
SELECT c.slug || '-index', c.issuer, c.name, c.network,
       -- The catalog labels transferable travel rewards "travel"; the index
       -- keeps a small honest vocabulary and calls it points.
       CASE WHEN v.rewards_type = 'travel' THEN 'points' ELSE v.rewards_type END,
       v.annual_fee_cents,
       v.reward_rates, 'verified',
       COALESCE(NULLIF(s.url, ''), 'https://www.issuer.example.invalid'),
       COALESCE(s.published_at::date, CURRENT_DATE),
       s.disclaimer
FROM revocred.catalog_cards c
JOIN LATERAL (SELECT * FROM revocred.card_catalog_versions WHERE catalog_card_id = c.id
              ORDER BY created_at DESC, id DESC LIMIT 1) v ON true
LEFT JOIN revocred.catalog_sources s ON s.id = v.source_id
WHERE c.is_active AND c.owner_user_id IS NULL AND c.data_kind = 'issuer_snapshot'
ON CONFLICT DO NOTHING;

-- +goose Down
DELETE FROM revocred.card_reference_index WHERE terms_status = 'verified';
