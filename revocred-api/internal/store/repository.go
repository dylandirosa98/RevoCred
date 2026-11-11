package store

import (
	"context"
	"encoding/json"
	"errors"
	"github.com/revocred/revocred-api/internal/affiliate"
	"time"

	"github.com/revocred/revocred-api/internal/domain"
)

var (
	ErrNotFound = errors.New("not found")
	ErrConflict = errors.New("conflict")
	ErrQuota    = errors.New("account card limit reached")
)

type Repository interface {
	SearchReferenceCards(ctx context.Context, query string, limit int) ([]domain.ReferenceCard, error)
	PreviewPlan(context.Context, domain.RecommendationInput) (domain.Bootstrap, error)
	SaveOnboarding(context.Context, string, domain.RecommendationInput) (domain.RecommendationResult, error)
	ListOffers(ctx context.Context) ([]affiliate.Offer, error)
	RecordOfferClick(ctx context.Context, id, placement string) (string, error)
	Ping(ctx context.Context) error
	ExportAccount(ctx context.Context, userID string) (map[string]json.RawMessage, error)
	DeleteAccount(ctx context.Context, userID string) error
	Bootstrap(ctx context.Context, userID string) (domain.Bootstrap, error)
	ListCatalog(ctx context.Context) ([]domain.CatalogCard, error)
	GetProfile(ctx context.Context, userID string) (*domain.Profile, error)
	UpsertProfile(ctx context.Context, userID string, profile domain.Profile) (domain.Profile, error)
	ListWallet(ctx context.Context, userID string) ([]domain.WalletCard, error)
	CreateWalletCard(ctx context.Context, userID string, input domain.CreateWalletCard) (domain.WalletCard, error)
	CreateCustomCard(ctx context.Context, userID string, input domain.CreateCustomCard) (domain.WalletCard, error)
	DeleteWalletCard(ctx context.Context, userID, walletCardID string) error
	SaveRecommendation(ctx context.Context, userID string, input domain.RecommendationInput, result domain.RecommendationResult) (domain.RecommendationResult, error)
	ListMessages(ctx context.Context, userID string, limit int) ([]domain.ChatMessage, error)
	// AppendChatExchange saves a prompt and its reply; mode ("ai" or "basic")
	// is recorded on the reply.
	AppendChatExchange(ctx context.Context, userID, prompt, reply string, blocks json.RawMessage, mode string) ([]domain.ChatMessage, error)
	// ChatConsent returns the stored AI sharing version, or "" when none.
	ChatConsent(ctx context.Context, userID string) (string, error)
	// SetChatConsent stores a version; "" revokes.
	SetChatConsent(ctx context.Context, userID, version string) error
	ClearChat(ctx context.Context, userID string) error
	// ReserveAIUse reserves one external-AI answer against the account's
	// rolling 24-hour allowance: paidLimit with an active AI entitlement,
	// otherwise freeLimit. Use.Allowed is false when the allowance is spent.
	ReserveAIUse(ctx context.Context, userID string, freeLimit, paidLimit int) (AIUse, error)
	// ReleaseAIUse gives back a reservation that produced no AI answer.
	ReleaseAIUse(ctx context.Context, userID, useID string) error
	// ChatFeedback upserts feedback on the caller's own assistant message and
	// reports whether such a message exists.
	ChatFeedback(ctx context.Context, userID, messageID, rating, reason string) (bool, error)
	// AIPlan reports the account's plan and rolling 24-hour AI usage.
	AIPlan(ctx context.Context, userID string, freeLimit, paidLimit int) (AIPlan, error)
	// ApplyRevenueCatEntitlement records RevenueCat subscription state and
	// returns "applied", "duplicate", "stale", "manual" or "unknown_user".
	ApplyRevenueCatEntitlement(ctx context.Context, update EntitlementUpdate) (string, error)
}

// AIUse is the outcome of reserving an external-AI answer.
type AIUse struct {
	Allowed    bool
	ID         string
	Subscriber bool
	Limit      int
}

// AIPlan is the account's REVO AI plan and today's usage.
type AIPlan struct {
	Subscriber bool
	// Source is "manual" or "revenuecat" for subscribers, otherwise "".
	Source      string
	ExpiresAt   *time.Time
	Used        int
	Limit       int
	NextResetAt *time.Time
}

// EntitlementUpdate is RevenueCat subscription state for one account.
// EventID is empty for a refresh read from the RevenueCat API.
type EntitlementUpdate struct {
	EventID   string
	UserID    string
	EventAt   time.Time
	ExpiresAt time.Time
	ProductID string
}
