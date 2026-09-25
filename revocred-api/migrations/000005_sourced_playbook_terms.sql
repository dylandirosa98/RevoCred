-- +goose Up
UPDATE revocred.catalog_sources
SET name = 'Issuer public product pages captured 2026-09-23',
    url = 'https://creditcards.chase.com',
    disclaimer = 'Rates, fees, and benefits were copied from public issuer product pages on 2026-09-23. They are not guaranteed, can change, and may differ by offer. Verify current terms with the issuer before applying or spending. Educational use only. Welcome bonuses are omitted from scoring.'
WHERE id = '10000000-0000-4000-8000-000000000001';

-- Freedom Unlimited
UPDATE revocred.card_catalog_versions SET
  summary = 'Sourced 2026-09-23 from https://creditcards.chase.com/cash-back-credit-cards/freedom/unlimited',
  best_use = 'Everyday catch-all cash back',
  annual_fee_cents = 0,
  reward_rates = '{"dining": 3, "travel": 5, "other": 1.5}',
  benefits = '["$0 annual fee", "1.5% on all other purchases", "3% dining and drugstores", "5% Chase Travel", "Verify current terms with Chase"]',
  transferable_points = false,
  travel_scope = 'both',
  minimum_credit_tier = 'good',
  rewards_type = 'cash_back',
  first_year_bonus_estimate_cents = 20000,
  annual_benefit_estimate_cents = 0
WHERE catalog_card_id = '20000000-0000-4000-8000-000000000011';

-- Freedom Flex
UPDATE revocred.card_catalog_versions SET
  summary = 'Sourced 2026-09-23 from https://creditcards.chase.com/cash-back-credit-cards/freedom/flex',
  best_use = 'Rotating quarterly cash back plus dining',
  annual_fee_cents = 0,
  reward_rates = '{"dining": 3, "travel": 5, "other": 1}',
  benefits = '["$0 annual fee", "5% rotating categories up to $1,500/quarter when activated", "3% dining and drugstores", "5% Chase Travel", "1% everything else", "Verify current terms with Chase"]',
  transferable_points = false,
  travel_scope = 'both',
  minimum_credit_tier = 'good',
  rewards_type = 'cash_back',
  first_year_bonus_estimate_cents = 25000,
  annual_benefit_estimate_cents = 0
WHERE catalog_card_id = '20000000-0000-4000-8000-000000000010';

-- Freedom Rise
UPDATE revocred.card_catalog_versions SET
  summary = 'Sourced 2026-09-23 from https://creditcards.chase.com/cash-back-credit-cards/freedom/rise',
  best_use = 'Build credit with flat cash back',
  annual_fee_cents = 0,
  reward_rates = '{"other": 1.5}',
  benefits = '["$0 annual fee", "1.5% cash back on all purchases", "Verify current terms with Chase"]',
  transferable_points = false,
  travel_scope = 'both',
  minimum_credit_tier = 'building',
  rewards_type = 'cash_back'
WHERE catalog_card_id = '20000000-0000-4000-8000-000000000009';

-- Sapphire Preferred
UPDATE revocred.card_catalog_versions SET
  summary = 'Sourced 2026-09-23 from https://creditcards.chase.com/rewards-credit-cards/sapphire and Chase 2026 preferred update',
  best_use = 'Transferable travel points starter',
  annual_fee_cents = 9500,
  reward_rates = '{"dining": 3, "travel": 2, "groceries": 3, "gas": 3, "other": 1}',
  benefits = '["$95 annual fee", "5x Chase Travel", "3x dining, online grocery, gas/EV", "2x other travel", "Transferable Ultimate Rewards", "Verify current terms with Chase"]',
  transferable_points = true,
  travel_scope = 'both',
  minimum_credit_tier = 'good',
  rewards_type = 'travel',
  first_year_bonus_estimate_cents = 0,
  annual_benefit_estimate_cents = 10000
WHERE catalog_card_id = '20000000-0000-4000-8000-000000000012';

