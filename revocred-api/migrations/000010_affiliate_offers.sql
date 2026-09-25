-- +goose Up
-- Commercial metadata is deliberately separate from the recommendation catalog.
CREATE TABLE revocred.affiliate_offers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    catalog_card_id UUID NOT NULL REFERENCES revocred.catalog_cards(id),
    catalog_version_id UUID NOT NULL REFERENCES revocred.card_catalog_versions(id),
    network TEXT NOT NULL CHECK (length(network) BETWEEN 1 AND 100),
    destination_url TEXT NOT NULL CHECK (destination_url LIKE 'https://%' AND length(destination_url) <= 4096),
    approved BOOLEAN NOT NULL DEFAULT false,
    reviewed_by TEXT NOT NULL CHECK (length(reviewed_by) BETWEEN 1 AND 200),
    reviewed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ NOT NULL CHECK (ends_at > starts_at),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- Revoke an old offer before approving its replacement; no paid prioritization.
CREATE UNIQUE INDEX affiliate_one_approved_card ON revocred.affiliate_offers(catalog_card_id) WHERE approved;

-- Aggregate counts only: no user IDs, cookies, IP addresses or device identifiers.
CREATE TABLE revocred.affiliate_click_days (
    offer_id UUID NOT NULL REFERENCES revocred.affiliate_offers(id),
    day DATE NOT NULL,
    placement TEXT NOT NULL CHECK (placement IN ('recommendation','strategy','report')),
    clicks BIGINT NOT NULL DEFAULT 1 CHECK (clicks > 0),
    PRIMARY KEY (offer_id, day, placement)
);
REVOKE ALL ON revocred.affiliate_offers, revocred.affiliate_click_days FROM PUBLIC;
GRANT SELECT ON revocred.affiliate_offers, revocred.affiliate_click_days TO revocred_runtime;
GRANT INSERT, UPDATE ON revocred.affiliate_click_days TO revocred_runtime;

-- +goose Down
DROP TABLE revocred.affiliate_click_days;
DROP TABLE revocred.affiliate_offers;
