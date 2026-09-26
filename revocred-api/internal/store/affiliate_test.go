package store

import (
	"context"
	"errors"
	"reflect"
	"sync"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/revocred/revocred-api/internal/affiliate"
	"github.com/revocred/revocred-api/internal/domain"
	"github.com/revocred/revocred-api/internal/recommendation"
)

func testAffiliateOffers(t *testing.T, ctx context.Context, admin *pgxpool.Pool, repo *Postgres, input domain.RecommendationInput, cards []domain.CatalogCard) {
	t.Helper()
	operator := NewPostgres(admin)
	var official int
	if err := admin.QueryRow(ctx, `SELECT count(*) FROM revocred.affiliate_offers WHERE kind='official'`).Scan(&official); err != nil || official != 14 {
		t.Fatalf("official links: %d %v", official, err)
	}
	// Isolate operator lifecycle fixtures from the shipped official links.
	if _, err := admin.Exec(ctx, `UPDATE revocred.affiliate_offers SET approved=false`); err != nil {
		t.Fatal(err)
	}
	before := recommendation.New().Recommend(input, cards)
	var version string
	if err := admin.QueryRow(ctx, `SELECT id::text FROM revocred.card_catalog_versions WHERE catalog_card_id=$1 ORDER BY created_at DESC,id DESC LIMIT 1`, cards[0].ID).Scan(&version); err != nil {
		t.Fatal(err)
	}
	p := affiliate.Publication{CardID: cards[0].ID, CatalogVersionID: version, Network: "Test partner", DestinationURL: "https://partner.example/apply?publisher=123", ReviewedBy: "Integration fixture", Approved: true, StartsAt: time.Now().Add(-time.Hour), EndsAt: time.Now().Add(time.Hour)}
	if _, err := repo.PublishOffer(ctx, p); err == nil {
		t.Fatal("runtime may publish offers")
	}
	id, err := operator.PublishOffer(ctx, p)
	if err != nil {
		t.Fatal(err)
	}
	offers, err := repo.ListOffers(ctx)
	if err != nil || len(offers) != 1 || offers[0].ID != id {
		t.Fatalf("offers=%+v err=%v", offers, err)
	}
	afterCards, err := repo.ListCatalog(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(before, recommendation.New().Recommend(input, afterCards)) {
		t.Fatal("commercial metadata changed recommendation or snapshot")
	}
	var wg sync.WaitGroup
	for i := 0; i < 12; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			url, err := repo.RecordOfferClick(ctx, id, "strategy")
			if err != nil || url != p.DestinationURL {
				t.Errorf("click %q %v", url, err)
			}
		}()
	}
	wg.Wait()
	rows, err := operator.OfferReport(ctx, time.Now().Add(-24*time.Hour))
	var clicks int64
	for _, row := range rows {
		if row.OfferID == id {
			clicks += row.Clicks
		}
	}
	if err != nil || clicks != 12 {
		t.Fatalf("lost click updates: %+v %v", rows, err)
	}
	if _, err = repo.RecordOfferClick(ctx, id, "untrusted"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("invalid placement: %v", err)
	}
	if err = repo.RevokeOffer(ctx, id); err == nil {
		t.Fatal("runtime may revoke offers")
	}
	if _, err = admin.Exec(ctx, `UPDATE revocred.affiliate_offers SET ends_at=now()-interval '1 second' WHERE id=$1`, id); err != nil {
		t.Fatal(err)
	}
	assertUnavailable := func() {
		t.Helper()
		offers, err := repo.ListOffers(ctx)
		if err != nil || len(offers) != 0 {
			t.Fatalf("inactive offer listed: %+v %v", offers, err)
		}
		if _, err = repo.RecordOfferClick(ctx, id, "report"); !errors.Is(err, ErrNotFound) {
			t.Fatalf("inactive offer redirected: %v", err)
		}
	}
	assertUnavailable()
	if _, err = admin.Exec(ctx, `UPDATE revocred.affiliate_offers SET starts_at=now()+interval '1 hour',ends_at=now()+interval '2 hours' WHERE id=$1`, id); err != nil {
		t.Fatal(err)
	}
	assertUnavailable()
	if _, err = admin.Exec(ctx, `UPDATE revocred.affiliate_offers SET starts_at=now()-interval '1 hour' WHERE id=$1`, id); err != nil {
		t.Fatal(err)
	}
	// A different card's version cannot be used as the reviewed snapshot.
	if _, err = admin.Exec(ctx, `UPDATE revocred.affiliate_offers SET catalog_version_id=(SELECT id FROM revocred.card_catalog_versions WHERE catalog_card_id<>$2 LIMIT 1) WHERE id=$1`, id, p.CardID); err != nil {
		t.Fatal(err)
	}
	assertUnavailable()
	if _, err = admin.Exec(ctx, `UPDATE revocred.affiliate_offers SET catalog_version_id=$2 WHERE id=$1`, id, version); err != nil {
		t.Fatal(err)
	}
	assertAvailable := func() {
		t.Helper()
		offers, err := repo.ListOffers(ctx)
		if err != nil || len(offers) != 1 {
			t.Fatalf("expected restored offer: %+v %v", offers, err)
		}
	}
	assertAvailable()
	for _, gate := range []struct{ disable, restore string }{
		{`UPDATE revocred.catalog_cards SET is_active=false WHERE id=$1`, `UPDATE revocred.catalog_cards SET is_active=true WHERE id=$1`},
		{`UPDATE revocred.catalog_cards SET data_kind='demo' WHERE id=$1`, `UPDATE revocred.catalog_cards SET data_kind='issuer_snapshot' WHERE id=$1`},
		{`UPDATE revocred.catalog_cards SET owner_user_id='11111111-1111-4111-8111-111111111111' WHERE id=$1`, `UPDATE revocred.catalog_cards SET owner_user_id=NULL WHERE id=$1`},
	} {
		if _, err = admin.Exec(ctx, gate.disable, p.CardID); err != nil {
			t.Fatal(err)
		}
		assertUnavailable()
		if _, err = admin.Exec(ctx, gate.restore, p.CardID); err != nil {
			t.Fatal(err)
		}
		assertAvailable()
	}
	var newer string
	err = admin.QueryRow(ctx, `INSERT INTO revocred.card_catalog_versions(catalog_card_id,source_id,dataset_version,summary,best_use,annual_fee_cents,reward_rates,benefits,transferable_points,travel_scope,minimum_credit_tier,rewards_type,first_year_bonus_estimate_cents,annual_benefit_estimate_cents)
SELECT catalog_card_id,source_id,dataset_version||'-offer-test',summary,best_use,annual_fee_cents,reward_rates,benefits,transferable_points,travel_scope,minimum_credit_tier,rewards_type,first_year_bonus_estimate_cents,annual_benefit_estimate_cents FROM revocred.card_catalog_versions WHERE id=$1 RETURNING id::text`, version).Scan(&newer)
	if err != nil {
		t.Fatal(err)
	}
	assertUnavailable()
	if _, err = admin.Exec(ctx, `DELETE FROM revocred.card_catalog_versions WHERE id=$1`, newer); err != nil {
		t.Fatal(err)
	}
	assertAvailable()
	if err = operator.RevokeOffer(ctx, id); err != nil {
		t.Fatal(err)
	}
	assertUnavailable()
	// Demo cards remain ineligible even if an operator tries to publish a link.
	p.CardID = "20000000-0000-4000-8000-000000000001"
	if err = admin.QueryRow(ctx, `SELECT id::text FROM revocred.card_catalog_versions WHERE catalog_card_id=$1 ORDER BY created_at DESC,id DESC LIMIT 1`, p.CardID).Scan(&p.CatalogVersionID); err != nil {
		t.Fatal(err)
	}
	if _, err = admin.Exec(ctx, `UPDATE revocred.catalog_cards SET is_active=true WHERE id=$1`, p.CardID); err != nil {
		t.Fatal(err)
	}
	if _, err = operator.PublishOffer(ctx, p); !errors.Is(err, ErrNotFound) {
		t.Fatalf("demo offer published: %v", err)
	}
	if _, err = admin.Exec(ctx, `UPDATE revocred.catalog_cards SET is_active=false WHERE id=$1`, p.CardID); err != nil {
		t.Fatal(err)
	}
	for _, role := range []string{"anon", "authenticated"} {
		var allowed bool
		if err = admin.QueryRow(ctx, `SELECT has_table_privilege($1,'revocred.affiliate_offers','SELECT')`, role).Scan(&allowed); err != nil || allowed {
			t.Fatalf("browser role %s has offer access: %v", role, err)
		}
	}
}