-- Sapphire Reserve
UPDATE revocred.card_catalog_versions SET
  summary = 'Sourced 2026-09-23 from https://creditcards.chase.com/rewards-credit-cards/sapphire/reserve',
  best_use = 'Premium Chase travel hub',
  annual_fee_cents = 79500,
  reward_rates = '{"travel": 4, "flights": 4, "hotels": 4, "dining": 3, "other": 1}',
  benefits = '["$795 annual fee", "8x Chase Travel", "4x flights and hotels booked direct", "3x dining", "$300 annual travel credit", "Verify current terms with Chase"]',
  transferable_points = true,
  travel_scope = 'both',
  minimum_credit_tier = 'excellent',
  rewards_type = 'travel',
  annual_benefit_estimate_cents = 30000
WHERE catalog_card_id = '20000000-0000-4000-8000-000000000013';

-- Quicksilver
UPDATE revocred.card_catalog_versions SET
  summary = 'Sourced 2026-09-23 from https://www.capitalone.com/credit-cards/quicksilver-good-credit/',
  best_use = 'Flat 1.5% cash back catch-all',
  annual_fee_cents = 0,
  reward_rates = '{"other": 1.5}',
  benefits = '["$0 annual fee on this product page", "1.5% cash back on every purchase", "No foreign transaction fees", "Verify current terms with Capital One"]',
  transferable_points = false,
  travel_scope = 'both',
  minimum_credit_tier = 'good',
  rewards_type = 'cash_back'
WHERE catalog_card_id = '20000000-0000-4000-8000-000000000008';

-- Savor for Students
UPDATE revocred.card_catalog_versions SET
  summary = 'Sourced 2026-09-23 from https://www.capitalone.com/credit-cards/savor-student/',
  best_use = 'Student dining and grocery cash back',
  annual_fee_cents = 0,
  reward_rates = '{"dining": 3, "groceries": 3, "entertainment": 3, "other": 1}',
  benefits = '["$0 annual fee", "3% groceries, dining, entertainment, streaming", "1% everything else", "Verify current terms with Capital One"]',
  transferable_points = false,
  travel_scope = 'both',
  minimum_credit_tier = 'building',
  rewards_type = 'cash_back'
WHERE catalog_card_id = '20000000-0000-4000-8000-000000000007';

-- SavorOne
UPDATE revocred.card_catalog_versions SET
  summary = 'Sourced 2026-09-23 from https://www.capitalone.com/credit-cards/savorone/',
  best_use = 'Dining and grocery cash back',
  annual_fee_cents = 3900,
  reward_rates = '{"dining": 3, "groceries": 3, "entertainment": 3, "other": 1}',
  benefits = '["$39 annual fee on the SavorOne product page", "3% groceries, dining, entertainment, streaming", "1% everything else", "Capital One also offers $0 Savor variants; verify which product applies"]',
  transferable_points = false,
  travel_scope = 'both',
  minimum_credit_tier = 'fair',
  rewards_type = 'cash_back'
WHERE catalog_card_id = '20000000-0000-4000-8000-000000000014';

-- Venture X
UPDATE revocred.card_catalog_versions SET
  summary = 'Sourced 2026-09-23 from https://www.capitalone.com/credit-cards/venture-x/',
  best_use = 'Premium transferable travel miles',
  annual_fee_cents = 39500,
  reward_rates = '{"hotels": 10, "flights": 5, "travel": 5, "other": 2}',
  benefits = '["$395 annual fee", "2x miles on all purchases", "10x hotels and rental cars via Capital One Travel", "5x flights via Capital One Travel", "$300 annual Capital One Travel credit", "10,000 anniversary miles", "Verify current terms with Capital One"]',
  transferable_points = true,
  travel_scope = 'international',
  minimum_credit_tier = 'excellent',
  rewards_type = 'travel',
  annual_benefit_estimate_cents = 40000
WHERE catalog_card_id = '20000000-0000-4000-8000-000000000015';

