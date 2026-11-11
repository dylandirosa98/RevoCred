-- +goose Up
-- Remember which search-index product a member's own card is, so the API can
-- score a card added without typed terms with conservative community earning
-- rates (OpenCard DB, mapped in internal/carddata). The link identifies the
-- product only: terms the member typed always win, and a linked card is still
-- owned user_supplied data that can never be recommended.
ALTER TABLE revocred.catalog_cards
    ADD COLUMN reference_card_id UUID REFERENCES revocred.card_reference_index(id) ON DELETE SET NULL,
    ADD CONSTRAINT catalog_cards_reference_owned
        CHECK (reference_card_id IS NULL OR (owner_user_id IS NOT NULL AND data_kind = 'user_supplied'));
CREATE INDEX catalog_cards_reference_card ON revocred.catalog_cards(reference_card_id)
    WHERE reference_card_id IS NOT NULL;
COMMENT ON COLUMN revocred.catalog_cards.reference_card_id IS
    'Search-index product this owned card was added as (exact issuer + name). Identity only; never overrides member-entered terms.';

-- Exact community product identity only; never issuer-verified terms or candidates.
ALTER TABLE revocred.card_reference_index ADD COLUMN opencard_product_id TEXT;
COMMENT ON COLUMN revocred.card_reference_index.opencard_product_id IS
    'Exact OpenCard DB product identity; community data, never recommendation eligibility.';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-amex-blue-cash-everyday' WHERE slug = 'amex-blue-cash-everyday';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-amex-blue-cash-preferred' WHERE slug = 'amex-blue-cash-preferred';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-amex-delta-skymiles-blue' WHERE slug = 'amex-delta-skymiles-blue';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-amex-delta-skymiles-gold' WHERE slug = 'amex-delta-skymiles-gold';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-amex-delta-skymiles-platinum' WHERE slug = 'amex-delta-skymiles-platinum';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-amex-delta-skymiles-reserve' WHERE slug = 'amex-delta-skymiles-reserve';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-amex-hilton-honors' WHERE slug = 'amex-hilton-honors';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-amex-hilton-honors-surpass' WHERE slug = 'amex-hilton-honors-surpass';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-amex-hilton-honors-aspire' WHERE slug = 'amex-hilton-honors-aspire';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-amex-marriott-bonvoy-brilliant' WHERE slug = 'amex-marriott-bonvoy-brilliant';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-amex-marriott-bonvoy-bevy' WHERE slug = 'amex-marriott-bonvoy-bevy';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-chase-aer-lingus-signature' WHERE slug = 'aer-lingus-visa-signature';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-chase-aeroplan' WHERE slug = 'air-canada-aeroplan-card';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-chase-amazon-visa' WHERE slug = 'amazon-visa';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-chase-british-airways-signature' WHERE slug = 'british-airways-visa-signature';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-chase-disney-inspire' WHERE slug = 'disney-inspire-visa-card';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-chase-disney-premier' WHERE slug = 'disney-premier-visa-card';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-chase-disney' WHERE slug = 'disney-visa-card';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-chase-doordash-rewards-mastercard' WHERE slug = 'doordash-rewards-mastercard';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-chase-ihg-premier' WHERE slug = 'ihg-one-rewards-premier';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-chase-ihg-traveler' WHERE slug = 'ihg-one-rewards-traveler';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-chase-iberia-signature' WHERE slug = 'iberia-visa-signature';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-chase-instacart-mastercard' WHERE slug = 'instacart-mastercard';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-chase-marriott-bonvoy-bold' WHERE slug = 'marriott-bonvoy-bold';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-chase-marriott-bonvoy-boundless' WHERE slug = 'marriott-bonvoy-boundless';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-chase-marriott-bonvoy-bountiful' WHERE slug = 'marriott-bonvoy-bountiful';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-chase-amazon-prime' WHERE slug = 'prime-visa';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-chase-southwest-plus' WHERE slug = 'southwest-rapid-rewards-plus';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-chase-southwest-premier' WHERE slug = 'southwest-rapid-rewards-premier';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-chase-southwest-priority' WHERE slug = 'southwest-rapid-rewards-priority';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-chase-united-club' WHERE slug = 'united-club-card';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-chase-united-explorer' WHERE slug = 'united-explorer-card';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-chase-united-gateway' WHERE slug = 'united-gateway-card';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-chase-united-quest' WHERE slug = 'united-quest-card';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-chase-world-of-hyatt' WHERE slug = 'world-of-hyatt';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-discover-it-cash-back' WHERE slug = 'discover-discover-it-cash-back';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-discover-it-miles' WHERE slug = 'discover-discover-it-miles';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-discover-it-chrome' WHERE slug = 'discover-discover-it-chrome-gas-and-restaurants';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-discover-it-student-cash-back' WHERE slug = 'discover-discover-it-student-cash-back';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-discover-it-student-chrome' WHERE slug = 'discover-discover-it-student-chrome';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-capital-one-venture' WHERE slug = 'capital-one-venture-rewards';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-capital-one-ventureone' WHERE slug = 'capital-one-ventureone-rewards';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-capital-one-savor' WHERE slug = 'capital-one-savor-rewards';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-capital-one-quicksilverone' WHERE slug = 'capital-one-quicksilverone-rewards';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-capital-one-quicksilver-secured-cash-rewards' WHERE slug = 'capital-one-quicksilver-secured-rewards';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-capital-one-quicksilver-student-cash-rewards' WHERE slug = 'capital-one-quicksilver-rewards-for-students';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-capital-one-platinum' WHERE slug = 'capital-one-platinum';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-capital-one-platinum-secured' WHERE slug = 'capital-one-platinum-secured';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-capital-one-t-mobile-visa' WHERE slug = 'capital-one-t-mobile-visa';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-capital-one-rei-co-op-mastercard' WHERE slug = 'capital-one-rei-co-op-mastercard';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-citi-strata-premier' WHERE slug = 'citi-strata-premier';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-citi-simplicity' WHERE slug = 'citi-simplicity';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-citi-diamond-preferred' WHERE slug = 'citi-diamond-preferred';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-citi-aadvantage-platinum-select-world-elite' WHERE slug = 'citi-aadvantage-platinum-select';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-citi-aadvantage-executive' WHERE slug = 'citi-aadvantage-executive';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-citi-aadvantage-globe' WHERE slug = 'citi-aadvantage-globe';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-citi-aadvantage-mileup' WHERE slug = 'citi-aadvantage-mileup';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-citi-costco-anywhere-visa-card-by-citi' WHERE slug = 'citi-costco-anywhere-visa';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-citi-at-and-t-points-plus' WHERE slug = 'citi-at-and-t-points-plus';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-citi-my-best-buy-credit-card' WHERE slug = 'citi-my-best-buy-credit-card';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-citi-home-depot-consumer' WHERE slug = 'citi-the-home-depot-consumer-credit-card';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-citi-macys-credit-card' WHERE slug = 'citi-macys-credit-card';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-wells-fargo-active-cash' WHERE slug = 'wells-fargo-active-cash';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-wells-fargo-autograph' WHERE slug = 'wells-fargo-autograph';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-wells-fargo-autograph-journey' WHERE slug = 'wells-fargo-autograph-journey';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-wells-fargo-reflect' WHERE slug = 'wells-fargo-reflect';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-wells-fargo-expedia-one-key' WHERE slug = 'wells-fargo-one-key';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-wells-fargo-choice-privileges' WHERE slug = 'wells-fargo-choice-privileges-mastercard';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-wells-fargo-choice-privileges-select' WHERE slug = 'wells-fargo-choice-privileges-select-mastercard';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-us-bank-altitude-go' WHERE slug = 'u-s-bank-altitude-go-visa-signature';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-us-bank-altitude-connect' WHERE slug = 'u-s-bank-altitude-connect-visa-signature';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-us-bank-cash-plus' WHERE slug = 'u-s-bank-cash-plus-visa-signature';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-us-bank-smartly' WHERE slug = 'u-s-bank-smartly-visa-signature';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-us-bank-shield-visa' WHERE slug = 'u-s-bank-shield-visa';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-bank-of-america-atmos-rewards-ascent' WHERE slug = 'bank-of-america-atmos-rewards-ascent-visa-signature';
