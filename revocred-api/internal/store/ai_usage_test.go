package store

import (
	"context"
	"sync"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
)

func testAIAllowance(t *testing.T, ctx context.Context, admin *pgxpool.Pool, repo *Postgres) {
	const user = "33333333-3333-4333-8333-333333333329"
	if _, err := admin.Exec(ctx, `INSERT INTO auth.users(id,email) VALUES ($1,'ai-allowance@example.test')`, user); err != nil {
		t.Fatal(err)
	}
	// Parallel sends cannot exceed the free allowance.
	var wg sync.WaitGroup
	results := make(chan AIUse, 6)
	for range 6 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			use, err := repo.ReserveAIUse(ctx, user, 3, 60)
			if err != nil {
				t.Error(err)
			}
			results <- use
		}()
	}
	wg.Wait()
	close(results)
	allowed := 0
	var first AIUse
	for use := range results {
		if use.Allowed {
			allowed++
			first = use
		}
		if use.Subscriber || use.Limit != 3 {
			t.Fatalf("free member got %+v", use)
		}
	}
	if allowed != 3 {
		t.Fatalf("parallel sends allowed %d free AI answers, want 3", allowed)
	}
	// Clearing the chat does not hand the allowance back.
	if err := repo.ClearChat(ctx, user); err != nil {
		t.Fatal(err)
	}
	if use, err := repo.ReserveAIUse(ctx, user, 3, 60); err != nil || use.Allowed {
		t.Fatalf("clearing chat reset the allowance: %+v %v", use, err)
	}
	// A released reservation (basic fallback) is given back.
	if err := repo.ReleaseAIUse(ctx, user, first.ID); err != nil {
		t.Fatal(err)
	}
	if use, err := repo.ReserveAIUse(ctx, user, 3, 60); err != nil || !use.Allowed {
		t.Fatalf("released use not returned: %+v %v", use, err)
	}
	// An active entitlement gives the subscriber allowance; an expired one doesn't.
	if _, err := admin.Exec(ctx, `INSERT INTO revocred.ai_entitlements(user_id,source,expires_at) VALUES ($1,'manual',now()-interval '1 day')`, user); err != nil {
		t.Fatal(err)
	}
	if use, _ := repo.ReserveAIUse(ctx, user, 3, 60); use.Allowed || use.Subscriber {
		t.Fatalf("expired entitlement counted: %+v", use)
	}
	if _, err := admin.Exec(ctx, `UPDATE revocred.ai_entitlements SET expires_at=NULL WHERE user_id=$1`, user); err != nil {
		t.Fatal(err)
	}
	if use, err := repo.ReserveAIUse(ctx, user, 3, 60); err != nil || !use.Allowed || !use.Subscriber || use.Limit != 60 {
		t.Fatalf("subscriber allowance not applied: %+v %v", use, err)
	}
	// The runtime role cannot grant itself a subscription.
	if _, err := repo.pool.Exec(ctx, `INSERT INTO revocred.ai_entitlements(user_id,source) VALUES ($1,'manual') ON CONFLICT DO NOTHING`, user); err == nil {
		t.Fatal("runtime role wrote an AI entitlement")
	}
}
