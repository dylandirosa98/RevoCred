package store

import (
	"context"
	"errors"

	"github.com/revocred/revocred-api/internal/domain"
)

var (
	ErrNotFound = errors.New("not found")
	ErrConflict = errors.New("conflict")
)

type Repository interface {
	Ping(ctx context.Context) error
	Bootstrap(ctx context.Context, userID string) (domain.Bootstrap, error)
	ListCatalog(ctx context.Context) ([]domain.CatalogCard, error)
	GetProfile(ctx context.Context, userID string) (*domain.Profile, error)
	UpsertProfile(ctx context.Context, userID string, profile domain.Profile) (domain.Profile, error)
	ListWallet(ctx context.Context, userID string) ([]domain.WalletCard, error)
	CreateWalletCard(ctx context.Context, userID string, input domain.CreateWalletCard) (domain.WalletCard, error)
	DeleteWalletCard(ctx context.Context, userID, walletCardID string) error
	SaveRecommendation(ctx context.Context, userID string, input domain.RecommendationInput, result domain.RecommendationResult) (domain.RecommendationResult, error)
	ListMessages(ctx context.Context, userID string, limit int) ([]domain.ChatMessage, error)
	AppendChatExchange(ctx context.Context, userID, prompt, reply string) ([]domain.ChatMessage, error)
}