UPDATE revocred.card_reference_index SET opencard_product_id = 'us-bank-of-america-atmos-rewards-summit' WHERE slug = 'bank-of-america-atmos-rewards-summit-visa-infinite';
-- US identities from OpenCard DB, CC BY 4.0, captured 2026-11-09.
-- Snapshot SHA-256: 3bd65d8237c4d3835656c45a5cb480319117a06abb4358e0b46db989966ac73d
WITH products(product_id, issuer, name, network) AS (VALUES
    ('us-affinity-fcu-business-first-visa', 'Affinity Federal Credit Union', 'Affinity Business First Visa Credit Card', 'visa'),
    ('us-affinity-fcu-cash-rewards-visa-signature', 'Affinity Federal Credit Union', 'Affinity FCU Cash Rewards Visa Signature', 'visa'),
    ('us-affinity-fcu-premium-visa', 'Affinity Federal Credit Union', 'Affinity FCU Premium Visa', 'visa'),
    ('us-affinity-fcu-pure-rewards-visa', 'Affinity Federal Credit Union', 'Affinity FCU Pure Rewards Visa', 'visa'),
    ('us-affinity-fcu-secured-visa', 'Affinity Federal Credit Union', 'Affinity FCU Secured Visa', 'visa'),
    ('us-alliant-visa-platinum', 'Alliant Credit Union', 'Alliant Visa Platinum Credit Card', 'visa'),
    ('us-alliant-visa-signature-cashback', 'Alliant Credit Union', 'Alliant Visa Signature Cashback Credit Card', 'visa'),
    ('us-amex-amazon-business', 'American Express', 'Amazon Business American Express Card', 'amex'),
    ('us-amex-blue-business-cash', 'American Express', 'Blue Business Cash Card from American Express', 'amex'),
    ('us-amex-blue-business-plus', 'American Express', 'Blue Business Plus Credit Card from American Express', 'amex'),
    ('us-amex-blue-cash-everyday', 'American Express', 'Blue Cash Everyday® Card', 'amex'),
    ('us-amex-blue-cash-preferred', 'American Express', 'Blue Cash Preferred® Card', 'amex'),
    ('us-amex-business-gold', 'American Express', 'American Express Business Gold Card', 'amex'),
    ('us-amex-business-gold-rewards', 'American Express', 'American Express Business Gold Rewards Card', 'amex'),
    ('us-amex-business-green', 'American Express', 'Business Green Rewards Card from American Express', 'amex'),
    ('us-amex-business-platinum', 'American Express', 'Business Platinum Card®', 'amex'),
    ('us-amex-cash-magnet', 'American Express', 'American Express Cash Magnet® Card', 'amex'),
    ('us-amex-corporate-platinum', 'American Express', 'American Express Corporate Platinum Card', 'amex'),
    ('us-amex-delta-skymiles-blue', 'American Express', 'Delta SkyMiles® Blue American Express Card', 'amex'),
    ('us-amex-delta-skymiles-gold', 'American Express', 'Delta SkyMiles® Gold American Express Card', 'amex'),
    ('us-amex-delta-skymiles-gold-business', 'American Express', 'Delta SkyMiles Gold Business American Express Card', 'amex'),
    ('us-amex-delta-skymiles-platinum', 'American Express', 'Delta SkyMiles® Platinum American Express Card', 'amex'),
    ('us-amex-delta-skymiles-platinum-business', 'American Express', 'Delta SkyMiles Platinum Business American Express Card', 'amex'),
    ('us-amex-delta-skymiles-reserve', 'American Express', 'Delta SkyMiles® Reserve American Express Card', 'amex'),
    ('us-amex-delta-skymiles-reserve-business', 'American Express', 'Delta SkyMiles Reserve Business American Express Card', 'amex'),
    ('us-amex-everyday', 'American Express', 'Amex EveryDay Credit Card', 'amex'),
    ('us-amex-everyday-preferred', 'American Express', 'Amex EveryDay® Preferred Credit Card', 'amex'),
    ('us-amex-gold', 'American Express', 'American Express® Gold Card', 'amex'),
    ('us-amex-graphite-business-cash-unlimited', 'American Express', 'American Express Graphite Business Cash Unlimited Card', 'amex'),
    ('us-amex-green', 'American Express', 'American Express® Green Card', 'amex'),
    ('us-amex-hilton-honors', 'American Express', 'Hilton Honors American Express Card', 'amex'),
    ('us-amex-hilton-honors-aspire', 'American Express', 'Hilton Honors American Express Aspire Card', 'amex'),
    ('us-amex-hilton-honors-business', 'American Express', 'The Hilton Honors American Express Business Card', 'amex'),
    ('us-amex-hilton-honors-surpass', 'American Express', 'Hilton Honors American Express Surpass® Card', 'amex'),
    ('us-amex-lowes', 'American Express', 'Lowe''s Business Rewards Card from American Express', 'amex'),
    ('us-amex-marriott-bonvoy-bevy', 'American Express', 'Marriott Bonvoy Bevy® American Express® Card', 'amex'),
    ('us-amex-marriott-bonvoy-brilliant', 'American Express', 'Marriott Bonvoy Brilliant® American Express® Card', 'amex'),
    ('us-amex-marriott-bonvoy-business', 'American Express', 'Marriott Bonvoy Business Credit Card', 'amex'),
    ('us-amex-mercedes-benz', 'American Express', 'Mercedes-Benz Credit Card from American Express', 'amex'),
    ('us-amex-mercedes-benz-platinum', 'American Express', 'Mercedes-Benz Platinum Card from American Express', 'amex'),
    ('us-amex-platinum', 'American Express', 'The Platinum Card®', 'amex'),
    ('us-amex-platinum-morgan-stanley', 'American Express', 'The Platinum Card® from American Express Exclusively for Morgan Stanley', 'amex'),
    ('us-amex-platinum-schwab', 'American Express', 'The Platinum Card® from American Express Exclusively for Charles Schwab', 'amex'),
    ('us-amex-plenti', 'American Express', 'American Express Plenti® Card', 'amex'),
    ('us-amex-plum', 'American Express', 'American Express Plum® Card', 'amex'),
    ('us-amex-premier-rewards-gold', 'American Express', 'American Express Premier Rewards Gold Card', 'amex'),
    ('us-amex-rakuten', 'First Electronic Bank', 'Rakuten American Express Card', 'amex'),
    ('us-amex-schwab-investor', 'American Express', 'Charles Schwab Investor Credit Card™ from American Express', 'amex'),
    ('us-amex-simplycash-plus-business', 'American Express', 'American Express SimplyCash Plus® Business Card', 'amex'),
    ('us-amex-starwood-preferred-guest-business', 'American Express', 'Starwood Preferred Guest Business Credit Card from American Express', 'amex'),
    ('us-aod-fcu-share-secured-visa-platinum', 'AOD Federal Credit Union', 'AOD FCU Share Secured Visa Platinum', 'visa'),
    ('us-aod-fcu-visa-platinum', 'AOD Federal Credit Union', 'AOD FCU Visa Platinum', 'visa'),
    ('us-aod-fcu-visa-signature', 'AOD Federal Credit Union', 'AOD FCU Visa Signature', 'visa'),
    ('us-apple-card', 'Goldman Sachs', 'Apple Card', 'mastercard'),
    ('us-aven-home-equity-visa', 'Coastal Community Bank', 'Aven Home Equity Visa Card', 'visa'),
    ('us-aven-rewards-visa', 'Coastal Community Bank', 'Aven Rewards Visa Card', 'visa'),
    ('us-bank-of-america-air-france-klm', 'Bank of America', 'Air France KLM Visa Signature Credit Card', 'visa'),
    ('us-bank-of-america-alaska-airlines-business', 'Bank of America', 'Alaska Airlines Visa Signature Business Card', 'visa'),
    ('us-bank-of-america-alaska-airlines-visa-platinum-plus', 'Bank of America', 'Alaska Airlines Visa Platinum Plus', 'visa'),
    ('us-bank-of-america-alaska-airlines-visa-signature', 'Bank of America', 'Alaska Airlines Visa Signature', 'visa'),
    ('us-bank-of-america-allways-rewards', 'Bank of America', 'Allegiant® Allways Rewards Visa® Card', 'visa'),
    ('us-bank-of-america-atmos-rewards-ascent', 'Bank of America', 'Atmos™ Rewards Ascent Visa Signature® Credit Card', 'visa'),
    ('us-bank-of-america-atmos-rewards-business', 'Bank of America', 'Atmos™ Rewards Visa Signature® Business Card', 'visa'),
    ('us-bank-of-america-atmos-rewards-summit', 'Bank of America', 'Atmos™ Rewards Summit Visa Infinite® Credit Card', 'visa'),
    ('us-bank-of-america-bankamericard', 'Bank of America', 'BankAmericard Credit Card', 'visa'),
    ('us-bank-of-america-business-advantage-customized-cash', 'Bank of America', 'Business Advantage Cash Rewards Credit Card with 3% Choice Category', 'mastercard'),
    ('us-bank-of-america-business-advantage-travel-rewards', 'Bank of America', 'Business Advantage Travel Rewards World Mastercard® Credit Card', 'mastercard'),
    ('us-bank-of-america-business-advantage-unlimited-cash', 'Bank of America', 'Business Advantage Unlimited Cash Rewards Mastercard® Credit Card', 'mastercard'),
    ('us-bank-of-america-customized-cash-rewards', 'Bank of America', 'Bank of America® Customized Cash Rewards Credit Card', 'visa'),
    ('us-bank-of-america-free-spirit', 'Bank of America', 'Free Spirit® Travel Mastercard®', 'mastercard'),
    ('us-bank-of-america-nea-ratesmart', 'Bank of America', 'NEA RateSmart Mastercard Credit Card', 'mastercard'),
    ('us-bank-of-america-norwegian-cruise-line', 'Bank of America', 'Norwegian Cruise Line® World Mastercard®', 'mastercard'),
    ('us-bank-of-america-platinum-plus', 'Bank of America', 'Platinum Plus® Mastercard® Business Credit Card', 'mastercard'),
    ('us-bank-of-america-premium-rewards', 'Bank of America', 'Bank of America® Premium Rewards® credit card', 'visa'),
    ('us-bank-of-america-premium-rewards-elite', 'Bank of America', 'Bank of America® Premium Rewards® Elite Credit Card', 'visa'),
    ('us-bank-of-america-susan-g-komen-customized-cash-rewards', 'Bank of America', 'Susan G. Komen Customized Cash Rewards Visa Credit Card', 'visa'),
    ('us-bank-of-america-travel-rewards', 'Bank of America', 'Bank of America® Travel Rewards Credit Card', 'visa'),
    ('us-bank-of-america-unlimited-cash-rewards', 'Bank of America', 'Bank of America® Unlimited Cash Rewards Credit Card', 'visa'),
    ('us-barclays-aadvantage-aviator-red-world-elite', 'Barclays', 'AAdvantage Aviator Red World Elite', 'mastercard'),
    ('us-barclays-aarp-essential-rewards', 'Barclays', 'AARP® Essential Rewards Mastercard® from Barclays', 'mastercard'),
    ('us-barclays-aarp-travel-rewards', 'Barclays', 'AARP® Travel Rewards Mastercard® from Barclays', 'mastercard'),
    ('us-barclays-arrival', 'Barclays', 'Barclays Arrival® World Mastercard®', 'mastercard'),
    ('us-barclays-arrival-plus', 'Barclays', 'Barclays Arrival Plus® World Elite Mastercard®', 'mastercard'),
    ('us-barclays-athleta-encore-mastercard', 'Barclays', 'Athleta Encore Mastercard', 'mastercard'),
    ('us-barclays-banana-republic-encore-mastercard', 'Barclays', 'Banana Republic Encore Mastercard', 'mastercard'),
    ('us-barclays-breeze', 'Barclays', 'Breeze Easy® Visa® Credit Card', 'visa'),
    ('us-barclays-carnival-world-mastercard', 'Barclays', 'Carnival® World Mastercard®', 'mastercard'),
    ('us-barclays-cashforward', 'Barclays', 'Barclays CashForward® World Mastercard®', 'mastercard'),
    ('us-barclays-diamond-resorts-international', 'Barclays', 'Diamond Resorts World Mastercard®', 'mastercard'),
    ('us-barclays-emirates-skywards-premium-world-elite', 'Barclays', 'Emirates Skywards Premium World Elite Mastercard', 'mastercard'),
    ('us-barclays-emirates-skywards-rewards-world-elite', 'Barclays', 'Emirates Skywards Rewards World Elite Mastercard', 'mastercard'),
    ('us-barclays-frontier-airlines-world', 'Barclays', 'Frontier Airlines World Mastercard® Credit Card', 'mastercard'),
    ('us-barclays-frontier-business', 'Barclays', 'Frontier Airlines Business Card', 'mastercard'),
    ('us-barclays-gap-encore-mastercard', 'Barclays', 'Gap Encore Mastercard', 'mastercard'),
    ('us-barclays-gm-rewards-mastercard', 'Barclays', 'GM Rewards Mastercard', 'mastercard'),
    ('us-barclays-hawaiian-airlines-world-elite', 'Barclays', 'Hawaiian Airlines® Bank of Hawaii World Elite Mastercard®', 'mastercard'),
    ('us-barclays-hawaiian-airlines-world-elite-business', 'Barclays', 'Hawaiian Airlines® World Elite Business Mastercard®', 'mastercard'),
    ('us-barclays-holland-america-line-rewards-visa', 'Barclays', 'Holland America Line Rewards Visa® Card', 'visa'),
    ('us-barclays-jetblue', 'Barclays', 'JetBlue Card', 'mastercard'),
    ('us-barclays-jetblue-business', 'Barclays', 'JetBlue Business Card', 'mastercard'),
    ('us-barclays-jetblue-plus', 'Barclays', 'JetBlue Plus Card', 'mastercard'),
    ('us-barclays-jetblue-premier', 'Barclays', 'JetBlue Premier Card', 'mastercard'),
    ('us-barclays-lufthansa-miles-and-more', 'Barclays', 'Lufthansa Miles and More® World Elite Mastercard®', 'mastercard'),
    ('us-barclays-old-navy-encore-mastercard', 'Barclays', 'Old Navy Encore Mastercard', 'mastercard'),
    ('us-barclays-priceline-vip-rewards-visa', 'Barclays', 'Priceline VIP Rewards Visa® Card', 'visa'),
    ('us-barclays-princess-rewards-visa', 'Barclays', 'Princess Cruises Rewards Visa® Card', 'visa'),
    ('us-barclays-rci-elite-rewards-world-mastercard', 'Barclays', 'RCI Elite Rewards World Mastercard®', 'mastercard'),
    ('us-barclays-uber-visa', 'Barclays', 'Uber Visa Card', 'visa'),
    ('us-barclays-upromise', 'Barclays', 'Upromise® World Mastercard®', 'mastercard'),
    ('us-barclays-wyndham-rewards-earner', 'Barclays', 'Wyndham Rewards Earner Card', 'visa'),
    ('us-barclays-wyndham-rewards-earner-business', 'Barclays', 'Wyndham Rewards Earner Business Card', 'visa'),
    ('us-barclays-wyndham-rewards-earner-plus', 'Barclays', 'Wyndham Rewards Earner Plus Card', 'visa'),
    ('us-barclays-wyndham-rewards-earner-premier', 'Barclays', 'Wyndham Rewards Earner Premier Card', 'visa'),
    ('us-barclays-xbox', 'Barclays', 'Xbox Mastercard', 'mastercard'),
    ('us-becu-cash-back-visa', 'BECU', 'BECU Cash Back Visa Credit Card', 'visa'),
    ('us-becu-low-rate-visa', 'BECU', 'BECU Low Rate Visa Credit Card', 'visa'),
    ('us-bh-payboo-credit-card', 'Comenity Capital Bank (Bread Financial)', 'B&H Payboo Credit Card', 'other'),
    ('us-bmo-boost-secured', 'BMO', 'BMO Boost Secured Credit Card', 'mastercard'),
    ('us-bmo-cash-back', 'BMO', 'BMO Cash Back Credit Card', 'mastercard'),
    ('us-bmo-escape', 'BMO', 'BMO Escape Credit Card', 'mastercard'),
    ('us-bmo-platinum', 'BMO', 'BMO Platinum Credit Card', 'mastercard'),
    ('us-bmo-platinum-rewards', 'BMO', 'BMO Platinum Rewards Credit Card', 'mastercard'),
    ('us-bmo-premium-rewards', 'BMO', 'BMO Premium Rewards Credit Card', 'mastercard'),
    ('us-booking-com-genius-rewards-visa-signature', 'First Electronic Bank', 'Booking.com Genius Rewards Visa Signature Credit Card', 'visa'),
    ('us-brex-card', 'Brex', 'Brex Corporate Card', 'mastercard'),
    ('us-capital-one-key-rewards-visa', 'Capital One', 'Key Rewards Visa', 'visa'),
    ('us-capital-one-platinum', 'Capital One', 'Platinum Mastercard from Capital One', 'mastercard'),
    ('us-capital-one-platinum-secured', 'Capital One', 'Platinum Secured Credit Card from Capital One', 'visa'),
    ('us-capital-one-premier-dining-rewards', 'Capital One', 'Capital One Premier Dining Rewards', 'mastercard'),
    ('us-capital-one-quicksilver', 'Capital One', 'Quicksilver from Capital One', 'visa'),
    ('us-capital-one-quicksilver-cash-rewards', 'Capital One', 'Quicksilver Cash Back Rewards Card', 'visa'),
    ('us-capital-one-quicksilver-secured-cash-rewards', 'Capital One', 'Quicksilver Secured Rewards', 'visa'),
    ('us-capital-one-quicksilver-student-cash-rewards', 'Capital One', 'Quicksilver Rewards for Students', 'visa'),
    ('us-capital-one-quicksilverone', 'Capital One', 'QuicksilverOne Rewards', 'mastercard'),
    ('us-capital-one-rei-co-op-mastercard', 'Capital One', 'REI Co-op Mastercard', 'mastercard'),
    ('us-capital-one-savor', 'Capital One', 'Capital One Savor Cash Rewards Credit Card', 'mastercard'),
    ('us-capital-one-savor-student-cash-rewards', 'Capital One', 'Savor Rewards for Students', 'mastercard'),
    ('us-capital-one-savorone', 'Capital One', 'SavorOne Rewards', 'mastercard'),
    ('us-capital-one-spark-1-5-cash-select', 'Capital One', 'Spark 1.5% Cash Select', 'mastercard'),
    ('us-capital-one-spark-2-cash-plus', 'Capital One', 'Spark Cash Plus', 'mastercard'),
    ('us-capital-one-spark-cash', 'Capital One', 'Capital One Spark Cash for Business', 'visa'),
    ('us-capital-one-spark-miles-for-business', 'Capital One', 'Capital One Spark Miles for Business', 'visa'),
    ('us-capital-one-spark-miles-select-for-business', 'Capital One', 'Capital One Spark Miles Select for Business', 'visa'),
    ('us-capital-one-t-mobile-visa', 'Capital One', 'T-Mobile Visa', 'visa'),
    ('us-capital-one-venture', 'Capital One', 'Capital One Venture Rewards Credit Card', 'visa'),
    ('us-capital-one-venture-business', 'Capital One', 'Venture Business', 'visa'),
    ('us-capital-one-venture-x', 'Capital One', 'Capital One Venture X Rewards Credit Card', 'visa'),
    ('us-capital-one-venture-x-business', 'Capital One', 'Venture X Business', 'visa'),
    ('us-capital-one-ventureone', 'Capital One', 'Capital One VentureOne Rewards Credit Card', 'visa'),
    ('us-capital-one-ventureone-business', 'Capital One', 'VentureOne Business', 'visa'),
    ('us-cb2-visa-signature', 'First Bank & Trust', 'CB2 Visa Signature Credit Card', 'visa'),
    ('us-cfna-firestone-credit-card', 'Credit First National Association', 'Firestone Credit Card', 'other'),
    ('us-cfna-firestone-mastercard', 'Credit First National Association', 'Firestone Mastercard', 'mastercard'),
    ('us-chase-aer-lingus-signature', 'Chase', 'Aer Lingus Visa Signature Card', 'visa'),
    ('us-chase-aeroplan', 'Chase', 'Aeroplan Card', 'mastercard'),
    ('us-chase-amazon-prime', 'Chase', 'Prime Visa', 'visa'),
    ('us-chase-amazon-visa', 'Chase', 'Amazon Visa', 'visa'),
    ('us-chase-british-airways-signature', 'Chase', 'British Airways Credit Card', 'visa'),
    ('us-chase-disney', 'Chase', 'Disney Visa Card', 'visa'),
    ('us-chase-disney-inspire', 'Chase', 'Disney Inspire Visa Card', 'visa'),
    ('us-chase-disney-premier', 'Chase', 'Disney Premier Visa Card', 'visa'),
    ('us-chase-doordash-rewards-mastercard', 'Chase', 'DoorDash Rewards Mastercard', 'mastercard'),
    ('us-chase-fairmont', 'Chase', 'Fairmont Credit Card', 'visa'),
    ('us-chase-freedom-flex', 'Chase', 'Chase Freedom Flex® Credit Card', 'mastercard'),
    ('us-chase-freedom-rise', 'Chase', 'Chase Freedom Rise Credit Card', 'visa'),
    ('us-chase-freedom-unlimited', 'Chase', 'Chase Freedom Unlimited® Credit Card', 'visa'),
    ('us-chase-iberia-signature', 'Chase', 'Iberia Credit Card', 'visa'),
    ('us-chase-ihg-premier', 'Chase', 'IHG One Rewards Premier Credit Card', 'mastercard'),
    ('us-chase-ihg-premier-business', 'Chase', 'IHG One Rewards Premier Business Credit Card', 'mastercard'),
    ('us-chase-ihg-premier-select', 'Chase', 'IHG One Rewards Premier Select Credit Card', 'mastercard'),
    ('us-chase-ihg-rewards-club-select', 'Chase', 'IHG Rewards Club Select Credit Card', 'mastercard'),
    ('us-chase-ihg-traveler', 'Chase', 'IHG One Rewards Traveler Credit Card', 'mastercard'),
    ('us-chase-ink-business-cash', 'Chase', 'Ink Business Cash Credit Card', 'visa'),
    ('us-chase-ink-business-preferred', 'Chase', 'Chase Ink Business Preferred Credit Card', 'mastercard'),
    ('us-chase-ink-business-premier', 'Chase', 'Ink Business Premier Credit Card', 'visa'),
    ('us-chase-ink-business-unlimited', 'Chase', 'Ink Business Unlimited Credit Card: Cash Back', 'mastercard'),
    ('us-chase-ink-plus-business', 'Chase', 'Chase Ink Plus Business Card', 'visa'),
    ('us-chase-instacart-mastercard', 'Chase', 'Instacart Mastercard', 'mastercard'),
    ('us-chase-marriott-bonvoy-bold', 'Chase', 'Marriott Bonvoy Bold Credit Card', 'visa'),
    ('us-chase-marriott-bonvoy-boundless', 'Chase', 'Marriott Bonvoy Boundless® Credit Card', 'visa'),
    ('us-chase-marriott-bonvoy-bountiful', 'Chase', 'Marriott Bonvoy Bountiful Travel Credit Card', 'visa'),
    ('us-chase-ritz-carlton-rewards', 'Chase', 'Ritz-Carlton Rewards® Credit Card', 'visa'),
    ('us-chase-sapphire-preferred', 'Chase', 'Chase Sapphire Preferred® Card', 'visa'),
    ('us-chase-sapphire-reserve', 'Chase', 'Chase Sapphire Reserve® Credit Card', 'visa'),
    ('us-chase-sapphire-reserve-business', 'Chase', 'Sapphire Reserve for Business Credit Card', 'visa'),
    ('us-chase-slate-edge', 'Chase', 'Slate Edge Credit Card', 'visa'),
    ('us-chase-southwest-performance-business', 'Chase', 'Southwest Rapid Rewards Performance Business Credit Card', 'visa'),
    ('us-chase-southwest-plus', 'Chase', 'Southwest Rapid Rewards® Plus Credit Card', 'visa'),
    ('us-chase-southwest-premier', 'Chase', 'Southwest Rapid Rewards Premier Credit Card', 'visa'),
    ('us-chase-southwest-premier-business', 'Chase', 'Southwest Rapid Rewards Premier Business Credit Card', 'visa'),
    ('us-chase-southwest-priority', 'Chase', 'Southwest Rapid Rewards Priority Credit Card', 'visa'),
    ('us-chase-united-business', 'Chase', 'United Business Card', 'visa'),
    ('us-chase-united-club', 'Chase', 'United Club Infinite Card', 'visa'),
    ('us-chase-united-club-business', 'Chase', 'United Club Business Card', 'visa'),
    ('us-chase-united-explorer', 'Chase', 'United Explorer Credit Card', 'visa'),
    ('us-chase-united-gateway', 'Chase', 'United Gateway Card', 'visa'),
    ('us-chase-united-mileageplus-explorer-business', 'Chase', 'United MileagePlus Explorer Business Card', 'visa'),
    ('us-chase-united-quest', 'Chase', 'United Quest Card', 'visa'),
    ('us-chase-united-travelbank', 'Chase', 'United TravelBank Card', 'visa'),
    ('us-chase-world-of-hyatt', 'Chase', 'World of Hyatt Credit Card', 'visa'),
    ('us-chase-world-of-hyatt-business', 'Chase', 'World of Hyatt Business Credit Card', 'visa'),
    ('us-citi-aadvantage-business-world-elite', 'Citi', 'Citi® / AAdvantage Business™ World Elite Mastercard®', 'mastercard'),
    ('us-citi-aadvantage-executive', 'Citi', 'Citi® / AAdvantage® Executive World Legend Mastercard®', 'mastercard'),
    ('us-citi-aadvantage-globe', 'Citi', 'Citi® / AAdvantage® Globe™ Mastercard®', 'mastercard'),
    ('us-citi-aadvantage-mileup', 'Citi', 'American Airlines AAdvantage® MileUp® Card', 'mastercard'),
    ('us-citi-aadvantage-platinum-select-world-elite', 'Citi', 'Citi® / AAdvantage® Platinum Select® World Elite Mastercard®', 'mastercard'),
    ('us-citi-at-and-t-points-plus', 'Citi', 'AT&T Points Plus® Card from Citi', 'mastercard'),
    ('us-citi-costco-anywhere-visa-business', 'Citi', 'Costco Anywhere Visa Business Card by Citi', 'visa'),
    ('us-citi-costco-anywhere-visa-card-by-citi', 'Citi', 'Costco Anywhere Visa® Card by Citi', 'visa'),
    ('us-citi-custom-cash', 'Citi', 'Citi Custom Cash® Card', 'mastercard'),
    ('us-citi-diamond-preferred', 'Citi', 'Citi® Diamond Preferred® Credit Card', 'mastercard'),
    ('us-citi-double-cash', 'Citi', 'Citi Double Cash® Card', 'mastercard'),
    ('us-citi-home-depot-consumer', 'Citi', 'The Home Depot Consumer Credit Card', 'other'),
    ('us-citi-home-depot-pro-xtra', 'Citi', 'The Home Depot Pro Xtra Credit Card', 'other'),
    ('us-citi-macys-american-express', 'Citi', 'Macy''s American Express Card', 'amex'),
    ('us-citi-macys-credit-card', 'Citi', 'Macy''s Credit Card', 'other'),
    ('us-citi-my-best-buy-credit-card', 'Citi', 'My Best Buy Credit Card', 'other'),
    ('us-citi-my-best-buy-visa', 'Citi', 'My Best Buy Visa Card', 'visa'),
    ('us-citi-simplicity', 'Citi', 'Citi Simplicity® Credit Card', 'mastercard'),
    ('us-citi-strata', 'Citi', 'Citi Strata Card', 'mastercard'),
    ('us-citi-strata-elite', 'Citi', 'Citi Strata Elite℠', 'mastercard'),
    ('us-citi-strata-premier', 'Citi', 'Citi Strata Premier® Card', 'mastercard'),
    ('us-citi-thankyou-premier', 'Citi', 'Citi ThankYou Premier® Card', 'visa'),
    ('us-citizens-amp', 'Citizens', 'Citizens Amp Mastercard', 'mastercard'),
    ('us-citizens-spring', 'Citizens', 'Citizens Spring World Mastercard', 'mastercard'),
    ('us-citizens-summit', 'Citizens', 'Citizens Summit World Mastercard', 'mastercard'),
    ('us-citizens-summit-reserve', 'Citizens', 'Citizens Summit Reserve World Elite Mastercard', 'mastercard'),
    ('us-city-national-bank-crystal-visa-infinite', 'City National Bank', 'City National Bank Crystal Visa Infinite® Credit Card', 'visa'),
    ('us-city-national-bank-visa-crystal-commercial', 'City National Bank', 'City National Bank Visa Crystal Commercial Card', 'visa'),
    ('us-coinbase-one-card', 'First Electronic Bank', 'Coinbase One Card', 'amex'),
    ('us-column-bilt-blue', 'Column N.A.', 'Bilt Blue Card', 'mastercard'),
    ('us-column-bilt-obsidian', 'Column N.A.', 'Bilt Obsidian Card', 'mastercard'),
    ('us-column-bilt-palladium', 'Column N.A.', 'Bilt Palladium Card', 'mastercard'),
    ('us-comenity-aaa-daily-advantage', 'Comenity Capital Bank', 'AAA Daily Advantage Visa Signature® Credit Card', 'visa'),
    ('us-comenity-aaa-travel-advantage', 'Comenity Capital Bank', 'AAA Travel Advantage Visa Signature Credit Card', 'visa'),
    ('us-comenity-bread-cashback-amex', 'Comenity Capital Bank', 'Bread Cashback American Express Credit Card', 'amex'),
    ('us-comenity-bread-rewards-amex', 'Comenity Capital Bank', 'Bread Rewards American Express Credit Card', 'amex'),
    ('us-comenity-nfl-extra-points', 'Comenity Bank (Bread Financial)', 'NFL Extra Points Visa Credit Card', 'visa'),
    ('us-comenity-playstation-visa', 'Comenity Bank (Bread Financial)', 'PlayStation Visa Credit Card', 'visa'),
    ('us-comenity-virgin-america-premium-visa-signature', 'Comenity Bank (Bread Financial)', 'Virgin America Premium Visa Signature Card', 'visa'),
    ('us-comenity-virgin-america-visa-signature', 'Comenity Bank (Bread Financial)', 'Virgin America Visa Signature Card', 'visa'),
    ('us-crate-and-barrel-visa-signature', 'First Bank & Trust', 'Crate & Barrel Visa Signature Credit Card', 'visa'),
    ('us-credit-one-bank-amex-rebuilding-credit', 'Credit One Bank', 'Credit One Bank American Express Card for Rebuilding Credit', 'amex'),
    ('us-credit-one-bank-omni-rewards-amex', 'Credit One Bank', 'Credit One Bank Omni Rewards American Express Card', 'amex'),
    ('us-credit-one-bank-platinum-rewards-visa-no-annual-fee', 'Credit One Bank', 'Credit One Bank Platinum Rewards Visa with No Annual Fee', 'visa'),
    ('us-credit-one-bank-platinum-visa', 'Credit One Bank', 'Credit One Bank Platinum Visa', 'visa'),
    ('us-credit-one-bank-platinum-visa-rebuilding-credit', 'Credit One Bank', 'Credit One Bank Platinum Visa for Rebuilding Credit', 'visa'),
    ('us-credit-one-bank-platinum-x5-visa-signature', 'Credit One Bank', 'Credit One Bank Platinum X5 Visa Signature Card', 'visa'),
    ('us-credit-one-bank-premier-amex', 'Credit One Bank', 'Credit One Bank Premier American Express Card', 'amex'),
    ('us-credit-one-bank-secured', 'Credit One Bank', 'Credit One Bank Secured Card', 'visa'),
    ('us-credit-one-bank-vegas-golden-knights-visa', 'Credit One Bank', 'Credit One Bank Vegas Golden Knights Visa Card', 'visa'),
    ('us-credit-one-bank-wander-amex', 'Credit One Bank', 'Credit One Bank Wander American Express Card', 'amex'),
    ('us-cross-river-bank-upgrade-onecard-essentials', 'Cross River Bank', 'Upgrade OneCard Essentials', 'visa'),
    ('us-current-build-visa', 'Cross River Bank', 'Current Build Visa Credit Card', 'visa'),
    ('us-discover-it-cash-back', 'Discover', 'Discover it® Cash Back', 'discover'),
    ('us-discover-it-chrome', 'Discover', 'Discover it Chrome', 'discover'),
    ('us-discover-it-miles', 'Discover', 'Discover it Miles', 'discover'),
    ('us-discover-it-nhl', 'Discover', 'NHL Discover it Credit Card', 'discover'),
    ('us-discover-it-secured', 'Discover', 'Discover it Secured Cash Back Credit Card', 'discover'),
    ('us-discover-it-student-cash-back', 'Discover', 'Discover it Student Cash Back Card', 'discover'),
    ('us-discover-it-student-chrome', 'Discover', 'Discover it Student Chrome Credit Card', 'discover'),
    ('us-elan-fidelity-rewards-visa-signature', 'Elan Financial Services', 'Fidelity Rewards Visa Signature Card', 'visa'),
    ('us-fetch-american-express', 'First Electronic Bank', 'Fetch American Express Card', 'amex'),
    ('us-fifth-third-1-67-cash-back', 'Fifth Third Bank', 'Fifth Third 1.67% Cash/Back Card', 'mastercard'),
    ('us-fifth-third-preferred-cash-back', 'Fifth Third Bank', 'Fifth Third Preferred Cash/Back Card', 'mastercard'),
    ('us-fifth-third-secured', 'Fifth Third Bank', 'Fifth Third Secured Credit Card', 'mastercard'),
    ('us-first-ana-card-usa-plus', 'First National Bank of Omaha', 'ANA CARD U.S.A. Plus', 'visa'),
    ('us-first-avianca-lifemiles', 'First Electronic Bank', 'Avianca LifeMiles', 'amex'),
    ('us-first-avianca-lifemiles-elite', 'First Electronic Bank', 'Avianca LifeMiles Elite', 'amex'),
    ('us-first-cardless-qatar-infinite', 'First Electronic Bank', 'Qatar Airways Privilege Club Credit Card (Infinite)', 'visa'),
    ('us-first-cardless-qatar-signature', 'First Electronic Bank', 'Qatar Airways Privilege Club Credit Card (Signature)', 'visa'),
    ('us-first-latam-airlines', 'First Electronic Bank', 'LATAM Airlines Credit Card', 'mastercard'),
    ('us-first-latam-airlines-standard', 'First Electronic Bank', 'LATAM Airlines Mastercard', 'mastercard'),
    ('us-first-tech-choice-rewards-world-mastercard', 'First Tech Federal Credit Union', 'First Tech Choice Rewards World Mastercard', 'mastercard'),
    ('us-fnbo-amtrak-guest-rewards', 'First National Bank of Omaha', 'Amtrak Guest Rewards', 'mastercard'),
    ('us-fnbo-amtrak-guest-rewards-preferred', 'First National Bank of Omaha', 'Amtrak Guest Rewards Preferred', 'mastercard'),
    ('us-fnbo-best-western-rewards', 'First Bank & Trust', 'Best Western Rewards', 'visa'),
    ('us-fnbo-best-western-rewards-premium', 'First Bank & Trust', 'Best Western Rewards Premium', 'visa'),
    ('us-fnbo-bp-rewards-visa', 'FNBO', 'bp rewards Visa', 'visa'),
    ('us-fnbo-ducks-unlimited-rewards', 'FNBO', 'Ducks Unlimited Rewards Visa Card', 'visa'),
    ('us-fnbo-evergreen', 'FNBO', 'FNBO Evergreen Credit Card', 'visa'),
    ('us-fnbo-evergreen-business-edition', 'FNBO', 'FNBO Evergreen Business Edition Credit Card', 'mastercard'),
    ('us-harvard-alumni-world-mastercard', 'Harvard Federal Credit Union', 'Harvard Alumni World Mastercard', 'mastercard'),
    ('us-harvard-fcu-platinum-mastercard', 'Harvard Federal Credit Union', 'Harvard FCU Platinum Mastercard', 'mastercard'),
    ('us-harvard-fcu-platinum-rewards-mastercard', 'Harvard Federal Credit Union', 'Harvard FCU Platinum Rewards Mastercard', 'mastercard'),
    ('us-harvard-fcu-platinum-rewards-plus-mastercard', 'Harvard Federal Credit Union', 'Harvard FCU Platinum Rewards+ Mastercard', 'mastercard'),
    ('us-hsbc-elite', 'HSBC', 'HSBC Elite Credit Card', 'mastercard'),
    ('us-hsbc-premier-world', 'HSBC', 'HSBC Premier World Mastercard® Credit Card', 'mastercard'),
    ('us-hsbc-premier-world-elite', 'HSBC', 'HSBC Premier World Elite Mastercard® Credit Card', 'mastercard'),
    ('us-icbc-us-preferred-unionpay-gold', 'ICBC (USA) N.A.', 'ICBC Preferred UnionPay Gold Card', 'unionpay'),
    ('us-icbc-us-preferred-visa', 'ICBC (USA) N.A.', 'ICBC Preferred Visa Card', 'visa'),
    ('us-icbc-us-premier-unionpay-platinum', 'ICBC (USA) N.A.', 'ICBC Premier UnionPay Platinum Card', 'unionpay'),
    ('us-icbc-us-premier-visa-signature', 'ICBC (USA) N.A.', 'ICBC Premier Visa Signature Card', 'visa'),
    ('us-jal-usa-card', 'First National Bank of Omaha', 'JAL USA Card', 'mastercard'),
    ('us-kroger-rewards-world-elite-mastercard', 'First Bank & Trust', 'Kroger Family of Companies Rewards World Elite Mastercard', 'mastercard'),
    ('us-mercury-io-mastercard', 'Patriot Bank, N.A.', 'Mercury IO Mastercard', 'mastercard'),
    ('us-merrick-bank-ollo-everyday-rewards', 'Merrick Bank', 'Ollo Everyday Rewards Mastercard', 'mastercard'),
    ('us-merrick-bank-ollo-select-rewards', 'Merrick Bank', 'Ollo Select Rewards Mastercard', 'mastercard'),
    ('us-navy-federal-cashrewards', 'Navy Federal Credit Union', 'Navy Federal cashRewards Credit Card', 'visa'),
    ('us-navy-federal-cashrewards-plus', 'Navy Federal Credit Union', 'Navy Federal cashRewards Plus Credit Card', 'visa'),
    ('us-navy-federal-cashrewards-secured', 'Navy Federal Credit Union', 'Navy Federal cashRewards Secured Credit Card', 'visa'),
    ('us-navy-federal-flagship-premier-visa-signature', 'Navy Federal Credit Union', 'Navy Federal Flagship Premier Visa Signature Card', 'visa'),
    ('us-navy-federal-go-biz-rewards-mastercard', 'Navy Federal Credit Union', 'Navy Federal GO BIZ Rewards Mastercard', 'mastercard'),
    ('us-navy-federal-go-biz-rewards-visa', 'Navy Federal Credit Union', 'Navy Federal GO BIZ Rewards Visa Credit Card', 'visa'),
    ('us-navy-federal-go-rewards', 'Navy Federal Credit Union', 'Navy Federal GO REWARDS Credit Card', 'visa'),
    ('us-navy-federal-more-rewards-amex', 'Navy Federal Credit Union', 'Navy Federal More Rewards American Express Card', 'amex'),
    ('us-navy-federal-platinum', 'Navy Federal Credit Union', 'Navy Federal Platinum Credit Card', 'visa'),
    ('us-nibbles-rewards-world-mastercard', 'Lead Bank', 'Nibbles Rewards Credit Card', 'mastercard'),
    ('us-onepay-builder-card', 'Coastal Community Bank', 'OnePay Builder Card', 'mastercard'),
    ('us-opensky-launch-secured-visa', 'Capital Bank, N.A.', 'opensky Launch Secured Visa', 'visa'),
    ('us-opensky-plus-secured-visa', 'Capital Bank, N.A.', 'opensky Plus Secured Visa', 'visa'),
    ('us-opensky-secured-visa', 'Capital Bank, N.A.', 'opensky Secured Visa', 'visa'),
    ('us-penfed-gold-visa', 'PenFed Credit Union', 'PenFed Gold Visa® Card', 'visa'),
    ('us-penfed-pathfinder', 'PenFed', 'Pathfinder', 'visa'),
    ('us-penfed-platinum-rewards', 'PenFed', 'Platinum Rewards', 'visa'),
    ('us-penfed-power-cash-rewards', 'PenFed', 'Power Cash Rewards', 'visa'),
    ('us-penfed-premium-travel-rewards', 'PenFed Credit Union', 'PenFed Premium Travel Rewards American Express® Card', 'amex'),
    ('us-pnc-cash-rewards-visa', 'PNC Bank', 'PNC Cash Rewards Visa Credit Card', 'visa'),
    ('us-pnc-cash-rewards-visa-signature-business', 'PNC', 'PNC Cash Rewards Visa Signature Business Credit Card', 'visa'),
    ('us-pnc-cash-unlimited-visa', 'PNC Bank', 'PNC Cash Unlimited Visa Credit Card', 'visa'),
    ('us-regions-cash-rewards-visa-signature', 'Regions Bank', 'Regions Cash Rewards Visa Signature', 'visa'),
    ('us-revolut-secured-mastercard', 'Lead Bank', 'Revolut Secured Mastercard Credit Card', 'mastercard'),
    ('us-robinhood-gold-card', 'Coastal Community Bank', 'Robinhood Gold Card', 'visa'),
    ('us-shop-your-way-5321-visa', 'First Bank & Trust', 'Shop Your Way 5321 Visa Credit Card', 'visa'),
    ('us-sofi-everyday-cash-rewards', 'SoFi', 'SoFi Everyday Cash Rewards Credit Card', 'mastercard'),
    ('us-sofi-smart-card', 'SoFi', 'SoFi Smart Card', 'mastercard'),
    ('us-sofi-unlimited-2', 'SoFi', 'SoFi Unlimited 2% Credit Card', 'mastercard'),
    ('us-stanford-fcu-tech-card-visa-signature', 'Stanford Federal Credit Union', 'Stanford FCU Tech Card Visa Signature', 'visa'),
    ('us-step-visa-card', 'Evolve Bank & Trust', 'Step Visa Card', 'visa'),
    ('us-synchrony-amazon-prime-store', 'Synchrony', 'Amazon Prime Store Card', 'other'),
    ('us-synchrony-car-care-credit-card', 'Synchrony', 'Synchrony Car Care Credit Card', 'other'),
    ('us-synchrony-carecredit-credit-card', 'Synchrony', 'CareCredit Credit Card', 'other'),
    ('us-synchrony-cathay-pacific', 'Synchrony', 'Cathay Pacific Credit Card', 'mastercard'),
    ('us-synchrony-dicks-credit-card', 'Synchrony', 'DICK''S Credit Card', 'other'),
    ('us-synchrony-dicks-mastercard', 'Synchrony', 'DICK''S Mastercard', 'mastercard'),
    ('us-synchrony-floor-decor-credit-card', 'Synchrony', 'Floor & Decor Credit Card', 'other'),
    ('us-synchrony-floor-decor-pro-premier', 'Synchrony', 'Floor & Decor PRO Premier Credit Card', 'other'),
    ('us-synchrony-harbor-freight-credit-card', 'Synchrony', 'Harbor Freight Credit Card', 'other'),
    ('us-synchrony-home-credit-card', 'Synchrony', 'Synchrony HOME Credit Card', 'other'),
    ('us-synchrony-jcpenney-credit-card', 'Synchrony', 'JCPenney Credit Card', 'other'),
    ('us-synchrony-jcpenney-mastercard', 'Synchrony', 'JCPenney Mastercard', 'mastercard'),
    ('us-synchrony-mylowes-rewards-credit-card', 'Synchrony', 'MyLowe''s Rewards Credit Card', 'other'),
    ('us-synchrony-mywalgreens-credit-card', 'Synchrony', 'myWalgreens Credit Card', 'other'),
    ('us-synchrony-mywalgreens-mastercard', 'Synchrony', 'myWalgreens Mastercard', 'mastercard'),
    ('us-synchrony-paypal-cashback-mastercard', 'Synchrony', 'PayPal Cashback Mastercard', 'mastercard'),
    ('us-synchrony-premier-world-mastercard', 'Synchrony', 'Synchrony Premier World Mastercard', 'mastercard'),
    ('us-synchrony-sams-club-mastercard', 'Synchrony', 'Sam''s Club Mastercard', 'mastercard'),
    ('us-synchrony-sport-credit-card', 'Synchrony', 'Synchrony Sport Credit Card', 'other'),
    ('us-synchrony-sun-country-visa-signature', 'Synchrony', 'Sun Country Visa Signature® Card', 'visa'),
    ('us-synchrony-tjx-rewards-credit-card', 'Synchrony', 'TJX Rewards Credit Card', 'other'),
    ('us-synchrony-tjx-rewards-platinum-mastercard', 'Synchrony', 'TJX Rewards Platinum Mastercard', 'mastercard'),
    ('us-synchrony-venmo-credit-card', 'Synchrony', 'Venmo Credit Card', 'visa'),
    ('us-synchrony-verizon-visa', 'Synchrony', 'Verizon Visa® Card', 'visa'),
    ('us-synchrony-virgin-red-rewards', 'Synchrony', 'Virgin Red Rewards', 'mastercard'),
    ('us-synchrony-walmart-onepay-cashrewards', 'Synchrony', 'Walmart OnePay CashRewards', 'mastercard'),
    ('us-td-aeroplan-visa-signature', 'TD Bank', 'TD Aeroplan Visa Signature Credit Card', 'visa'),
    ('us-td-ameritrade-client-rewards', 'TD Bank', 'TD Ameritrade Client Rewards Card', 'visa'),
    ('us-td-business-solutions', 'TD Bank', 'TD Business Solutions Credit Card', 'visa'),
    ('us-td-cash', 'TD Bank', 'TD Cash Credit Card', 'visa'),
    ('us-td-double-up', 'TD Bank', 'TD Double Up Credit Card', 'visa'),
    ('us-td-first-class', 'TD Bank', 'TD First Class Visa Signature® Credit Card', 'visa'),
    ('us-td-target-circle-credit', 'TD Bank', 'Target Circle Credit Card', 'other'),
    ('us-td-target-mastercard', 'TD Bank', 'Target Mastercard', 'mastercard'),
    ('us-truist-enjoy-beyond', 'Truist', 'Truist Enjoy Beyond Credit Card', 'visa'),
    ('us-truist-enjoy-cash', 'Truist', 'Truist Enjoy Cash Credit Card', 'visa'),
    ('us-truist-enjoy-travel', 'Truist', 'Truist Enjoy Travel Credit Card', 'visa'),
    ('us-truist-future', 'Truist', 'Truist Future Credit Card', 'visa'),
    ('us-ubs-cash-rewards-visa-business', 'UBS Bank USA', 'UBS Cash Rewards Visa Business Card', 'visa'),
    ('us-ubs-visa-infinite', 'UBS Bank USA', 'UBS Visa Infinite Credit Card', 'visa'),
    ('us-ubs-visa-infinite-business', 'UBS Bank USA', 'UBS Visa Infinite Business Card', 'visa'),
    ('us-ubs-visa-signature', 'UBS Bank USA', 'UBS Visa Signature Credit Card', 'visa'),
    ('us-ubs-visa-signature-business', 'UBS Bank USA', 'UBS Visa Signature Business Card', 'visa'),
    ('us-ulta-beauty-rewards-credit-card', 'Comenity Capital Bank (Bread Financial)', 'Ulta Beauty Rewards Credit Card', 'other'),
    ('us-ulta-beauty-rewards-mastercard', 'Comenity Capital Bank (Bread Financial)', 'Ulta Beauty Rewards Mastercard', 'mastercard'),
    ('us-us-bank-aaa-cashback-visa-signature', 'U.S. Bank', 'AAA Cashback Visa Signature Card', 'visa'),
    ('us-us-bank-altitude-connect', 'U.S. Bank', 'U.S. Bank Altitude Connect Visa Signature Card', 'visa'),
    ('us-us-bank-altitude-go', 'U.S. Bank', 'U.S. Bank Altitude™ Go Visa Signature® Card', 'visa'),
    ('us-us-bank-altitude-reserve', 'U.S. Bank', 'U.S. Bank Altitude Reserve Visa Infinite Card', 'visa'),
    ('us-us-bank-amazon-business-card', 'U.S. Bank', 'Amazon Business World Elite Mastercard', 'mastercard'),
    ('us-us-bank-business-altitude-connect', 'U.S. Bank', 'U.S. Bank Business Altitude® Connect Visa Signature® Card', 'visa'),
    ('us-us-bank-business-altitude-power', 'U.S. Bank', 'U.S. Bank Business Altitude®™ Power Visa Signature® Card', 'visa'),
    ('us-us-bank-business-essentials', 'U.S. Bank', 'U.S. Bank Business Essentials Visa Card', 'visa'),
    ('us-us-bank-business-essentials-plus', 'U.S. Bank', 'U.S. Bank Business Essentials Plus Visa Signature Card', 'visa'),
    ('us-us-bank-business-leverage', 'U.S. Bank', 'U.S. Bank Business Leverage® Visa Signature® Card', 'visa'),
    ('us-us-bank-business-shield', 'U.S. Bank', 'U.S. Bank Business Shield Visa Card', 'visa'),
    ('us-us-bank-business-triple-cash-rewards', 'U.S. Bank', 'U.S. Bank Triple Cash Rewards Visa® Business Credit Card', 'visa'),
    ('us-us-bank-cash-plus', 'U.S. Bank', 'U.S. Bank Cash+® Visa Signature® Card', 'visa'),
    ('us-us-bank-club-carlson-business-rewards-visa', 'U.S. Bank', 'Club Carlson Business Rewards Visa', 'visa'),
    ('us-us-bank-club-carlson-platinum-rewards-visa', 'U.S. Bank', 'Club Carlson Platinum Rewards Visa', 'visa'),
    ('us-us-bank-club-carlson-premier-visa-signature', 'U.S. Bank', 'Club Carlson Premier Visa Signature', 'visa'),
    ('us-us-bank-club-carlson-rewards-visa', 'U.S. Bank', 'Club Carlson Rewards Visa', 'visa'),
    ('us-us-bank-club-carlson-rewards-visa-signature', 'U.S. Bank', 'Club Carlson Rewards Visa Signature', 'visa'),
    ('us-us-bank-edward-jones-business', 'U.S. Bank', 'Edward Jones Everyday Solutions Business World Elite Mastercard', 'mastercard'),
    ('us-us-bank-edward-jones-flex-balance', 'U.S. Bank', 'Edward Jones Everyday Solutions Flex Balance Mastercard', 'mastercard'),
    ('us-us-bank-edward-jones-triple-rewards', 'U.S. Bank', 'Edward Jones Everyday Solutions Triple Rewards World Elite Mastercard', 'mastercard'),
    ('us-us-bank-flexperks-travel-rewards', 'U.S. Bank', 'U.S. Bank FlexPerks Travel Rewards Visa Signature Card', 'visa'),
    ('us-us-bank-prime-business-card', 'U.S. Bank', 'Prime Business World Elite Mastercard', 'mastercard'),
    ('us-us-bank-shield-visa', 'U.S. Bank', 'U.S. Bank Shield® Visa® Card', 'visa'),
    ('us-us-bank-skypass', 'U.S. Bank', 'SKYPASS Visa Signature® Credit Card', 'visa'),
    ('us-us-bank-skypass-blue', 'U.S. Bank', 'SkyBlue SKYPASS Visa Credit Card', 'visa'),
    ('us-us-bank-skypass-business', 'U.S. Bank', 'SKYPASS Visa Signature Business Credit Card', 'visa'),
    ('us-us-bank-skypass-select', 'U.S. Bank', 'SKYPASS Select Visa Signature® Credit Card', 'visa'),
    ('us-us-bank-skypass-visa-classic', 'U.S. Bank', 'SKYPASS Visa Classic Card', 'visa'),
    ('us-us-bank-skypass-visa-secured', 'U.S. Bank', 'SKYPASS Visa Secured Card', 'visa'),
    ('us-us-bank-smartly', 'U.S. Bank', 'U.S. Bank Smartly™ Visa Signature® Card', 'visa'),
    ('us-us-bank-state-farm-business-cash-rewards', 'U.S. Bank', 'State Farm Business Cash Rewards Visa Signature Card', 'visa'),
    ('us-us-bank-state-farm-premier-cash-rewards', 'U.S. Bank', 'State Farm Premier Cash Rewards Visa Signature Card', 'visa'),
    ('us-usaa-cashback-rewards-plus-amex', 'USAA Federal Savings Bank', 'USAA Cashback Rewards Plus American Express', 'amex'),
    ('us-usaa-eagle-adapt-visa', 'USAA Federal Savings Bank', 'USAA Eagle Adapt Visa', 'visa'),
    ('us-usaa-eagle-ascend-amex', 'USAA Federal Savings Bank', 'USAA Eagle Ascend American Express', 'amex'),
    ('us-usaa-eagle-navigator-visa-signature', 'USAA Federal Savings Bank', 'USAA Eagle Navigator Visa Signature', 'visa'),
    ('us-usaa-preferred-cash-rewards-visa-signature', 'USAA Federal Savings Bank', 'USAA Preferred Cash Rewards Visa Signature', 'visa'),
    ('us-usaa-rate-advantage-visa-platinum', 'USAA Federal Savings Bank', 'USAA Rate Advantage Visa Platinum', 'visa'),
    ('us-usaa-rewards-visa-signature', 'USAA Federal Savings Bank', 'USAA Rewards Visa Signature', 'visa'),
    ('us-usaa-secured-amex', 'USAA Federal Savings Bank', 'USAA Secured American Express', 'amex'),
    ('us-web-bank-gemini', 'WebBank', 'Gemini Credit Card', 'mastercard'),
    ('us-wells-fargo-active-cash', 'Wells Fargo', 'Wells Fargo Active Cash® Credit Card', 'visa'),
    ('us-wells-fargo-attune', 'Wells Fargo', 'Wells Fargo Attune® Card', 'mastercard'),
    ('us-wells-fargo-autograph', 'Wells Fargo', 'Wells Fargo Autograph℠ Card', 'visa'),
    ('us-wells-fargo-autograph-journey', 'Wells Fargo', 'Wells Fargo Autograph Journey℠ Card', 'visa'),
    ('us-wells-fargo-bilt', 'Wells Fargo', 'Bilt Card', 'mastercard'),
    ('us-wells-fargo-business-platinum', 'Wells Fargo', 'Wells Fargo Business Platinum Credit Card', 'visa'),
    ('us-wells-fargo-cash-back-college', 'Wells Fargo', 'Wells Fargo Cash Back College Card', 'visa'),
    ('us-wells-fargo-cash-wise', 'Wells Fargo', 'Wells Fargo Cash Wise Visa® Card', 'visa'),
    ('us-wells-fargo-choice-privileges', 'Wells Fargo', 'Wells Fargo Choice Privileges Mastercard', 'mastercard'),
    ('us-wells-fargo-choice-privileges-select', 'Wells Fargo', 'Wells Fargo Choice Privileges Select Mastercard', 'mastercard'),
    ('us-wells-fargo-expedia-one-key', 'Wells Fargo', 'Expedia One Key', 'mastercard'),
    ('us-wells-fargo-propel', 'Wells Fargo', 'Wells Fargo Propel American Express® Card', 'amex'),
    ('us-wells-fargo-propel-365', 'Wells Fargo', 'Wells Fargo Propel 365 American Express® Card', 'amex'),
    ('us-wells-fargo-propel-world', 'Wells Fargo', 'Wells Fargo Propel World Elite American Express® Card', 'amex'),
    ('us-wells-fargo-reflect', 'Wells Fargo', 'Wells Fargo Reflect® Card', 'visa'),
    ('us-wells-fargo-rewards', 'Wells Fargo', 'Wells Fargo Rewards® Card', 'visa'),
    ('us-wells-fargo-signify-business-cash', 'Wells Fargo', 'Signify Business Cash Card', 'mastercard'),
    ('us-wells-fargo-visa-signature', 'Wells Fargo', 'Wells Fargo Visa Signature® Card', 'visa'),
    ('us-wescom-bruin-edge-visa', 'Wescom Financial', 'Wescom Bruin Edge Visa Credit Card', 'visa')
)
INSERT INTO revocred.card_reference_index
    (slug, issuer, name, network, source_url, source_captured_on, disclaimer, opencard_product_id)
