-- +goose Up
-- Forward-only catalog terms audit update (2026-11-23).
-- Independently verified all 14 active recommendable issuer_snapshot cards
-- against live official issuer product pages on 2026-11-23T07:24Z.
-- See docs/card-data-audit-2026-11-23/README.md for evidence hashes, quotes,
-- and remaining manual-verification caveats.
--
-- Rules preserved:
-- - Historical migrations, catalog_sources, and card_catalog_versions are
--   never edited in place.
-- - Exact 14 recommendable strategy cards retained (no new candidates added).
-- - Conservative scoring model preserved: 1 cent/point; portal-only uplift,
--   welcome bonuses, and conditional credits remain excluded from rankings
--   (first_year_bonus_estimate_cents = 0, annual_benefit_estimate_cents = 0).
-- - Official application links in revocred.affiliate_offers are intentionally
--   untouched here so operators explicitly review and republish offers against
--   these new catalog version IDs before the 2026-12-25 expiry.

INSERT INTO revocred.catalog_sources (id, name, url, disclaimer, published_at) VALUES
(
    '10000000-0000-4000-8000-000000000007',
    'American Express Gold issuer audit 2026-11-23',
    'https://www.americanexpress.com/us/credit-cards/card/gold-card/',
    'Verified 2026-11-23 against the official American Express Gold Card product page. Conservative scoring model: 1 cent per point; portal-only multipliers, welcome bonuses, conditional credits, and housing rewards excluded from recommendation rankings. Category caps and enrollment terms apply; verify current terms with American Express.',
    '2026-11-23T07:24:16Z'
),
(
    '10000000-0000-4000-8000-000000000008',
    'American Express Platinum issuer audit 2026-11-23',
    'https://www.americanexpress.com/us/credit-cards/card/platinum/',
    'Verified 2026-11-23 against the official American Express Platinum Card product page (replaces prior broad category hub source). Conservative scoring model: 1 cent per point; capped/portal multipliers, welcome bonuses, conditional credits, and housing rewards excluded from recommendation rankings. Enrollment and stay minimums apply; verify current terms with American Express.',
    '2026-11-23T07:24:16Z'
),
(
    '10000000-0000-4000-8000-000000000009',
    'Capital One Quicksilver issuer audit 2026-11-23',
    'https://www.capitalone.com/credit-cards/quicksilver/',
    'Verified 2026-11-23 against the official Capital One Quicksilver Rewards (excellent credit) product page. Conservative scoring model: portal-only multipliers, welcome bonuses, and housing rewards excluded from recommendation rankings. Verify current terms and eligibility with Capital One.',
    '2026-11-23T07:24:17Z'
),
(
    '10000000-0000-4000-8000-00000000000a',
    'Capital One Savor for Students issuer audit 2026-11-23',
    'https://www.capitalone.com/credit-cards/savor-student/',
    'Verified 2026-11-23 against the official Capital One Savor Student Rewards product page. Conservative scoring model: portal-only multipliers, welcome bonuses, and housing rewards excluded from recommendation rankings. Grocery rate excludes superstores like Walmart and Target; verify current terms with Capital One.',
    '2026-11-23T07:24:17Z'
),
(
    '10000000-0000-4000-8000-00000000000b',
    'Capital One SavorOne issuer audit 2026-11-23',
    'https://www.capitalone.com/credit-cards/savorone/',
    'Verified 2026-11-23 against the official Capital One SavorOne Rewards ($39 annual fee, fair credit) product page. Capital One separately offers $0 Savor Rewards for excellent credit. Conservative scoring model: portal-only multipliers, welcome bonuses, and housing rewards excluded from recommendation rankings. Verify current terms with Capital One.',
    '2026-11-23T07:24:18Z'
),
(
    '10000000-0000-4000-8000-00000000000c',
    'Capital One Venture X issuer audit 2026-11-23',
    'https://www.capitalone.com/credit-cards/venture-x/',
    'Verified 2026-11-23 against the official Capital One Venture X Rewards product page. Conservative scoring model: 1 cent per mile; portal-only multipliers, welcome bonuses, conditional credits, and anniversary miles excluded from recommendation rankings. Verify current terms with Capital One.',
    '2026-11-23T07:24:18Z'
),
(
    '10000000-0000-4000-8000-00000000000d',
    'Chase Freedom Flex issuer audit 2026-11-23',
    'https://creditcards.chase.com/cash-back-credit-cards/freedom/flex',
    'Verified 2026-11-23 against the official Chase Freedom Flex product page (now advertises no foreign transaction fees). Conservative scoring model: quarterly rotating 5% uplift, Chase Travel portal uplift, welcome bonuses, and housing rewards excluded from recommendation rankings. Verify current terms with Chase.',
    '2026-11-23T07:24:18Z'
),
(
    '10000000-0000-4000-8000-00000000000e',
    'Chase Freedom Rise issuer audit 2026-11-23',
    'https://creditcards.chase.com/cash-back-credit-cards/freedom/rise',
    'Verified 2026-11-23 against the official Chase Freedom Rise product page. Conservative scoring model: promotional credits, welcome bonuses, and housing rewards excluded from recommendation rankings. Verify current terms with Chase.',
    '2026-11-23T07:24:19Z'
),
(
    '10000000-0000-4000-8000-00000000000f',
    'Chase Freedom Unlimited issuer audit 2026-11-23',
    'https://creditcards.chase.com/cash-back-credit-cards/freedom/unlimited',
    'Verified 2026-11-23 against the official Chase Freedom Unlimited product page. Conservative scoring model: Chase Travel portal uplift, welcome bonuses, and housing rewards excluded from recommendation rankings. Verify current terms with Chase.',
    '2026-11-23T07:24:20Z'
),
(
    '10000000-0000-4000-8000-000000000010',
    'Chase Sapphire Preferred issuer audit 2026-11-23',
    'https://creditcards.chase.com/rewards-credit-cards/sapphire/preferred',
    'Verified 2026-11-23 against the official Chase Sapphire Preferred product page and Offer Details. Conservative scoring model: 1 cent per point; includes verified standing 3x gas stations; excludes Chase Travel portal uplift, online-only grocery, select streaming, welcome bonuses, conditional credits, and housing rewards from recommendation rankings. Verify current terms with Chase.',
    '2026-11-23T07:24:21Z'
),
(
    '10000000-0000-4000-8000-000000000011',
    'Chase Sapphire Reserve issuer audit 2026-11-23',
    'https://creditcards.chase.com/rewards-credit-cards/sapphire/reserve',
    'Verified 2026-11-23 against the official Chase Sapphire Reserve product page. Conservative scoring model: 1 cent per point; Chase Travel portal uplift, welcome bonuses, conditional credits, and housing rewards excluded from recommendation rankings. Verify current terms with Chase.',
    '2026-11-23T07:24:31Z'
),
(
    '10000000-0000-4000-8000-000000000012',
    'Citi Double Cash issuer audit 2026-11-23',
    'https://www.citi.com/credit-cards/citi-double-cash-credit-card',
    'Verified 2026-11-23 against the official Citi Double Cash product page (replaces prior broad rewards hub source). Static HTML omits client-rendered APR/fee widget numbers; no annual fee confirmed on-page and via Citi product disclosures. Conservative scoring model: Citi Travel portal uplift, welcome bonuses, and housing rewards excluded from recommendation rankings. Verify current terms with Citi.',
    '2026-11-23T07:24:34Z'
),
(
    '10000000-0000-4000-8000-000000000013',
    'Citi Strata issuer audit 2026-11-23',
    'https://www.citi.com/credit-cards/citi-strata-credit-card',
    'Verified 2026-11-23 against the official Citi Strata Card ($0 annual fee) product page (replaces prior multi-card Strata family hub source). Conservative scoring model: 1 cent per point; Citi Travel portal uplift, self-select category uplift, welcome bonuses, and housing rewards excluded from recommendation rankings. Verify current terms with Citi.',
    '2026-11-23T07:24:40Z'
),
(
    '10000000-0000-4000-8000-000000000014',
    'Citi Strata Elite issuer audit 2026-11-23',
    'https://www.citi.com/credit-cards/citi-strata-elite-credit-card',
    'Verified 2026-11-23 against the official Citi Strata Elite product page. Static HTML omits client-rendered numeric fee slot; $595 annual fee corroborated by on-page Citigold Private Client $595 relationship credit text and official Citi disclosures (verify interactive Pricing & Information modal before launch). Conservative scoring model: 1 cent per point; Citi Travel portal uplift, Citi Nights window uplift, welcome bonuses, conditional credits, and housing rewards excluded from recommendation rankings. Verify current terms with Citi.',
    '2026-11-23T07:24:44Z'
);

