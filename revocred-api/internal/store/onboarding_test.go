package store

import (
	"context"
	"errors"
	"reflect"
	"testing"

	"github.com/revocred/revocred-api/internal/domain"
)

func testOnboarding(t *testing.T, ctx context.Context, repo *Postgres, a, b string, cards []domain.CatalogCard) {
	t.Helper()
	input := domain.RecommendationInput{LifeStage: "adult", MonthlyCategorySpend: map[string]int64{"dining": 40000, "groceries": 50000, "gas": 10000, "travel": 15000, "streaming": 3000, "other": 30000}, CreditTier: "good", RewardsGoal: "cash_back", TravelScope: "none", FeeToleranceCents: 10000, ExistingCardIDs: []string{cards[0].ID, cards[1].ID}}
	preview, err := repo.PreviewPlan(ctx, input)
	if err != nil {
		t.Fatal(err)
	}
	if len(preview.Wallet) != 2 {
		t.Fatal("preview lost selected cards")
	}
	for _, item := range preview.LatestRecommendations.Items {
		if item.CardID == cards[0].ID || item.CardID == cards[1].ID {
			t.Fatal("preview recommends an owned card")
		}
	}
	wallet, _ := repo.ListWallet(ctx, a)
	if len(wallet) != 0 {
		t.Fatal("preview persisted a wallet")
	}
	saved, err := repo.SaveOnboarding(ctx, a, input)
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(saved.Items, preview.LatestRecommendations.Items) {
		t.Fatal("guest and saved ranking differ")
	}
	if _, err = repo.SaveOnboarding(ctx, a, input); err != nil {
		t.Fatalf("retry: %v", err)
	}
	wallet, err = repo.ListWallet(ctx, a)
	if err != nil || len(wallet) != 2 {
		t.Fatalf("selected wallet not persisted: %+v %v", wallet, err)
	}
	invalid := input
	invalid.CreditTier = "invalid"
	invalid.ExistingCardIDs = []string{}
	if _, err = repo.SaveOnboarding(ctx, a, invalid); err == nil {
		t.Fatal("invalid persisted questionnaire accepted")
	}
	wallet, _ = repo.ListWallet(ctx, a)
	if len(wallet) != 2 {
		t.Fatal("failed plan save changed wallet")
	}
	foreign, err := repo.CreateCustomCard(ctx, b, domain.CreateCustomCard{Name: "Foreign onboarding card", Issuer: "Test", Network: "Visa", RewardRates: map[string]float64{"other": 1}, TravelScope: "none", RewardsType: "cash_back", MinimumCreditTier: "good"})
	if err != nil {
		t.Fatal(err)
	}
	invalid = input
	invalid.ExistingCardIDs = []string{foreign.CatalogCardID}
	if _, err = repo.SaveOnboarding(ctx, a, invalid); !errors.Is(err, ErrNotFound) {
		t.Fatalf("cross-account selection: %v", err)
	}
	if _, err = repo.PreviewPlan(ctx, invalid); !errors.Is(err, ErrNotFound) {
		t.Fatalf("guest custom card access: %v", err)
	}
	if err = repo.DeleteWalletCard(ctx, b, foreign.ID); err != nil {
		t.Fatal(err)
	}
	input.ExistingCardIDs = []string{}
	if _, err = repo.SaveOnboarding(ctx, a, input); err != nil {
		t.Fatal(err)
	}
	wallet, _ = repo.ListWallet(ctx, a)
	if len(wallet) != 0 {
		t.Fatal("deselected cards remain in wallet")
	}
}
