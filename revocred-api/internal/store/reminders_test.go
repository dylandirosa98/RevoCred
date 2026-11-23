package store

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/revocred/revocred-api/internal/domain"
)

func testReminders(t *testing.T, ctx context.Context, admin, runtimePool *pgxpool.Pool, repo *Postgres, cards []domain.CatalogCard) {
	u1 := "33333333-3333-4333-8333-333333333331"
	u2 := "33333333-3333-4333-8333-333333333332"
	if _, err := admin.Exec(ctx, `INSERT INTO auth.users(id,email) VALUES ($1,'r1@example.test'),($2,'r2@example.test')`, u1, u2); err != nil {
		t.Fatal(err)
	}
	defer func() {
		_, _ = admin.Exec(ctx, `DELETE FROM auth.users WHERE id IN ($1, $2)`, u1, u2)
	}()

	// Browser-facing Supabase roles must never have privileges on reminder_states.
	for _, role := range []string{"anon", "authenticated"} {
		for _, priv := range []string{"SELECT", "INSERT", "UPDATE", "DELETE"} {
			var allowed bool
			if err := admin.QueryRow(ctx, `SELECT has_table_privilege($1, 'revocred.reminder_states', $2)`, role, priv).Scan(&allowed); err != nil {
				t.Fatal(err)
			}
			if allowed {
				t.Fatalf("role %s unexpectedly has %s on revocred.reminder_states", role, priv)
			}
		}
	}

	// Add a wallet card for u1 and test renewal_month updates + cross-user isolation.
	walletCard, err := repo.CreateWalletCard(ctx, u1, domain.CreateWalletCard{
		CatalogCardID: cards[0].ID,
		Status:        "active",
	})
	if err != nil {
		t.Fatal(err)
	}
	if walletCard.RenewalMonth != nil {
		t.Fatalf("expected nil renewal_month initially, got %v", *walletCard.RenewalMonth)
	}

	march := 3
	updated, err := repo.UpdateWalletRenewalMonth(ctx, u1, walletCard.ID, &march)
	if err != nil {
		t.Fatal(err)
	}
	if updated.RenewalMonth == nil || *updated.RenewalMonth != 3 {
		t.Fatalf("expected renewal_month=3, got %+v", updated)
	}

	// Cross-user update must fail with ErrNotFound.
	oct := 10
	if _, err = repo.UpdateWalletRenewalMonth(ctx, u2, walletCard.ID, &oct); !errors.Is(err, ErrNotFound) {
		t.Fatalf("expected ErrNotFound for cross-user renewal update, got %v", err)
	}

	// ListWallet returns renewal_month.
	list, err := repo.ListWallet(ctx, u1)
	if err != nil || len(list) != 1 || list[0].RenewalMonth == nil || *list[0].RenewalMonth != 3 {
		t.Fatalf("ListWallet missing renewal_month: %+v %v", list, err)
	}

	// Clear renewal_month back to NULL.
	cleared, err := repo.UpdateWalletRenewalMonth(ctx, u1, walletCard.ID, nil)
	if err != nil || cleared.RenewalMonth != nil {
		t.Fatalf("expected cleared renewal_month, got %+v %v", cleared, err)
	}

	// DB check constraint rejects out-of-range renewal_month.
	if _, err = runtimePool.Exec(ctx, `UPDATE revocred.wallet_cards SET renewal_month = 13 WHERE id = $1`, walletCard.ID); err == nil {
		t.Fatal("database accepted renewal_month=13")
	}

	// Reminder state CRUD + check constraint + isolation.
	until := time.Now().UTC().Add(7 * 24 * time.Hour).Truncate(time.Second)
	if err = repo.UpsertReminderState(ctx, u1, "credit.amex-gold.uber.2026-11", "completed", nil); err != nil {
		t.Fatal(err)
	}
	if err = repo.UpsertReminderState(ctx, u1, "annual-fee.test.2026-12", "snoozed", &until); err != nil {
		t.Fatal(err)
	}
	// Snoozed without snoozed_until must fail check constraint.
	if err = repo.UpsertReminderState(ctx, u1, "bad.snooze", "snoozed", nil); err == nil {
		t.Fatal("database accepted snoozed reminder without snoozed_until")
	}

	states1, err := repo.ListReminderStates(ctx, u1)
	if err != nil || len(states1) != 2 {
		t.Fatalf("unexpected u1 states: %+v %v", states1, err)
	}
	if states1["credit.amex-gold.uber.2026-11"].Status != "completed" {
		t.Fatalf("unexpected completed state: %+v", states1["credit.amex-gold.uber.2026-11"])
	}
	if states1["annual-fee.test.2026-12"].Status != "snoozed" || states1["annual-fee.test.2026-12"].SnoozedUntil == nil {
		t.Fatalf("unexpected snoozed state: %+v", states1["annual-fee.test.2026-12"])
	}

	// User 2 must never see user 1's reminder states.
	states2, err := repo.ListReminderStates(ctx, u2)
	if err != nil || len(states2) != 0 {
		t.Fatalf("u2 saw leaked reminder states: %+v %v", states2, err)
	}

	// ExportAccount includes reminder_states for u1 and does not leak to u2.
	exp1, err := repo.ExportAccount(ctx, u1)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(exp1["reminder_states"]), "credit.amex-gold.uber.2026-11") {
		t.Fatalf("export missing reminder_states: %s", exp1["reminder_states"])
	}
	exp2, err := repo.ExportAccount(ctx, u2)
	if err != nil {
		t.Fatal(err)
	}
	if string(exp2["reminder_states"]) != "[]" {
		t.Fatalf("u2 export leaked reminder_states: %s", exp2["reminder_states"])
	}

	// DeleteReminderState restores a reminder.
	if err = repo.DeleteReminderState(ctx, u1, "annual-fee.test.2026-12"); err != nil {
		t.Fatal(err)
	}
	states1, err = repo.ListReminderStates(ctx, u1)
	if err != nil || len(states1) != 1 {
		t.Fatalf("expected 1 state after delete, got %+v %v", states1, err)
	}

	// Account deletion must cascade-delete all reminder_states rows.
	if err = repo.DeleteAccount(ctx, u1); err != nil {
		t.Fatal(err)
	}
	var remaining int
	if err = admin.QueryRow(ctx, `SELECT count(*) FROM revocred.reminder_states WHERE user_id = $1`, u1).Scan(&remaining); err != nil || remaining != 0 {
		t.Fatalf("reminder_states survived account deletion: %d %v", remaining, err)
	}
	if err = repo.DeleteAccount(ctx, u2); err != nil {
		t.Fatal(err)
	}
}
