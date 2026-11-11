package store

import (
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/revocred/revocred-api/internal/carddata"
	"github.com/revocred/revocred-api/internal/domain"
	"github.com/revocred/revocred-api/internal/recommendation"
	"github.com/revocred/revocred-api/internal/scoring"
)

func sampleTerms() *carddata.Terms {
	return &carddata.Terms{
		ProductID: "us-wells-fargo-autograph", ProductName: "Wells Fargo Autograph Card",
		SourceName: carddata.TermsSourceName, SourceURL: carddata.ProjectURL, LastVerified: "2026-07-25",
		CapturedAt: time.Date(2026, 11, 9, 12, 0, 0, 0, time.UTC), SnapshotSHA256: strings.Repeat("ab", 32),
		MappingVersion: carddata.TermsMappingVersion, AnnualFeeCents: 0, RewardsType: "travel",
		RewardRates: map[string]float64{"other": 1, "dining": 3, "gas": 3, "travel": 3, "streaming": 3},
	}
}

func skippedCard() domain.CatalogCard {
	return domain.CatalogCard{
		ID: "c1", Name: "Autograph", Issuer: "Wells Fargo", TermsUnknown: true,
		RewardRates: map[string]float64{}, RewardsType: "cash_back", DatasetVersion: "user-supplied",
		Benefits: []string{"Terms not supplied; excluded from wallet score and value"},
		BestUse:  "Terms not supplied; excluded from scoring",
	}
}

func TestCommunityTermsScoreSkippedCardsOnly(t *testing.T) {
	terms := sampleTerms()
	card := skippedCard()
	applyCommunityTerms(&card, terms)
	if card.TermsUnknown || card.TermsSource != domain.TermsSourceCommunity || card.CommunityTerms != terms {
		t.Fatalf("skipped card not scored with community terms: %+v", card)
	}
	if !reflect.DeepEqual(card.RewardRates, terms.RewardRates) || card.RewardsType != "travel" {
		t.Fatalf("rates/type not applied: %+v", card)
	}
	card.RewardRates["dining"] = 99
	if terms.RewardRates["dining"] != 3 {
		t.Fatal("card shares the cached rate map")
	}
	if !strings.Contains(card.SourceDisclaimer, "2026-07-25") || !strings.Contains(card.SourceDisclaimer, "2026-11-09") || !strings.Contains(card.SourceDisclaimer, "not issuer-verified") {
		t.Fatalf("missing source/date label: %s", card.SourceDisclaimer)
	}
	if card.SourceName != carddata.TermsSourceName || !strings.HasPrefix(card.DatasetVersion, carddata.TermsMappingVersion+":2026-11-09:") {
		t.Fatalf("missing versioned provenance: %s %s", card.SourceName, card.DatasetVersion)
	}
	if strings.Contains(strings.Join(card.Benefits, " "), "excluded") || strings.Contains(card.BestUse, "excluded") {
		t.Fatal("stale skipped-terms copy kept")
	}
	if card.BestUse != "3x dining, 3x gas, 3x streaming" {
		t.Fatalf("best use = %q", card.BestUse)
	}
	if card.ShapesRecommendations() {
		t.Fatal("community terms may not shape recommendations")
	}

	// The cardholder's own terms always win.
	own := domain.CatalogCard{ID: "c2", RewardRates: map[string]float64{"other": 1.25}, AnnualFeeCents: 1000, DatasetVersion: "user-supplied"}
	before := own
	applyCommunityTerms(&own, terms)
	if !reflect.DeepEqual(own, before) {
		t.Fatalf("user terms were overwritten: %+v", own)
	}
	// No mapping keeps the card unscored.
	unknown := skippedCard()
	applyCommunityTerms(&unknown, nil)
	if !unknown.TermsUnknown || unknown.TermsSource != "" {
		t.Fatal("card without community terms was scored")
	}
}

func TestCommunityTermsChangeWalletMetricsNotRecommendations(t *testing.T) {
	spend := map[string]int64{"dining": 40000, "gas": 10000, "other": 30000}
	skipped := skippedCard()
	scored := skippedCard()
	applyCommunityTerms(&scored, sampleTerms())
	walletOf := func(card domain.CatalogCard) []domain.WalletCard {
		return []domain.WalletCard{{CatalogCardID: card.ID, Status: "active", Card: &card}}
	}
	before := scoring.Metrics(walletOf(skipped), spend, "none")
	after := scoring.Metrics(walletOf(scored), spend, "none")
	if after.Score <= before.Score || after.OngoingValue.RewardsCents <= before.OngoingValue.RewardsCents {
		t.Fatalf("community terms did not score the wallet: %+v vs %+v", after, before)
	}
	// 12 months x (3% of $400 dining + 3% of $100 gas + 1% of $300 other) = $216.
	if after.OngoingValue.RewardsCents != 21600 {
		t.Fatalf("rewards = %d", after.OngoingValue.RewardsCents)
	}

	catalog := []domain.CatalogCard{
		{ID: "cat-1", Slug: "flat-two", Name: "Flat Two", RewardRates: map[string]float64{"other": 2}, RewardsType: "cash_back", TravelScope: "none", MinimumCreditTier: "good", DatasetVersion: "v1"},
		{ID: "cat-2", Slug: "dining-four", Name: "Dining Four", RewardRates: map[string]float64{"other": 1, "dining": 4}, RewardsType: "cash_back", TravelScope: "none", MinimumCreditTier: "good", DatasetVersion: "v1"},
	}
	input := domain.RecommendationInput{MonthlyCategorySpend: spend, CreditTier: "good", RewardsGoal: "cash_back", TravelScope: "none", FeeToleranceCents: 10000}
	withoutCard := recommendation.New().Recommend(input, catalog)
	input.OwnedCards = []domain.CatalogCard{scored}
	input.ExistingCardIDs = []string{scored.ID}
	withCard := recommendation.New().Recommend(input, catalog)
	if !reflect.DeepEqual(withCard.Items, withoutCard.Items) || !reflect.DeepEqual(withCard.Exclusions, withoutCard.Exclusions) {
		t.Fatalf("community-scored wallet card changed recommendations:\n%+v\n%+v", withCard.Items, withoutCard.Items)
	}
	// A community-scored card is never a candidate, even if passed as one.
	withCandidate := recommendation.New().Recommend(domain.RecommendationInput{MonthlyCategorySpend: spend, CreditTier: "good", RewardsGoal: "cash_back", TravelScope: "none", FeeToleranceCents: 10000}, append(append([]domain.CatalogCard{}, catalog...), scored))
	for _, item := range withCandidate.Items {
		if item.CardID == scored.ID {
			t.Fatal("community-scored card became a recommendation candidate")
		}
	}
}

func TestCommunityPointValueAppliedOnlyToSkippedTerms(t *testing.T) {
	terms := sampleTerms()
	terms.PointValueCents = .5
	card := skippedCard()
	applyCommunityTerms(&card, terms)
	if card.PointValueCents != .5 || !strings.Contains(card.SourceDisclaimer, "0.5 cents") {
		t.Fatalf("missing value: %+v", card)
	}
	issuer := domain.CatalogCard{RewardRates: map[string]float64{"other": 2}}
	applyCommunityTerms(&issuer, terms)
	if issuer.PointValueCents != 0 {
		t.Fatal("issuer snapshot changed")
	}
}