WITH audit_rows(slug, source_id, summary, annual_fee_cents, reward_rates, benefits) AS (VALUES
(
    'amex-gold',
    '10000000-0000-4000-8000-000000000007'::uuid,
    'Audited 2026-11-23 from https://www.americanexpress.com/us/credit-cards/card/gold-card/',
    32500,
    '{"dining": 4, "groceries": 4, "flights": 3, "other": 1}'::jsonb,
    '["$325 annual fee; no foreign transaction fees", "4x at restaurants worldwide (up to $50,000 per calendar year, then 1x)", "4x at U.S. supermarkets (up to $25,000 per calendar year, then 1x)", "5x on prepaid hotels booked through AmexTravel.com or Amex Travel App; 3x on flights booked direct or via Amex Travel; 2x on prepaid car rentals and cruises via AmexTravel.com", "Up to $100 Resy credit per calendar year ($50 Jan-Jun and $50 Jul-Dec at qualifying U.S. Resy restaurants; enrollment required)", "Up to $84 Dunkin credit per year ($7 monthly at U.S. Dunkin locations; enrollment required)", "$120 Uber Cash per year ($10 monthly for U.S. rides and orders; add Gold to Uber account and pay with an Amex card)", "Up to $120 dining credit per year ($10 monthly at Grubhub/Seamless, Buffalo Wild Wings, Five Guys, The Cheesecake Factory, and Wonder; enrollment required)", "$100 property credit on eligible Hotel Collection stays booked through AmexTravel.com (two-night minimum)", "Transfer points to participating airline and hotel travel partners", "Verify current terms with American Express; conditional credits are excluded from recommendation rankings"]'::jsonb
),
(
    'amex-platinum',
    '10000000-0000-4000-8000-000000000008'::uuid,
    'Audited 2026-11-23 from https://www.americanexpress.com/us/credit-cards/card/platinum/',
    89500,
    '{"other": 1}'::jsonb,
    '["$895 annual fee ($195 per Additional Platinum Card); no foreign transaction fees", "5x on flights booked directly with airlines or via Amex Travel (up to $500,000/calendar year) and 5x on prepaid hotels via Amex Travel; 1x all other eligible purchases", "Up to $600 Hotel Credit per calendar year ($300 semi-annually on prepaid Fine Hotels + Resorts or The Hotel Collection bookings via Amex Travel; 2-night min on THC and effective Jan 1, 2027 on FHR)", "Up to $400 Resy Credit per calendar year ($100 quarterly at qualifying U.S. Resy restaurants; enrollment required)", "Up to $300 Digital Entertainment Credit per calendar year ($25 monthly at participating partners; enrollment required)", "Up to $300 lululemon Credit per calendar year ($75 quarterly at U.S. retail stores excl. outlets and lululemon.com; enrollment required)", "Up to $219 CLEAR+ Credit per calendar year on auto-renewing membership (excl. taxes/fees)", "Up to $200 Uber Cash per year ($15 monthly plus $20 December bonus for U.S. rides/orders; add card to Uber and pay with an Amex card) and up to $120 Uber One Credit per calendar year", "Up to $200 Airline Fee Credit per calendar year for incidental fees on one selected qualifying airline (enrollment required)", "Up to $200 Oura Ring Credit per calendar year and up to $155 Walmart+ Credit ($12.95/month plus taxes on auto-renewing monthly membership)", "Global Entry ($120 every 4 years) or TSA PreCheck (up to $85 every 4.5 years) application fee credit; Global Lounge Collection access (1,550+ lounges incl. Centurion, 10 Delta Sky Club visits when flying Delta, Priority Pass with enrollment)", "Verify current terms with American Express; conditional credits and capped/portal multipliers are excluded from recommendation rankings"]'::jsonb
),
(
    'quicksilver',
    '10000000-0000-4000-8000-000000000009'::uuid,
    'Audited 2026-11-23 from https://www.capitalone.com/credit-cards/quicksilver/ (base Quicksilver; excellent credit)',
    0,
    '{"other": 1.5}'::jsonb,
    '["$0 annual fee; no foreign transaction fees", "Unlimited 1.5% cash back on every purchase, every day", "5% cash back on hotels, vacation rentals, and rental cars via Capital One Travel and 5% via Capital One Entertainment", "Requires excellent credit; verify eligibility with Capital One", "Promotional cash bonuses may be offered; welcome bonuses and portal multipliers are excluded from recommendation rankings", "Verify current terms with Capital One"]'::jsonb
),
(
    'savor-for-students',
    '10000000-0000-4000-8000-00000000000a'::uuid,
    'Audited 2026-11-23 from https://www.capitalone.com/credit-cards/savor-student/',
    0,
    '{"dining": 3, "groceries": 3, "entertainment": 3, "other": 1}'::jsonb,
    '["$0 annual fee; no foreign transaction fees", "Unlimited 3% cash back at grocery stores (excluding superstores like Walmart and Target), on dining, entertainment, and popular streaming services", "1% cash back on all other purchases", "8% cash back on Capital One Entertainment and 5% on hotels, vacation rentals, and rental cars via Capital One Travel", "No credit score required to apply; student eligibility applies", "Verify current terms with Capital One"]'::jsonb
),
(
    'savorone',
    '10000000-0000-4000-8000-00000000000b'::uuid,
    'Audited 2026-11-23 from https://www.capitalone.com/credit-cards/savorone/ (SavorOne Fair Credit $39 variant)',
    3900,
    '{"dining": 3, "groceries": 3, "entertainment": 3, "other": 1}'::jsonb,
    '["$39 annual fee on this SavorOne (Fair Credit) product; no foreign transaction fees", "Unlimited 3% cash back at grocery stores (excluding superstores like Walmart and Target), on dining, entertainment, and popular streaming services", "1% cash back on all other purchases", "5% cash back via Capital One Travel and 8% cash back via Capital One Entertainment", "Capital One separately offers $0 annual fee Savor Rewards for excellent credit; verify which product applies", "Verify current terms with Capital One"]'::jsonb
),
(
    'venture-x',
    '10000000-0000-4000-8000-00000000000c'::uuid,
    'Audited 2026-11-23 from https://www.capitalone.com/credit-cards/venture-x/',
    39500,
    '{"other": 2}'::jsonb,
    '["$395 annual fee; no foreign transaction fees", "Unlimited 2x miles on all other purchases, every day", "10x miles on hotels and rental cars and 5x miles on flights and vacation rentals via Capital One Travel; 5x miles on Capital One Entertainment", "$300 annual Capital One Travel credit for bookings through Capital One Travel", "10,000 anniversary bonus miles each year starting with the first anniversary", "Capital One Lounge and Landing access plus 1,300+ Priority Pass lounges (primary cardholders)", "Global Entry or TSA PreCheck application fee credit every 4 years; cell phone protection up to $800 (terms apply); transfer miles to 15+ travel loyalty programs", "Verify current terms with Capital One; portal multipliers, credits, and anniversary miles are excluded from recommendation rankings"]'::jsonb
),
(
    'freedom-flex',
    '10000000-0000-4000-8000-00000000000d'::uuid,
    'Audited 2026-11-23 from https://creditcards.chase.com/cash-back-credit-cards/freedom/flex',
    0,
    '{"dining": 3, "drugstores": 3, "other": 1}'::jsonb,
    '["$0 annual fee", "No foreign transaction fees (newly advertised on Chase product page as of 2026-11-23)", "5% cash back on up to $1,500 in combined rotating bonus category purchases each quarter you activate", "5% cash back on travel purchased through Chase Travel", "3% cash back on dining at restaurants (including takeout and eligible delivery) and on drugstore purchases; 1% on all other purchases", "Verify current terms with Chase; rotating and portal multipliers are excluded from recommendation rankings"]'::jsonb
),
(
    'freedom-rise',
    '10000000-0000-4000-8000-00000000000e'::uuid,
    'Audited 2026-11-23 from https://creditcards.chase.com/cash-back-credit-cards/freedom/rise',
    0,
    '{"other": 1.5}'::jsonb,
    '["$0 annual fee", "1.5% cash back on all purchases", "Designed for new-to-credit and student applicants; holding at least $250 in Chase checking or savings can increase approval odds", "Verify current terms with Chase"]'::jsonb
),
(
    'freedom-unlimited',
    '10000000-0000-4000-8000-00000000000f'::uuid,
    'Audited 2026-11-23 from https://creditcards.chase.com/cash-back-credit-cards/freedom/unlimited',
    0,
    '{"dining": 3, "drugstores": 3, "other": 1.5}'::jsonb,
    '["$0 annual fee", "1.5% cash back on all other purchases", "3% cash back on dining at restaurants (including takeout and eligible delivery) and on drugstore purchases", "5% cash back on travel purchased through Chase Travel", "Verify current terms with Chase; portal multipliers are excluded from recommendation rankings"]'::jsonb
),
(
    'sapphire-preferred',
    '10000000-0000-4000-8000-000000000010'::uuid,
    'Audited 2026-11-23 from https://creditcards.chase.com/rewards-credit-cards/sapphire/preferred',
    9500,
    '{"dining": 3, "gas": 3, "travel": 2, "other": 1}'::jsonb,
    '["$95 annual fee; no foreign transaction fees", "5x on Chase Travel; 3x on dining, gas stations, EV charging, vacation homes at top brands, top streaming services, and online grocery (excluding Target, Walmart, and wholesale clubs); 2x on all other travel; 1x all other purchases", "Up to $100 Chase Travel hotel credit each account anniversary year for hotel stays purchased through Chase Travel", "Up to $120 Global Entry, TSA PreCheck, or NEXUS application fee credit every four years", "Transfer points to participating airline and hotel partners", "Primary rental-car coverage and trip cancellation, interruption, and delay coverage (terms, exclusions, and limits apply)", "Verify current terms with Chase; conditional credits, portal uplift, online-only grocery, and select streaming are excluded from recommendation rankings"]'::jsonb
),
(
    'sapphire-reserve',
    '10000000-0000-4000-8000-000000000011'::uuid,
    'Audited 2026-11-23 from https://creditcards.chase.com/rewards-credit-cards/sapphire/reserve',
    79500,
    '{"dining": 3, "flights": 4, "hotels": 4, "other": 1}'::jsonb,
    '["$795 annual fee ($195 per authorized user); no foreign transaction fees", "8x on all purchases through Chase Travel (including The Edit); 4x on flights booked direct; 4x on hotels booked direct; 3x on dining worldwide; 1x all other purchases", "$300 annual travel credit each account anniversary year (credited purchases do not earn points)", "Up to $500 annual credit for stays with The Edit (up to $250 per prepaid booking; two-night minimum; credited purchases do not earn points)", "Up to $300 annual dining credit ($150 Jan-Jun and $150 Jul-Dec) at Sapphire Reserve Exclusive Tables restaurants on OpenTable", "Up to $300 annual StubHub/viagogo credit ($150 Jan-Jun and $150 Jul-Dec through 12/31/2027; activation required)", "Global Entry, TSA PreCheck, or NEXUS application fee credit up to $120 every four years", "Chase Sapphire Reserve Lounge Network: Sapphire Lounges by The Club and 1,300+ Priority Pass lounges worldwide with up to two guests", "Time-bound partner offers (Apple TV & Apple Music activate by 6/22/2027; Lyft $10/mo + 5x through 9/30/2027; Peloton $10/mo + 10x through 12/31/2027; DashPass activate by 12/31/2029) and transferable Ultimate Rewards points", "Verify current terms with Chase; conditional credits and portal multipliers are excluded from recommendation rankings"]'::jsonb
),
(
    'double-cash',
    '10000000-0000-4000-8000-000000000012'::uuid,
    'Audited 2026-11-23 from https://www.citi.com/credit-cards/citi-double-cash-credit-card',
    0,
    '{"other": 2}'::jsonb,
    '["No annual fee; no authorized user fee", "Unlimited 2% cash back on every purchase: 1% when you buy plus an additional 1% as you pay (earned as ThankYou Points; no caps or category enrollment)", "5% total cash back on hotels, car rentals, and attractions booked through the Citi Travel portal (additional 3% via portal)", "Verify current terms with Citi; portal multipliers are excluded from recommendation rankings"]'::jsonb
),
(
    'strata',
    '10000000-0000-4000-8000-000000000013'::uuid,
    'Audited 2026-11-23 from https://www.citi.com/credit-cards/citi-strata-credit-card',
    0,
    '{"groceries": 3, "gas": 3, "dining": 2, "other": 1}'::jsonb,
    '["$0 annual fee; no authorized user fee", "5x on hotels, car rentals, and attractions booked on cititravel.com", "3x at supermarkets; 3x at gas & EV charging stations and on select transit", "3x on one eligible Self-Select Category (Fitness Clubs, Select Streaming Services, Live Entertainment, Cosmetic Stores/Barber Shops/Hair Salons, or Pet Supply Stores)", "2x at restaurants; 1x on all other purchases; transferable ThankYou Points", "Verify current terms with Citi; portal and self-select multipliers are excluded from recommendation rankings"]'::jsonb
),
(
    'strata-elite',
    '10000000-0000-4000-8000-000000000014'::uuid,
    'Audited 2026-11-23 from https://www.citi.com/credit-cards/citi-strata-elite-credit-card',
    59500,
    '{"dining": 3, "other": 1.5}'::jsonb,
    '["$595 annual fee; no foreign transaction fees", "12x on hotels, car rentals, and attractions booked on cititravel.com; 6x on air travel booked on cititravel.com", "6x at restaurants on Citi Nights (Friday and Saturday 6 PM-6 AM ET); 3x at restaurants any other time; 1.5x on all other purchases", "Up to $300 Annual Hotel Benefit each calendar year on a hotel stay of 2 nights or more booked through cititravel.com", "Up to $200 Annual Splurge Credit each calendar year on your choice of up to 2 participating brands (1stDibs, American Airlines, Best Buy, Future Personal Training, Live Nation; exclusions apply)", "Up to $200 Annual Blacklane Credit each calendar year ($100 Jan-Jun and $100 Jul-Dec)", "Priority Pass Select membership (1,500+ lounges) plus 4 American Airlines Admirals Club access passes per calendar year", "Up to $120 Global Entry or TSA PreCheck application fee credit every four years; transferable ThankYou Points; travel and shopping protections (terms apply)", "Verify current terms with Citi; conditional credits, portal uplift, and Citi Nights window uplift are excluded from recommendation rankings"]'::jsonb
)
)
INSERT INTO revocred.card_catalog_versions (
    catalog_card_id, source_id, dataset_version, summary, best_use,
    annual_fee_cents, reward_rates, benefits, transferable_points,
    travel_scope, minimum_credit_tier, rewards_type,
    first_year_bonus_estimate_cents, annual_benefit_estimate_cents, created_at
)
SELECT c.id,
       a.source_id,
       'conservative-2026-11-23-v1',
       a.summary,
       v.best_use,
       a.annual_fee_cents,
       a.reward_rates,
       a.benefits,
       v.transferable_points,
       v.travel_scope,
       v.minimum_credit_tier,
       v.rewards_type,
       0,
       0,
       GREATEST(now(), v.created_at + interval '1 second')