SELECT 'opencard-' || p.product_id, p.issuer, p.name, p.network,
       'https://github.com/thedavidweng/opencard-db', '2026-11-09',
       'OpenCard DB community data (CC BY 4.0), captured 2026-11-09. Identity only; not issuer-verified. Rates depend on the cached feed.', p.product_id
FROM products p
WHERE NOT EXISTS (SELECT 1 FROM revocred.card_reference_index r WHERE r.opencard_product_id = p.product_id)
ON CONFLICT (lower(issuer), lower(name)) WHERE is_active
DO UPDATE SET opencard_product_id = EXCLUDED.opencard_product_id;

-- Existing owned cards were created from index rows with the row's exact
-- issuer and name, so an exact case-insensitive match recovers the link.
UPDATE revocred.catalog_cards c
SET reference_card_id = r.id
FROM revocred.card_reference_index r
WHERE c.owner_user_id IS NOT NULL
  AND c.data_kind = 'user_supplied'
  AND c.reference_card_id IS NULL
  AND r.is_active
  AND lower(r.issuer) = lower(c.issuer)
  AND lower(r.name) = lower(c.name);

-- The runtime role keeps its existing table-level INSERT/DELETE/SELECT on
-- catalog_cards (000008), which covers the new column. No UPDATE is granted:
-- the link is written only when the card is created.

-- +goose Down
ALTER TABLE revocred.catalog_cards
    DROP CONSTRAINT catalog_cards_reference_owned,
    DROP COLUMN reference_card_id;

DELETE FROM revocred.card_reference_index WHERE slug LIKE 'opencard-us-%';
ALTER TABLE revocred.card_reference_index DROP COLUMN opencard_product_id;
