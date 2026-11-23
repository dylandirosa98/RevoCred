// Package moderation holds operator-only triage models, redaction helpers,
// and optional privacy-minimized webhook alerts for reported REVO replies.
package moderation

import (
	"errors"
	"regexp"
	"strings"
	"time"
	"unicode/utf8"
)

const (
	StatusOpen      = "open"
	StatusReviewed  = "reviewed"
	StatusActioned  = "actioned"
	StatusDismissed = "dismissed"

	DefaultListLimit = 50
	MaxListLimit     = 500
	MaxReviewedBy    = 200
	MaxNoteLength    = 2000
	SnippetMaxRunes  = 120
)

var uuidPattern = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)

func ValidUUID(value string) bool {
	return uuidPattern.MatchString(strings.TrimSpace(value))
}

func ValidStatus(status string) bool {
	switch status {
	case StatusOpen, StatusReviewed, StatusActioned, StatusDismissed:
		return true
	default:
		return false
	}
}

func ValidResolutionStatus(status string) bool {
	switch status {
	case StatusReviewed, StatusActioned, StatusDismissed:
		return true
	default:
		return false
	}
}

// ListFilter selects feedback rows for out-of-band operator review.
type ListFilter struct {
	// Status is open, reviewed, actioned, dismissed, or all (empty defaults to open).
	Status string
	// Rating is down, up, or all (empty defaults to down).
	Rating string
	// Reason filters reports whose reason contains this case-insensitive text.
	Reason string
	// Since restricts results to reports created at or after this UTC instant.
	Since *time.Time
	// Limit bounds returned rows (defaults to DefaultListLimit, capped at MaxListLimit).
	Limit int
}

// Normalize validates and normalizes filter defaults for querying.
func (f ListFilter) Normalize() (ListFilter, error) {
	out := f
	out.Status = strings.ToLower(strings.TrimSpace(out.Status))
	if out.Status == "" {
		out.Status = StatusOpen
	}
	if out.Status != "all" && !ValidStatus(out.Status) {
		return ListFilter{}, errors.New("status must be open, reviewed, actioned, dismissed, or all")
	}

	out.Rating = strings.ToLower(strings.TrimSpace(out.Rating))
	if out.Rating == "" {
		out.Rating = "down"
	}
	if out.Rating != "all" && out.Rating != "down" && out.Rating != "up" {
		return ListFilter{}, errors.New("rating must be down, up, or all")
	}

	out.Reason = strings.TrimSpace(out.Reason)
	if utf8.RuneCountInString(out.Reason) > 200 {
		return ListFilter{}, errors.New("reason filter must be 200 characters or fewer")
	}

	if out.Since != nil {
		utc := out.Since.UTC()
		out.Since = &utc
	}

	if out.Limit == 0 {
		out.Limit = DefaultListLimit
	}
	if out.Limit < 1 || out.Limit > MaxListLimit {
		return ListFilter{}, errors.New("limit must be between 1 and 500")
	}
	return out, nil
}

// Resolution records an operator triage decision on one reported message.
type Resolution struct {
	MessageID  string `json:"message_id"`
	Status     string `json:"status"`
	ReviewedBy string `json:"reviewed_by"`
	Note       string `json:"resolution_note,omitempty"`
}

func (r Resolution) Normalize() (Resolution, error) {
	out := Resolution{
		MessageID:  strings.TrimSpace(r.MessageID),
		Status:     strings.ToLower(strings.TrimSpace(r.Status)),
		ReviewedBy: strings.TrimSpace(r.ReviewedBy),
		Note:       strings.TrimSpace(r.Note),
	}
	if !ValidUUID(out.MessageID) {
		return Resolution{}, errors.New("message_id must be a valid UUID")
	}
	if !ValidResolutionStatus(out.Status) {
		return Resolution{}, errors.New("status must be reviewed, actioned, or dismissed")
	}
	if out.ReviewedBy == "" || utf8.RuneCountInString(out.ReviewedBy) > MaxReviewedBy || strings.ContainsAny(out.ReviewedBy, "\r\n\t") {
		return Resolution{}, errors.New("reviewed_by (--by) is required, single-line, and at most 200 characters")
	}
	if utf8.RuneCountInString(out.Note) > MaxNoteLength {
		return Resolution{}, errors.New("resolution note (--note) must be 2000 characters or fewer")
	}
	return out, nil
}

// ReportSummary is a privacy-minimized queue row for operator listing.
// It intentionally excludes user emails and account identifiers.
type ReportSummary struct {
	MessageID        string     `json:"message_id"`
	Rating           string     `json:"rating"`
	Reason           string     `json:"reason"`
	Status           string     `json:"status"`
	Mode             string     `json:"mode,omitempty"`
	CreatedAt        time.Time  `json:"created_at"`
	UpdatedAt        time.Time  `json:"updated_at"`
	ReviewedBy       string     `json:"reviewed_by,omitempty"`
	ReviewedAt       *time.Time `json:"reviewed_at,omitempty"`
	ResolutionNote   string     `json:"resolution_note,omitempty"`
	PromptSnippet    string     `json:"prompt_snippet"`
	AssistantSnippet string     `json:"assistant_snippet"`
}

// TurnMessage is one redacted message inside a report's turn context.
type TurnMessage struct {
	ID        string    `json:"id"`
	Role      string    `json:"role"`
	Mode      string    `json:"mode,omitempty"`
	Content   string    `json:"content"`
	CreatedAt time.Time `json:"created_at"`
	Reported  bool      `json:"reported,omitempty"`
}

// ReportDetail contains one reported reply and its redacted turn context.
// It never includes auth.users records, emails, or credentials.
type ReportDetail struct {
	MessageID      string        `json:"message_id"`
	Rating         string        `json:"rating"`
	Reason         string        `json:"reason"`
	Status         string        `json:"status"`
	Mode           string        `json:"mode,omitempty"`
	CreatedAt      time.Time     `json:"created_at"`
	UpdatedAt      time.Time     `json:"updated_at"`
	ReviewedBy     string        `json:"reviewed_by,omitempty"`
	ReviewedAt     *time.Time    `json:"reviewed_at,omitempty"`
	ResolutionNote string        `json:"resolution_note,omitempty"`
	UserPrompt     string        `json:"user_prompt"`
	AssistantReply string        `json:"assistant_reply"`
	ContextTurns   []TurnMessage `json:"context_turns,omitempty"`
}
