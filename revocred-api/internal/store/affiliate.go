package store

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/revocred/revocred-api/internal/affiliate"
)

// Reviewing a snapshot does not endorse future terms. A newly published
// catalog version automatically hides the offer until separately re-approved.
const availableOffers = `
SELECT o.* FROM revocred.affiliate_offers o
JOIN revocred.catalog_cards c ON c.id=o.catalog_card_id
JOIN LATERAL (SELECT id FROM revocred.card_catalog_versions WHERE catalog_card_id=c.id ORDER BY created_at DESC,id DESC LIMIT 1) v ON v.id=o.catalog_version_id
WHERE o.approved AND o.starts_at<=now() AND o.ends_at>now()
AND c.is_active AND c.owner_user_id IS NULL AND c.data_kind='issuer_snapshot'`

func (p *Postgres) ListOffers(ctx context.Context) ([]affiliate.Offer, error) {
	rows, err := p.pool.Query(ctx, `SELECT id::text,catalog_card_id::text,network,ends_at,destination_url,kind FROM (`+availableOffers+`) offers ORDER BY catalog_card_id`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	result := []affiliate.Offer{}
	for rows.Next() {
		var offer affiliate.Offer
		var destination string
		if err := rows.Scan(&offer.ID, &offer.CardID, &offer.Network, &offer.EndsAt, &destination, &offer.Kind); err != nil {
			return nil, err
		}
		if affiliate.ValidDestination(destination) {
			result = append(result, offer)
		}
	}
	return result, rows.Err()
}

func (p *Postgres) RecordOfferClick(ctx context.Context, id, placement string) (string, error) {
	if !affiliate.ValidPlacement(placement) {
		return "", ErrNotFound
	}
	tx, err := p.pool.Begin(ctx)
	if err != nil {
		return "", err
	}
	defer tx.Rollback(ctx)
	var destination string
	err = tx.QueryRow(ctx, `SELECT destination_url FROM (`+availableOffers+`) offers WHERE id=$1`, id).Scan(&destination)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", ErrNotFound
	}
	if err != nil {
		return "", err
	}
	if !affiliate.ValidDestination(destination) {
		return "", ErrNotFound
	}
	_, err = tx.Exec(ctx, `INSERT INTO revocred.affiliate_click_days(offer_id,day,placement) VALUES($1,(now() AT TIME ZONE 'UTC')::date,$2)
ON CONFLICT(offer_id,day,placement) DO UPDATE SET clicks=revocred.affiliate_click_days.clicks+1`, id, placement)
	if err != nil {
		return "", err
	}
	if err = tx.Commit(ctx); err != nil {
		return "", err
	}
	return destination, nil
}

// PublishOffer and RevokeOffer require an operator DB role, not the API login.
func (p *Postgres) PublishOffer(ctx context.Context, offer affiliate.Publication) (string, error) {
	if offer.Kind == "" {
		offer.Kind = "affiliate"
	}
	if err := offer.Validate(time.Now()); err != nil {
		return "", err
	}
	var id string
	err := p.pool.QueryRow(ctx, `INSERT INTO revocred.affiliate_offers(catalog_card_id,catalog_version_id,network,destination_url,reviewed_by,approved,starts_at,ends_at,kind)
SELECT c.id,v.id,$3,$4,$5,true,$6,$7,$8 FROM revocred.catalog_cards c
JOIN LATERAL (SELECT id FROM revocred.card_catalog_versions WHERE catalog_card_id=c.id ORDER BY created_at DESC,id DESC LIMIT 1) v ON v.id=$2
WHERE c.id=$1 AND c.is_active AND c.owner_user_id IS NULL AND c.data_kind='issuer_snapshot'
RETURNING id::text`, offer.CardID, offer.CatalogVersionID, offer.Network, offer.DestinationURL, offer.ReviewedBy, offer.StartsAt, offer.EndsAt, offer.Kind).Scan(&id)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", ErrNotFound
	}
	return id, err
}

func (p *Postgres) RevokeOffer(ctx context.Context, id string) error {
	result, err := p.pool.Exec(ctx, `UPDATE revocred.affiliate_offers SET approved=false WHERE id=$1`, id)
	if err == nil && result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return err
}

func (p *Postgres) OfferReport(ctx context.Context, since time.Time) ([]affiliate.ReportRow, error) {
	rows, err := p.pool.Query(ctx, `SELECT o.id::text,c.name,o.network,o.approved,o.ends_at,COALESCE(d.placement,'none'),COALESCE(sum(d.clicks),0)::bigint
FROM revocred.affiliate_offers o JOIN revocred.catalog_cards c ON c.id=o.catalog_card_id
LEFT JOIN revocred.affiliate_click_days d ON d.offer_id=o.id AND d.day >= $1::date
GROUP BY o.id,c.name,d.placement ORDER BY c.name,o.id,d.placement`, since.UTC().Format("2006-01-02"))
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	result := []affiliate.ReportRow{}
	for rows.Next() {
		var row affiliate.ReportRow
		if err := rows.Scan(&row.OfferID, &row.CardName, &row.Network, &row.Approved, &row.EndsAt, &row.Placement, &row.Clicks); err != nil {
			return nil, err
		}
		result = append(result, row)
	}
	return result, rows.Err()
}
