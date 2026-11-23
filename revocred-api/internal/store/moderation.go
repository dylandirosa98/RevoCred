package store

import (
	"context"
	"errors"
	"fmt"
	"slices"

	"github.com/jackc/pgx/v5"
	"github.com/revocred/revocred-api/internal/moderation"
)

const moderationContextTurnLimit = 6

// Operator-only moderation methods require an operator DB role, not the API
// runtime login. They never query auth.users or return email addresses.

// ListModerationReports returns privacy-minimized, redacted report summaries
// matching the filter, newest first.
func (p *Postgres) ListModerationReports(ctx context.Context, filter moderation.ListFilter) ([]moderation.ReportSummary, error) {
	normalized, err := filter.Normalize()
	if err != nil {
		return nil, err
	}
	statusParam := normalized.Status
	if statusParam == "all" {
		statusParam = ""
	}
	ratingParam := normalized.Rating
	if ratingParam == "all" {
		ratingParam = ""
	}

	rows, err := p.pool.Query(ctx, `
SELECT
    f.message_id::text,
    f.rating,
    COALESCE(f.reason, ''),
    f.status,
    COALESCE(m.mode, ''),
    f.created_at,
    f.updated_at,
    COALESCE(f.reviewed_by, ''),
    f.reviewed_at,
    COALESCE(f.resolution_note, ''),
    COALESCE(prompt.content, ''),
    m.content
FROM revocred.chat_feedback f
JOIN revocred.chat_messages m ON m.id = f.message_id
LEFT JOIN LATERAL (
    SELECT p.content
    FROM revocred.chat_messages p
    WHERE p.user_id = m.user_id
      AND p.role = 'user'
      AND p.sequence < m.sequence
    ORDER BY p.sequence DESC
    LIMIT 1
) prompt ON true
WHERE ($1 = '' OR f.status = $1)
  AND ($2 = '' OR f.rating = $2)
  AND ($3 = '' OR strpos(lower(COALESCE(f.reason, '')), lower($3)) > 0)
  AND ($4::timestamptz IS NULL OR f.created_at >= $4)
ORDER BY f.created_at DESC, f.message_id DESC
LIMIT $5`, statusParam, ratingParam, normalized.Reason, normalized.Since, normalized.Limit)
	if err != nil {
		return nil, fmt.Errorf("list moderation reports: %w", err)
	}
	defer rows.Close()

	result := make([]moderation.ReportSummary, 0)
	for rows.Next() {
		var (
			item             moderation.ReportSummary
			rawReason        string
			rawPrompt        string
			rawAssistantText string
		)
		if err := rows.Scan(
			&item.MessageID,
			&item.Rating,
			&rawReason,
			&item.Status,
			&item.Mode,
			&item.CreatedAt,
			&item.UpdatedAt,
			&item.ReviewedBy,
			&item.ReviewedAt,
			&item.ResolutionNote,
			&rawPrompt,
			&rawAssistantText,
		); err != nil {
			return nil, fmt.Errorf("scan moderation report: %w", err)
		}
		item.Reason = moderation.RedactSensitive(rawReason)
		item.PromptSnippet = moderation.Snippet(rawPrompt, moderation.SnippetMaxRunes)
		item.AssistantSnippet = moderation.Snippet(rawAssistantText, moderation.SnippetMaxRunes)
		result = append(result, item)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate moderation reports: %w", err)
	}
	return result, nil
}