FROM audit_rows a
JOIN revocred.catalog_cards c
  ON c.slug = a.slug
 AND c.owner_user_id IS NULL
 AND c.data_kind = 'issuer_snapshot'
 AND c.is_active
JOIN LATERAL (
    SELECT * FROM revocred.card_catalog_versions
    WHERE catalog_card_id = c.id
    ORDER BY created_at DESC, id DESC
    LIMIT 1
) v ON true
ON CONFLICT (catalog_card_id, dataset_version) DO NOTHING;

-- Keep the 14 search-only catalog mirror rows in card_reference_index aligned
-- with the freshly audited product URLs, dates, and conservative scoring rates.
UPDATE revocred.card_reference_index r
SET annual_fee_cents = v.annual_fee_cents,
    reward_rates = v.reward_rates,
    source_url = s.url,
    source_captured_on = '2026-11-23',
    disclaimer = s.disclaimer
FROM revocred.catalog_cards c
JOIN revocred.card_catalog_versions v
  ON v.catalog_card_id = c.id
 AND v.dataset_version = 'conservative-2026-11-23-v1'
JOIN revocred.catalog_sources s
  ON s.id = v.source_id
WHERE r.slug = c.slug || '-index'
  AND r.terms_status = 'verified'
  AND c.owner_user_id IS NULL
  AND c.data_kind = 'issuer_snapshot'
  AND c.is_active;

