package store

import (
	"context"
	"encoding/json"
	"errors"
	"github.com/revocred/revocred-api/internal/affiliate"

	"github.com/revocred/revocred-api/internal/domain"
)

var (
	ErrNotFound = errors.New("not found")
	ErrConflict = errors.New("conflict")
	ErrQuota    = errors.New("account card limit reached")
)

type Repository interface {
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
	AppendChatExchange(ctx context.Context, userID, prompt, reply string) ([]domain.ChatMessage, error)
}
