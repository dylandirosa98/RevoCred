package main

import (
	"bytes"
	"context"
	"encoding/json"
	"strings"
	"testing"
	"time"

	"github.com/revocred/revocred-api/internal/moderation"
	"github.com/revocred/revocred-api/internal/store"
)

type fakeModerationStore struct {
	listFilter   moderation.ListFilter
	reports      []moderation.ReportSummary
	detail       moderation.ReportDetail
	resolved     moderation.Resolution
	resolveReply moderation.ReportSummary
	err          error
}

func (f *fakeModerationStore) ListModerationReports(_ context.Context, filter moderation.ListFilter) ([]moderation.ReportSummary, error) {
	f.listFilter = filter
	return f.reports, f.err
}

func (f *fakeModerationStore) GetModerationReport(_ context.Context, messageID string) (moderation.ReportDetail, error) {
	if f.err != nil {
		return moderation.ReportDetail{}, f.err
	}
	if f.detail.MessageID != messageID {
		return moderation.ReportDetail{}, store.ErrNotFound
	}
	return f.detail, nil
}

func (f *fakeModerationStore) ResolveModerationReport(_ context.Context, res moderation.Resolution) (moderation.ReportSummary, error) {
	f.resolved = res
	if f.err != nil {
		return moderation.ReportSummary{}, f.err
	}
	return f.resolveReply, nil
}

func TestCLIListTableAndJSON(t *testing.T) {
	now := time.Date(2026, 11, 23, 7, 0, 0, 0, time.UTC)
	msgID := "11111111-1111-4111-8111-111111111111"
	fake := &fakeModerationStore{
		reports: []moderation.ReportSummary{{
			MessageID:        msgID,
			Rating:           "down",
			Reason:           "Harmful or offensive",
			Status:           moderation.StatusOpen,
			Mode:             "ai",
			CreatedAt:        now,
			UpdatedAt:        now,
			PromptSnippet:    "How do I maximize dining rewards?",
			AssistantSnippet: "Flagged assistant answer snippet.",
		}},
	}
	env := func(key string) string {
		if key == "MODERATION_DATABASE_URL" {
			return "postgresql://operator:secret-pass@db.example.test:5432/postgres?sslmode=verify-full"
		}
		return ""
	}
	connect := func(context.Context, string, string) (moderationStore, func(), error) {
		return fake, func() {}, nil
	}

	var stdout, stderr bytes.Buffer
	if err := run([]string{"list", "-status", "open", "-reason", "harmful", "-since", "2026-11-20"}, env, connect, &stdout, &stderr); err != nil {
		t.Fatal(err)
	}
	if fake.listFilter.Status != moderation.StatusOpen || fake.listFilter.Reason != "harmful" || fake.listFilter.Since == nil {
		t.Fatalf("unexpected filter passed to store: %+v", fake.listFilter)
	}
	table := stdout.String()
	if !strings.Contains(table, "MESSAGE_ID") || !strings.Contains(table, msgID) || !strings.Contains(table, "Harmful or offensive") {
		t.Fatalf("unexpected table output:\n%s", table)
	}
	if strings.Contains(table, "secret-pass") {
		t.Fatalf("credential leaked into output:\n%s", table)
	}

	stdout.Reset()
	if err := run([]string{"list", "-json"}, env, connect, &stdout, &stderr); err != nil {
		t.Fatal(err)
	}
	var decoded []moderation.ReportSummary
	if err := json.Unmarshal(stdout.Bytes(), &decoded); err != nil {
		t.Fatalf("invalid json output: %v\n%s", err, stdout.String())
	}
	if len(decoded) != 1 || decoded[0].MessageID != msgID {
		t.Fatalf("unexpected decoded reports: %+v", decoded)
	}
}

