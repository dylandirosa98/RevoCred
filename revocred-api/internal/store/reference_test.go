package store

import (
	"context"
	"errors"
	"testing"

	"github.com/revocred/revocred-api/internal/domain"
	"github.com/revocred/revocred-api/internal/scoring"
)

// testReferenceIndex covers the search-only index: identity rows are findable,
// a vetted product resolves to the real catalog card, skipping terms keeps a
// card out of scoring, and supplying terms brings it in.
func testReferenceIndex(t *testing.T, ctx context.Context, repo *Postgres, a, b string) {
	t.Helper()
	index, err := repo.SearchReferenceCards(ctx, "freedom", 20)
	if err != nil {
		t.Fatal(err)
	}
	if len(index) == 0 {
		t.Fatal("index search returned nothing for a seeded product")
	}
	var vetted, identity domain.ReferenceCard
	for _, card := range index {
		if card.CatalogCardID != "" && vetted.ID == "" {
			vetted = card
		}
		if card.TermsStatus == "partial" && identity.ID == "" {
			identity = card
		}
	}
	if vetted.ID == "" {
		t.Fatal("no index row resolved to a vetted catalog card")
	}
	if vetted.TermsStatus != "verified" || len(vetted.RewardRates) == 0 {
		t.Fatalf("vetted index row lost its sourced terms: %+v", vetted)
	}
	if identity.ID == "" {
		t.Skip("no identity-only row in this dataset")
	}
	if identity.SourceURL == "" || identity.SourceCapturedOn == "" || identity.Disclaimer == "" {
		t.Fatalf("identity row is not sourced: %+v", identity)
	}

	// A pick that matches the vetted catalog keeps the sourced card and must
	// not create a user copy.
	picks := []domain.OnboardingCard{{ReferenceID: vetted.ID}}
	ids, err := repo.resolveOnboardingCards(ctx, a, picks, nil)
	if err != nil {
		t.Fatal(err)
	}
	if len(ids) != 1 || ids[0] != vetted.CatalogCardID {
		t.Fatalf("vetted pick did not resolve to the catalog card: %v", ids)
	}
	before, _ := repo.ListWallet(ctx, a)
	if len(before) != 0 {
		t.Fatal("resolve created a wallet entry")
	}

	// Skipping terms: the card is owned, marked unknown, and ignored by scoring.
	input := domain.RecommendationInput{
		LifeStage: "adult", MonthlyCategorySpend: map[string]int64{"dining": 40000},
		CreditTier: "good", RewardsGoal: "cash_back", TravelScope: "none", FeeToleranceCents: 10000,
		AddedCards: []domain.OnboardingCard{{ReferenceID: identity.ID}},
	}
	result, err := repo.SaveOnboarding(ctx, a, input)
	if err != nil {
		t.Fatal(err)
	}
	wallet, err := repo.ListWallet(ctx, a)
	if err != nil || len(wallet) != 1 {
		t.Fatalf("skipped-term card not saved: %+v %v", wallet, err)
	}
	if !wallet[0].Card.TermsUnknown {
		t.Fatal("skipped-term card is not marked as unknown terms")
	}
	if wallet[0].Card.RewardRates["other"] != 0 {
		t.Fatal("skipped-term card invented a rate")
	}
	skipScore := scoring.Metrics(wallet, map[string]int64{"dining": 40000})
	if skipScore.Score != 24 {
		t.Fatalf("unknown-term card changed the score: %+v", skipScore)
	}
	for _, item := range result.Items {
		if item.CardID == wallet[0].CatalogCardID {
			t.Fatal("an owned card was recommended")
		}
	}

	// Supplying the same card's terms makes it count.
	supplied := input
	supplied.AddedCards = []domain.OnboardingCard{{
		ReferenceID: identity.ID, IncludeTerms: true, AnnualFeeCents: 9500,
		RewardRates: map[string]float64{"other": 2, "dining": 3}, MinimumTier: "good",
		BestUse: "Everyday spend",
	}}
	if _, err := repo.SaveOnboarding(ctx, a, supplied); err != nil {
		t.Fatal(err)
	}
	wallet, err = repo.ListWallet(ctx, a)
	if err != nil || len(wallet) != 1 {
		t.Fatalf("supplied-term card not saved: %+v %v", wallet, err)
	}
	if wallet[0].Card.TermsUnknown {
		t.Fatal("supplied terms were ignored")
	}
	if wallet[0].Card.AnnualFeeCents != 9500 || wallet[0].Card.RewardRates["dining"] != 3 {
		t.Fatalf("supplied terms were not stored: %+v", wallet[0].Card)
	}
	if got := scoring.Metrics(wallet, map[string]int64{"dining": 40000}); got.Score <= skipScore.Score || got.YearlyValue <= 0 {
		t.Fatalf("known terms did not improve the wallet: %+v vs %+v", got, skipScore)
	}

	// An unknown reference id is rejected rather than silently ignored.
	if _, err := repo.resolveOnboardingCards(ctx, a, []domain.OnboardingCard{{ReferenceID: "00000000-0000-4000-8000-000000000000"}}, nil); !errors.Is(err, ErrNotFound) {
		t.Fatalf("unknown reference accepted: %v", err)
	}
	// Another account cannot pick up this card.
	other, err := repo.SaveOnboarding(ctx, b, input)
	if err != nil {
		t.Fatal(err)
	}
	otherWallet, _ := repo.ListWallet(ctx, b)
	if len(otherWallet) != 1 || otherWallet[0].ID == wallet[0].ID {
		t.Fatalf("accounts share a wallet card: %+v", otherWallet)
	}
	_ = other
}
