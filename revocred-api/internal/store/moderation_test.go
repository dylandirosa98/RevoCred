package store

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/revocred/revocred-api/internal/moderation"
)

func testModerationWorkflow(t *testing.T, ctx context.Context, admin *pgxpool.Pool, repo *Postgres) {
	t.Helper()
	operator := NewPostgres(admin)
	const user = "55555555-5555-4555-8555-555555555532"
	if _, err := admin.Exec(ctx, `INSERT INTO auth.users(id,email) VALUES ($1,'mod-member@example.test')`, user); err != nil {
		t.Fatal(err)
	}

	// Seed two turns so we can verify turn context, redaction, and filters.
	turn1, err := repo.AppendChatExchange(ctx, user,
		"Earlier question about dining cards",
		"Earlier safe answer about dining multipliers.",
		[]byte(`[{"type":"paragraph","text":"Earlier safe answer about dining multipliers."}]`),
		"basic",
	)
	if err != nil {
		t.Fatal(err)
	}
	turn2, err := repo.AppendChatExchange(ctx, user,
		"My email is mod-member@example.test and card is 4111-2222-3333-4444, help me?",
		"Problematic reply mentioning Bearer secretTokenValue12345 and sk-live-abcdef1234567890",
		[]byte(`[{"type":"paragraph","text":"Problematic reply"}]`),
		"ai",
	)
	if err != nil {
		t.Fatal(err)
	}
	msg1 := turn1[1].ID
	msg2 := turn2[1].ID

	// Runtime can record normal thumbs-up and harmful reports without triage fields.
	if found, err := repo.ChatFeedback(ctx, user, msg1, "up", ""); err != nil || !found {
		t.Fatalf("thumbs-up feedback failed: found=%v err=%v", found, err)
	}
	if found, err := repo.ChatFeedback(ctx, user, msg2, "down", "Harmful or offensive: contact mod-member@example.test"); err != nil || !found {
		t.Fatalf("harmful report failed: found=%v err=%v", found, err)
	}

	// Least privilege: runtime role must not read, write, or directly delete moderation fields.
	for name, stmt := range map[string]string{
		"select status":        `SELECT status FROM revocred.chat_feedback`,
		"select reviewed_by":   `SELECT reviewed_by FROM revocred.chat_feedback`,
		"select reviewed_at":   `SELECT reviewed_at FROM revocred.chat_feedback`,
		"select note":          `SELECT resolution_note FROM revocred.chat_feedback`,
		"insert with status":   `INSERT INTO revocred.chat_feedback(message_id,user_id,rating,status) VALUES ('` + msg2 + `','` + user + `','down','dismissed')`,
		"update status":        `UPDATE revocred.chat_feedback SET status='dismissed' WHERE message_id='` + msg2 + `'`,
		"update reviewed_by":   `UPDATE revocred.chat_feedback SET reviewed_by='attacker' WHERE message_id='` + msg2 + `'`,
		"update reviewed_at":   `UPDATE revocred.chat_feedback SET reviewed_at=now() WHERE message_id='` + msg2 + `'`,
		"update note":          `UPDATE revocred.chat_feedback SET resolution_note='tampered' WHERE message_id='` + msg2 + `'`,
		"direct delete report": `DELETE FROM revocred.chat_feedback WHERE message_id='` + msg2 + `'`,
	} {
		if _, err := repo.pool.Exec(ctx, stmt); err == nil {
			t.Fatalf("runtime role unexpectedly allowed to %s", name)
		}
	}
	if _, err := repo.ListModerationReports(ctx, moderation.ListFilter{}); err == nil {
		t.Fatal("runtime role unexpectedly allowed to list moderation queue")
	}
	if _, err := repo.ResolveModerationReport(ctx, moderation.Resolution{MessageID: msg2, Status: moderation.StatusDismissed, ReviewedBy: "attacker"}); err == nil {
		t.Fatal("runtime role unexpectedly allowed to resolve moderation report")
	}

	// Browser roles must have zero access to revocred.chat_feedback.
	for _, role := range []string{"anon", "authenticated"} {
		var allowed bool
		if err := admin.QueryRow(ctx, `SELECT has_table_privilege($1,'revocred.chat_feedback','SELECT')`, role).Scan(&allowed); err != nil || allowed {
			t.Fatalf("browser role %s has chat_feedback SELECT privilege: %v", role, err)
		}
	}

	// Operator listing defaults to open negative reports and redacts sensitive text.
	openReports, err := operator.ListModerationReports(ctx, moderation.ListFilter{})
	if err != nil {
		t.Fatal(err)
	}
	if len(openReports) != 1 || openReports[0].MessageID != msg2 || openReports[0].Status != moderation.StatusOpen {
		t.Fatalf("unexpected open reports: %+v", openReports)
	}
	if strings.Contains(openReports[0].Reason, "mod-member@example.test") ||
		strings.Contains(openReports[0].PromptSnippet, "mod-member@example.test") ||
		strings.Contains(openReports[0].PromptSnippet, "4111-2222-3333-4444") ||
		strings.Contains(openReports[0].AssistantSnippet, "secretTokenValue12345") ||
		strings.Contains(openReports[0].AssistantSnippet, "sk-live-abcdef1234567890") {
		t.Fatalf("sensitive data leaked in summary: %+v", openReports[0])
	}

	// Filter by reason (case-insensitive substring, safe with % wildcard) and since.
	filtered, err := operator.ListModerationReports(ctx, moderation.ListFilter{Reason: "HARMFUL"})
	if err != nil || len(filtered) != 1 || filtered[0].MessageID != msg2 {
		t.Fatalf("reason filter failed: %+v %v", filtered, err)
	}
	wildcard, err := operator.ListModerationReports(ctx, moderation.ListFilter{Reason: "%"})
	if err != nil || len(wildcard) != 0 {
		t.Fatalf("literal percent matched wildcard: %+v %v", wildcard, err)
	}
	future := time.Now().UTC().Add(time.Hour)
	noneSince, err := operator.ListModerationReports(ctx, moderation.ListFilter{Since: &future})
	if err != nil || len(noneSince) != 0 {
		t.Fatalf("since filter returned older reports: %+v %v", noneSince, err)
	}

	// Show returns full redacted turn context including prior exchange.
	detail, err := operator.GetModerationReport(ctx, msg2)
	if err != nil {
		t.Fatal(err)
	}
	if detail.MessageID != msg2 || len(detail.ContextTurns) != 4 || !detail.ContextTurns[3].Reported {
		t.Fatalf("unexpected report detail: %+v", detail)
	}
	if strings.Contains(detail.UserPrompt, "mod-member@example.test") ||
		strings.Contains(detail.AssistantReply, "sk-live-abcdef1234567890") {
		t.Fatalf("sensitive data leaked in detail: %+v", detail)
	}

	// Database consistency constraint rejects resolving without reviewer identity.
	if _, err := admin.Exec(ctx, `UPDATE revocred.chat_feedback SET status='reviewed' WHERE message_id=$1`, msg2); err == nil {
		t.Fatal("check constraint allowed resolved row without reviewed_by/reviewed_at")
	}

	// Operator resolves the report.
	resolved, err := operator.ResolveModerationReport(ctx, moderation.Resolution{
		MessageID:  msg2,
		Status:     moderation.StatusActioned,
		ReviewedBy: "ops-reviewer",
		Note:       "Added guardrail test case.",
	})
	if err != nil {
		t.Fatal(err)
	}
	if resolved.Status != moderation.StatusActioned || resolved.ReviewedBy != "ops-reviewer" || resolved.ReviewedAt == nil || resolved.ResolutionNote != "Added guardrail test case." {
		t.Fatalf("unexpected resolved summary: %+v", resolved)
	}

	// Account export works under revocred_runtime and omits internal operator triage metadata.
	export, err := repo.ExportAccount(ctx, user)
	if err != nil {
		t.Fatal(err)
	}
	feedbackJSON := string(export["chat_feedback"])
	if !strings.Contains(feedbackJSON, msg2) {
		t.Fatalf("export missing user feedback: %s", feedbackJSON)
	}
	for _, internalField := range []string{"ops-reviewer", "Added guardrail test case.", `"reviewed_by"`, `"resolution_note"`, `"status"`} {
		if strings.Contains(feedbackJSON, internalField) {
			t.Fatalf("account export leaked internal moderation field %q: %s", internalField, feedbackJSON)
		}
	}

	// Re-submitting identical feedback leaves the resolved status intact.
	if found, err := repo.ChatFeedback(ctx, user, msg2, "down", "Harmful or offensive: contact mod-member@example.test"); err != nil || !found {
		t.Fatalf("idempotent feedback update failed: %v %v", found, err)
	}
	afterSame, err := operator.GetModerationReport(ctx, msg2)
	if err != nil || afterSame.Status != moderation.StatusActioned || afterSame.ReviewedBy != "ops-reviewer" {
		t.Fatalf("identical resubmission unexpectedly reopened report: %+v %v", afterSame, err)
	}

	// Changing rating or reason automatically reopens the report for operator triage.
	if found, err := repo.ChatFeedback(ctx, user, msg2, "down", "Harmful or offensive: additional safety concern"); err != nil || !found {
		t.Fatalf("edited feedback update failed: %v %v", found, err)
	}
	reopened, err := operator.GetModerationReport(ctx, msg2)
	if err != nil || reopened.Status != moderation.StatusOpen || reopened.ReviewedBy != "" || reopened.ReviewedAt != nil || reopened.ResolutionNote != "" {
		t.Fatalf("edited feedback did not reopen report cleanly: %+v %v", reopened, err)
	}

	// Unknown report UUID returns ErrNotFound.
	if _, err := operator.GetModerationReport(ctx, "99999999-9999-4999-8999-999999999999"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("expected ErrNotFound, got %v", err)
	}

	// Clearing chat cascades and removes feedback rows even without direct DELETE grant.
	if err := repo.ClearChat(ctx, user); err != nil {
		t.Fatalf("clear chat cascade failed: %v", err)
	}
	var remaining int
	if err := admin.QueryRow(ctx, `SELECT count(*) FROM revocred.chat_feedback WHERE user_id=$1`, user).Scan(&remaining); err != nil || remaining != 0 {
		t.Fatalf("clear chat left %d feedback rows: %v", remaining, err)
	}

	if err := repo.DeleteAccount(ctx, user); err != nil {
		t.Fatal(err)
	}
}