func TestCLIShowAndResolve(t *testing.T) {
	now := time.Date(2026, 11, 23, 7, 15, 0, 0, time.UTC)
	msgID := "22222222-2222-4222-8222-222222222222"
	fake := &fakeModerationStore{
		detail: moderation.ReportDetail{
			MessageID:      msgID,
			Rating:         "down",
			Reason:         "Harmful or offensive",
			Status:         moderation.StatusOpen,
			Mode:           "ai",
			CreatedAt:      now,
			UpdatedAt:      now,
			UserPrompt:     "Prompt with [redacted-email]",
			AssistantReply: "Reported reply text",
			ContextTurns: []moderation.TurnMessage{
				{ID: "u1", Role: "user", Content: "Prompt with [redacted-email]", CreatedAt: now},
				{ID: msgID, Role: "assistant", Mode: "ai", Content: "Reported reply text", CreatedAt: now, Reported: true},
			},
		},
		resolveReply: moderation.ReportSummary{
			MessageID:      msgID,
			Status:         moderation.StatusActioned,
			ReviewedBy:     "ops-dylan",
			ReviewedAt:     &now,
			ResolutionNote: "Updated safety prompt.",
		},
	}
	env := func(key string) string {
		if key == "MODERATION_DATABASE_URL" {
			return "postgresql://operator:secret@db.example.test:5432/postgres"
		}
		return ""
	}
	connect := func(context.Context, string, string) (moderationStore, func(), error) {
		return fake, func() {}, nil
	}

	var stdout, stderr bytes.Buffer
	// Positional ID before -json must work cleanly.
	if err := run([]string{"show", msgID, "-json"}, env, connect, &stdout, &stderr); err != nil {
		t.Fatal(err)
	}
	var detail moderation.ReportDetail
	if err := json.Unmarshal(stdout.Bytes(), &detail); err != nil || detail.MessageID != msgID || len(detail.ContextTurns) != 2 {
		t.Fatalf("unexpected show json: %+v err=%v", detail, err)
	}

	stdout.Reset()
	if err := run([]string{"show", msgID}, env, connect, &stdout, &stderr); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(stdout.String(), "[REPORTED]") || !strings.Contains(stdout.String(), "Reported reply text") {
		t.Fatalf("unexpected show text:\n%s", stdout.String())
	}

	// Shorthand `actioned` subcommand with --by and --note.
	stdout.Reset()
	if err := run([]string{"actioned", msgID, "--by", "ops-dylan", "--note", "Updated safety prompt."}, env, connect, &stdout, &stderr); err != nil {
		t.Fatal(err)
	}
	if fake.resolved.MessageID != msgID || fake.resolved.Status != moderation.StatusActioned || fake.resolved.ReviewedBy != "ops-dylan" || fake.resolved.Note != "Updated safety prompt." {
		t.Fatalf("unexpected resolve payload: %+v", fake.resolved)
	}
	if !strings.Contains(stdout.String(), "status=actioned") || !strings.Contains(stdout.String(), "by=ops-dylan") {
		t.Fatalf("unexpected resolve output: %s", stdout.String())
	}

	// Explicit `resolve --status dismissed` with -json.
	fake.resolveReply.Status = moderation.StatusDismissed
	stdout.Reset()
	if err := run([]string{"resolve", "--status", "dismissed", "--by", "ops-dylan", "-json", msgID}, env, connect, &stdout, &stderr); err != nil {
		t.Fatal(err)
	}
	if fake.resolved.Status != moderation.StatusDismissed {
		t.Fatalf("expected dismissed, got %+v", fake.resolved)
	}
}

func TestCLIValidationAndMissingEnv(t *testing.T) {
	noEnv := func(string) string { return "" }
	unusedConnect := func(context.Context, string, string) (moderationStore, func(), error) {
		t.Fatal("should not connect on validation or missing env error")
		return nil, nil, nil
	}
	var stdout, stderr bytes.Buffer

	cases := [][]string{
		{},
		{"unknown"},
		{"list", "-status", "invalid"},
		{"list", "-since", "not-a-date"},
		{"show", "not-a-uuid"},
		{"reviewed", "11111111-1111-4111-8111-111111111111"}, // missing --by
		{"list"}, // missing MODERATION_DATABASE_URL
	}
	for _, args := range cases {
		stdout.Reset()
		stderr.Reset()
		if err := run(args, noEnv, unusedConnect, &stdout, &stderr); err == nil {
			t.Fatalf("expected error for args %v", args)
		}
	}
}
