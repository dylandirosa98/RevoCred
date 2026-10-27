-- +goose Up
-- Identity-only rows for the two current Atmos Rewards consumer cards. Terms
-- remain deliberately empty until the card catalog receives a reviewed data
-- version; selecting either card therefore cannot affect scoring by accident.
INSERT INTO revocred.card_reference_index (
    slug, issuer, name, network, rewards_type, annual_fee_cents, reward_rates,
    terms_status, source_url, source_captured_on, disclaimer
) VALUES
    (
      'bank-of-america-atmos-rewards-ascent-visa-signature',
      'Bank of America', 'Atmos Rewards Ascent Visa Signature', 'Visa',
      'unknown', 0, '{}'::jsonb, 'partial',
      'https://www.bankofamerica.com/credit-cards/products/alaska-airlines-credit-card/',
      '2026-09-30'::date,
      'Card identity only, captured from the issuer public product page on 2026-09-30. This row carries no reward rates or annual fee, so RevoCred cannot score it until you supply your own terms. Verify current terms with Bank of America.'
    ),
    (
      'bank-of-america-atmos-rewards-summit-visa-infinite',
      'Bank of America', 'Atmos Rewards Summit Visa Infinite', 'Visa',
      'unknown', 0, '{}'::jsonb, 'partial',
      'https://www.bankofamerica.com/credit-cards/products/alaska-airlines-infinite-credit-card/',
      '2026-09-30'::date,
      'Card identity only, captured from the issuer public product page on 2026-09-30. This row carries no reward rates or annual fee, so RevoCred cannot score it until you supply your own terms. Verify current terms with Bank of America.'
    )
ON CONFLICT DO NOTHING;

-- +goose Down
DELETE FROM revocred.card_reference_index
WHERE slug IN (
  'bank-of-america-atmos-rewards-ascent-visa-signature',
  'bank-of-america-atmos-rewards-summit-visa-infinite'
);