-- Amex Gold
UPDATE revocred.card_catalog_versions SET
  summary = 'Sourced 2026-09-23 from https://www.americanexpress.com/en-us/credit-cards/credit-intel/gold-card-annual-fee/',
  best_use = 'Dining and U.S. supermarket points',
  annual_fee_cents = 32500,
  reward_rates = '{"dining": 4, "groceries": 4, "flights": 3, "hotels": 5, "other": 1}',
  benefits = '["$325 annual fee", "4x restaurants worldwide (cap applies)", "4x U.S. supermarkets (cap applies)", "3x flights via Amex Travel or airlines", "5x prepaid hotels via Amex Travel", "Dining credits require enrollment", "Verify current terms with American Express"]',
  transferable_points = true,
  travel_scope = 'international',
  minimum_credit_tier = 'good',
  rewards_type = 'travel',
  annual_benefit_estimate_cents = 24000
WHERE catalog_card_id = '20000000-0000-4000-8000-000000000016';

-- Platinum
UPDATE revocred.card_catalog_versions SET
  summary = 'Sourced 2026-09-23 from https://www.americanexpress.com/us/credit-cards/category/reward-points/',
  best_use = 'Premium travel credits and lounge access',
  annual_fee_cents = 89500,
  reward_rates = '{"flights": 5, "hotels": 5, "other": 1}',
  benefits = '["$895 annual fee", "5x prepaid hotels and flights via Amex Travel (caps apply)", "Lounge access", "Multiple statement credits; enrollment often required", "Verify current terms with American Express"]',
  transferable_points = true,
  travel_scope = 'international',
  minimum_credit_tier = 'excellent',
  rewards_type = 'travel',
  annual_benefit_estimate_cents = 60000
WHERE catalog_card_id = '20000000-0000-4000-8000-000000000017';

-- Double Cash
UPDATE revocred.card_catalog_versions SET
  summary = 'Sourced 2026-09-23 from https://www.citi.com/credit-cards/rewards-credit-cards',
  best_use = 'Flat 2% cash back',
  annual_fee_cents = 0,
  reward_rates = '{"other": 2}',
  benefits = '["No annual fee", "Unlimited 2% cash back: 1% when you buy, 1% as you pay", "Verify current terms with Citi"]',
  transferable_points = false,
  travel_scope = 'none',
  minimum_credit_tier = 'good',
  rewards_type = 'cash_back'
WHERE catalog_card_id = '20000000-0000-4000-8000-000000000018';

-- Strata
UPDATE revocred.card_catalog_versions SET
  summary = 'Sourced 2026-09-23 from https://www.citi.com/credit-cards/citi-strata-all-cards',
  best_use = 'No-fee everyday ThankYou points',
  annual_fee_cents = 0,
  reward_rates = '{"groceries": 3, "gas": 3, "dining": 2, "other": 1}',
  benefits = '["$0 annual fee", "3x supermarkets, gas/EV, transit, and one self-select category", "2x restaurants", "1x everything else", "Verify current terms with Citi"]',
  transferable_points = true,
  travel_scope = 'domestic',
  minimum_credit_tier = 'good',
  rewards_type = 'hybrid'
WHERE catalog_card_id = '20000000-0000-4000-8000-000000000019';

-- Strata Elite
UPDATE revocred.card_catalog_versions SET
  summary = 'Sourced 2026-09-23 from https://www.citi.com/credit-cards/citi-strata-elite-credit-card',
  best_use = 'Premium Citi travel',
  annual_fee_cents = 59500,
  reward_rates = '{"hotels": 12, "flights": 6, "dining": 3, "other": 1.5}',
  benefits = '["$595 annual fee", "12x hotels/cars/attractions via Citi Travel", "6x air via Citi Travel", "3x restaurants", "1.5x everything else", "Hotel and lounge benefits", "Verify current terms with Citi"]',
  transferable_points = true,
  travel_scope = 'domestic',
  minimum_credit_tier = 'excellent',
  rewards_type = 'travel',
  annual_benefit_estimate_cents = 30000
WHERE catalog_card_id = '20000000-0000-4000-8000-000000000020';

-- +goose Down
SELECT 1;
