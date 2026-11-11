package store

import (
	"context"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

func testRevenueCatEntitlements(t *testing.T, ctx context.Context, admin *pgxpool.Pool, repo *Postgres) {
	const user, manual, missing = "44444444-4444-4444-8444-444444444430", "44444444-4444-4444-8444-444444444431", "44444444-4444-4444-8444-444444444432"
	if _, err := admin.Exec(ctx, `INSERT INTO auth.users(id,email) VALUES ($1,'rc@example.test'),($2,'rc-manual@example.test')`, user, manual); err != nil {
		t.Fatal(err)
	}
	now := time.Now().UTC().Truncate(time.Millisecond)
	apply := func(id, account string, at, expires time.Time) string {
		t.Helper()
		outcome, err := repo.ApplyRevenueCatEntitlement(ctx, EntitlementUpdate{EventID: id, UserID: account, EventAt: at, ExpiresAt: expires, ProductID: "com.revocred.app.revo_ai_monthly"})
		if err != nil {
			t.Fatalf("apply %s: %v", id, err)
		}
		return outcome
	}
	plan := func(account string) AIPlan {
		t.Helper()
		value, err := repo.AIPlan(ctx, account, 3, 60)
		if err != nil {
			t.Fatal(err)
		}
		return value
	}
	if got := plan(user); got.Subscriber || got.Limit != 3 || got.Used != 0 || got.NextResetAt != nil {
		t.Fatalf("new account plan: %+v", got)
	}
	if got := apply("evt-missing", missing, now, now.Add(time.Hour)); got != "unknown_user" {
		t.Fatalf("unknown account: %s", got)
	}
	month := now.AddDate(0, 1, 0)
	if got := apply("evt-purchase", user, now.Add(-time.Hour), month); got != "applied" {
		t.Fatalf("purchase: %s", got)
	}
	if got := plan(user); !got.Subscriber || got.Source != "revenuecat" || got.Limit != 60 || got.ExpiresAt == nil || !got.ExpiresAt.Equal(month) {
		t.Fatalf("subscriber plan: %+v", got)
	}
	if use, err := repo.ReserveAIUse(ctx, user, 3, 60); err != nil || !use.Subscriber || use.Limit != 60 {
		t.Fatalf("subscriber reservation: %+v %v", use, err)
	}
	if got := plan(user); got.Used != 1 || got.NextResetAt == nil {
		t.Fatalf("usage not reported: %+v", got)
	}
	// A replayed event changes nothing, even with different contents.
	if got := apply("evt-purchase", user, now, now); got != "duplicate" {
		t.Fatalf("replay: %s", got)
	}
	// Equal timestamps cannot replace state, even with a new event id.
	if got := apply("evt-equal", user, now.Add(-time.Hour), now); got != "stale" || !plan(user).Subscriber {
		t.Fatalf("equal timestamp changed state: %s", got)
	}
	// Expiration, then an older renewal arriving late, leaves access ended.
	if got := apply("evt-expire", user, now, now.Add(-time.Minute)); got != "applied" {
		t.Fatalf("expiration: %s", got)
	}
	if got := apply("evt-late-renewal", user, now.Add(-30*time.Minute), month); got != "stale" {
		t.Fatalf("out-of-order renewal: %s", got)
	}
	if got := plan(user); got.Subscriber || got.Limit != 3 {
		t.Fatalf("expired plan: %+v", got)
	}
	if got := apply("evt-resubscribe", user, now.Add(time.Minute), month); got != "applied" || !plan(user).Subscriber {
		t.Fatalf("resubscribe: %s", got)
	}
	// RevenueCat never overrides an operator's manual grant, including expiry.
	if _, err := admin.Exec(ctx, `INSERT INTO revocred.ai_entitlements(user_id,source,expires_at) VALUES ($1,'manual',NULL)`, manual); err != nil {
		t.Fatal(err)
	}
	if got := apply("evt-manual-expire", manual, now, now.Add(-time.Hour)); got != "manual" {
		t.Fatalf("manual grant: %s", got)
	}
	if got := plan(manual); !got.Subscriber || got.Source != "manual" || got.ExpiresAt != nil {
		t.Fatalf("manual grant changed: %+v", got)
	}
	// The write function refuses open-ended or implausible access.
	for name, update := range map[string]EntitlementUpdate{
		"far expiry":   {EventID: "evt-far", UserID: user, EventAt: now, ExpiresAt: now.AddDate(2, 0, 0)},
		"future event": {EventID: "evt-future", UserID: user, EventAt: now.Add(48 * time.Hour), ExpiresAt: month},
	} {
		if _, err := repo.ApplyRevenueCatEntitlement(ctx, update); err == nil {
			t.Fatalf("%s accepted", name)
		}
	}
	if _, err := repo.pool.Exec(ctx, `SELECT revocred.apply_revenuecat_entitlement('evt-null',$1,now(),NULL,NULL)`, user); err == nil {
		t.Fatal("open-ended entitlement accepted")
	}
	// The runtime role still cannot write entitlements or event records directly.
	for name, statement := range map[string]string{
		"insert entitlement": `INSERT INTO revocred.ai_entitlements(user_id,source) VALUES ('` + missing + `','manual')`,
		"update entitlement": `UPDATE revocred.ai_entitlements SET expires_at=NULL, source='manual'`,
		"delete entitlement": `DELETE FROM revocred.ai_entitlements`,
		"read events":        `SELECT count(*) FROM revocred.revenuecat_events`,
		"insert event":       `INSERT INTO revocred.revenuecat_events(id,user_id,event_at) VALUES ('x','` + user + `',now())`,
		"delete events":      `DELETE FROM revocred.revenuecat_events`,
	} {
		if _, err := repo.pool.Exec(ctx, statement); err == nil {
			t.Fatalf("runtime role may %s", name)
		}
	}
	// Browser-facing Supabase roles cannot call the write function.
	for _, role := range []string{"anon", "authenticated"} {
		tx, err := admin.Begin(ctx)
		if err != nil {
			t.Fatal(err)
		}
		if _, err = tx.Exec(ctx, "SET LOCAL ROLE "+role); err != nil {
			t.Fatal(err)
		}
		_, err = tx.Exec(ctx, `SELECT revocred.apply_revenuecat_entitlement('evt-browser',$1,now(),now()+interval '1 day','x')`, user)
		_ = tx.Rollback(ctx)
		if err == nil {
			t.Fatalf("%s may grant subscriptions", role)
		}
	}
	// Deleting the account removes its subscription records.
	if err := repo.DeleteAccount(ctx, user); err != nil {
		t.Fatal(err)
	}
	var left int
	if err := admin.QueryRow(ctx, `SELECT (SELECT count(*) FROM revocred.revenuecat_events WHERE user_id=$1)+(SELECT count(*) FROM revocred.ai_entitlements WHERE user_id=$1)`, user).Scan(&left); err != nil || left != 0 {
		t.Fatalf("account deletion left %d subscription rows: %v", left, err)
	}
}