-- +goose Down
DELETE FROM revocred.card_catalog_versions
WHERE dataset_version = 'conservative-2026-11-23-v1';

DELETE FROM revocred.catalog_sources
WHERE id IN (
    '10000000-0000-4000-8000-000000000007',
    '10000000-0000-4000-8000-000000000008',
    '10000000-0000-4000-8000-000000000009',
    '10000000-0000-4000-8000-00000000000a',
    '10000000-0000-4000-8000-00000000000b',
    '10000000-0000-4000-8000-00000000000c',
    '10000000-0000-4000-8000-00000000000d',
    '10000000-0000-4000-8000-00000000000e',
    '10000000-0000-4000-8000-00000000000f',
    '10000000-0000-4000-8000-000000000010',
    '10000000-0000-4000-8000-000000000011',
    '10000000-0000-4000-8000-000000000012',
    '10000000-0000-4000-8000-000000000013',
    '10000000-0000-4000-8000-000000000014'
);

UPDATE revocred.card_reference_index r
SET annual_fee_cents = v.annual_fee_cents,
    reward_rates = v.reward_rates,
    source_url = COALESCE(NULLIF(s.url, ''), 'https://www.issuer.example.invalid'),
    source_captured_on = COALESCE(s.published_at::date, DATE '2026-09-23'),
    disclaimer = s.disclaimer
FROM revocred.catalog_cards c
JOIN LATERAL (
    SELECT * FROM revocred.card_catalog_versions
    WHERE catalog_card_id = c.id
    ORDER BY created_at DESC, id DESC
    LIMIT 1
) v ON true
LEFT JOIN revocred.catalog_sources s ON s.id = v.source_id
WHERE r.slug = c.slug || '-index'
  AND r.terms_status = 'verified'
  AND c.owner_user_id IS NULL
  AND c.data_kind = 'issuer_snapshot'
  AND c.is_active;