// GetModerationReport loads a single reported reply with its full turn context
// (plus up to two prior exchanges for conversational context), with sensitive
// tokens and email addresses redacted.
func (p *Postgres) GetModerationReport(ctx context.Context, messageID string) (moderation.ReportDetail, error) {
	if !moderation.ValidUUID(messageID) {
		return moderation.ReportDetail{}, ErrNotFound
	}
	var (
		detail           moderation.ReportDetail
		userID           string
		messageSequence  int64
		rawReason        string
		rawPrompt        string
		rawAssistantText string
	)
	err := p.pool.QueryRow(ctx, `
SELECT
    f.message_id::text,
    f.user_id::text,
    m.sequence,
    f.rating,
    COALESCE(f.reason, ''),
    f.status,
    COALESCE(m.mode, ''),
    f.created_at,
    f.updated_at,
    COALESCE(f.reviewed_by, ''),
    f.reviewed_at,
    COALESCE(f.resolution_note, ''),
    COALESCE(prompt.content, ''),
    m.content
FROM revocred.chat_feedback f
JOIN revocred.chat_messages m ON m.id = f.message_id
LEFT JOIN LATERAL (
    SELECT p.content
    FROM revocred.chat_messages p
    WHERE p.user_id = m.user_id
      AND p.role = 'user'
      AND p.sequence < m.sequence
    ORDER BY p.sequence DESC
    LIMIT 1
) prompt ON true
WHERE f.message_id = $1::uuid`, messageID).Scan(
		&detail.MessageID,
		&userID,
		&messageSequence,
		&detail.Rating,
		&rawReason,
		&detail.Status,
		&detail.Mode,
		&detail.CreatedAt,
		&detail.UpdatedAt,
		&detail.ReviewedBy,
		&detail.ReviewedAt,
		&detail.ResolutionNote,
		&rawPrompt,
		&rawAssistantText,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return moderation.ReportDetail{}, ErrNotFound
	}
	if err != nil {
		return moderation.ReportDetail{}, fmt.Errorf("get moderation report: %w", err)
	}
	detail.Reason = moderation.RedactSensitive(rawReason)
	detail.UserPrompt = moderation.RedactSensitive(rawPrompt)
	detail.AssistantReply = moderation.RedactSensitive(rawAssistantText)

	rows, err := p.pool.Query(ctx, `
SELECT id::text, role, COALESCE(mode, ''), content, created_at
FROM revocred.chat_messages
WHERE user_id = $1::uuid
  AND sequence <= $2
ORDER BY sequence DESC
LIMIT $3`, userID, messageSequence, moderationContextTurnLimit)
	if err != nil {
		return moderation.ReportDetail{}, fmt.Errorf("list moderation turn context: %w", err)
	}
	defer rows.Close()

	turns := make([]moderation.TurnMessage, 0, moderationContextTurnLimit)
	for rows.Next() {
		var (
			turn       moderation.TurnMessage
			rawContent string
		)
		if err := rows.Scan(&turn.ID, &turn.Role, &turn.Mode, &rawContent, &turn.CreatedAt); err != nil {
			return moderation.ReportDetail{}, fmt.Errorf("scan moderation turn context: %w", err)
		}
		turn.Content = moderation.RedactSensitive(rawContent)
		turn.Reported = turn.ID == detail.MessageID
		turns = append(turns, turn)
	}
	if err := rows.Err(); err != nil {
		return moderation.ReportDetail{}, fmt.Errorf("iterate moderation turn context: %w", err)
	}
	slices.Reverse(turns)
	detail.ContextTurns = turns
	return detail, nil
}

// ResolveModerationReport records an operator triage status, reviewer identity,
// timestamp, and optional resolution note on one feedback row.
func (p *Postgres) ResolveModerationReport(ctx context.Context, res moderation.Resolution) (moderation.ReportSummary, error) {
	normalized, err := res.Normalize()
	if err != nil {
		return moderation.ReportSummary{}, err
	}
	var (
		out       moderation.ReportSummary
		rawReason string
	)
	err = p.pool.QueryRow(ctx, `
UPDATE revocred.chat_feedback
SET status = $2,
    reviewed_by = $3,
    reviewed_at = now(),
    resolution_note = NULLIF($4, ''),
    updated_at = now()
WHERE message_id = $1::uuid
RETURNING message_id::text, rating, COALESCE(reason, ''), status, created_at, updated_at,
          COALESCE(reviewed_by, ''), reviewed_at, COALESCE(resolution_note, '')`,
		normalized.MessageID, normalized.Status, normalized.ReviewedBy, normalized.Note,
	).Scan(
		&out.MessageID,
		&out.Rating,
		&rawReason,
		&out.Status,
		&out.CreatedAt,
		&out.UpdatedAt,
		&out.ReviewedBy,
		&out.ReviewedAt,
		&out.ResolutionNote,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return moderation.ReportSummary{}, ErrNotFound
	}
	if err != nil {
		return moderation.ReportSummary{}, fmt.Errorf("resolve moderation report: %w", err)
	}
	out.Reason = moderation.RedactSensitive(rawReason)
	return out, nil
}
