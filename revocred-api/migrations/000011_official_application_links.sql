-- +goose Up
ALTER TABLE revocred.affiliate_offers ADD COLUMN kind TEXT NOT NULL DEFAULT 'affiliate' CHECK (kind IN ('official','affiliate'));
ALTER TABLE revocred.affiliate_click_days DROP CONSTRAINT affiliate_click_days_placement_check;
ALTER TABLE revocred.affiliate_click_days ADD CONSTRAINT affiliate_click_days_placement_check CHECK (placement IN ('recommendation','strategy','report','card_details'));

-- Official issuer pages/application paths checked 2026-09-25. This verifies
-- navigation, not a fresh certification of every modeled term or approval.
-- No RevoCred referral ID or affiliate parameter. Review links within 90 days.
WITH links(slug,url) AS (VALUES
 ('freedom-rise','https://creditcards.chase.com/cash-back-credit-cards/freedom/rise'),
 ('freedom-flex','https://creditcards.chase.com/cash-back-credit-cards/freedom/flex'),
 ('freedom-unlimited','https://creditcards.chase.com/cash-back-credit-cards/freedom/unlimited'),
 ('sapphire-preferred','https://creditcards.chase.com/rewards-credit-cards/sapphire/preferred'),
 ('sapphire-reserve','https://creditcards.chase.com/rewards-credit-cards/sapphire/reserve'),
 ('savor-for-students','https://www.capitalone.com/apply/credit-cards/?marketableOfferId=48308'),
 ('quicksilver','https://www.capitalone.com/apply/credit-cards/?marketableOfferId=48321'),
 ('savorone','https://www.capitalone.com/apply/credit-cards/?marketableOfferId=47672'),
 ('venture-x','https://www.capitalone.com/apply/credit-cards/?marketableOfferId=48137'),
 ('amex-gold','https://www.americanexpress.com/us/credit-cards/card/gold-card/'),
 ('amex-platinum','https://www.americanexpress.com/us/credit-cards/card/platinum/'),
 ('double-cash','https://www.citi.com/credit-cards/citi-double-cash-credit-card'),
 ('strata','https://www.citi.com/credit-cards/citi-strata-credit-card'),
 ('strata-elite','https://www.citi.com/credit-cards/citi-strata-elite-credit-card')
)
INSERT INTO revocred.affiliate_offers(catalog_card_id,catalog_version_id,network,destination_url,approved,reviewed_by,reviewed_at,starts_at,ends_at,kind)
SELECT c.id,v.id,'Issuer direct',links.url,true,'Issuer navigation check; see docs/official-application-links.md','2026-09-25T00:00:00Z','2026-09-25T00:00:00Z','2026-12-25T00:00:00Z','official'
FROM links JOIN revocred.catalog_cards c USING(slug)
JOIN LATERAL (SELECT id FROM revocred.card_catalog_versions WHERE catalog_card_id=c.id ORDER BY created_at DESC,id DESC LIMIT 1) v ON true
WHERE c.is_active AND c.owner_user_id IS NULL AND c.data_kind='issuer_snapshot'
AND NOT EXISTS(SELECT 1 FROM revocred.affiliate_offers o WHERE o.catalog_card_id=c.id AND o.approved);

-- +goose Down
-- Keep historical click counts and disclosure kinds intact.
-- +goose StatementBegin
DO $$ BEGIN RAISE EXCEPTION 'Official-link disclosure migration is forward-only; use a corrective migration'; END $$;
-- +goose StatementEnd
