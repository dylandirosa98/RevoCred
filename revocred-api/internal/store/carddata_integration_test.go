package store

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"reflect"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/revocred/revocred-api/internal/carddata"
	"github.com/revocred/revocred-api/internal/domain"
	"github.com/revocred/revocred-api/internal/recommendation"
	"github.com/revocred/revocred-api/internal/scoring"
)

func TestCommunityCardDataIntegration(t *testing.T) {
	url := os.Getenv("REVOCRED_TEST_DATABASE_URL")
	if url == "" {
		t.Skip("requires disposable local revocred_test database")
	}
	if !strings.Contains(url, "@127.0.0.1:") || !strings.Contains(url, "/revocred_test?") {
		t.Fatal("disposable database required")
	}
	ctx := context.Background()
	config, err := pgxpool.ParseConfig(url)
	if err != nil {
		t.Fatal(err)
	}
	admin, err := pgxpool.New(ctx, url)
	if err != nil {
		t.Fatal(err)
	}
	defer admin.Close()
	config.AfterConnect = func(ctx context.Context, c *pgx.Conn) error {
		_, err := c.Exec(ctx, "SET ROLE revocred_runtime")
		return err
	}
	pool, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		t.Fatal(err)
	}
	defer pool.Close()
	repo := NewPostgres(pool)
	before, err := repo.ListCatalog(ctx)
	if err != nil {
		t.Fatal(err)
	}
	raw, err := os.ReadFile("../carddata/testdata/cards.json")
	if err != nil {
		t.Fatal(err)
	}
	s := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.Write(raw) }))
	defer s.Close()
	cache := carddata.New(s.Client(), repo, s.URL)
	if err := cache.Refresh(ctx); err != nil {
		t.Fatal(err)
	}
	restarted := carddata.New(s.Client(), repo, s.URL)
	if err := restarted.Load(ctx); err != nil {
		t.Fatal(err)
	}
	id := "20000000-0000-4000-8000-000000000013"
	if cache.Get(id).SnapshotSHA256 != restarted.Get(id).SnapshotSHA256 {
		t.Fatal("database JSON normalization changed source snapshot provenance")
	}
	repo.UseCardData(restarted)
	after, err := repo.ListCatalog(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if len(after) != 15 {
		t.Fatalf("recommendation catalog changed size: %d", len(after))
	}
	matched := 0
	for n, c := range after {
		if c.CommunityData != nil {
			matched++
		}
		if c.AnnualFeeCents != before[n].AnnualFeeCents || !reflect.DeepEqual(c.RewardRates, before[n].RewardRates) || !reflect.DeepEqual(c.Benefits, before[n].Benefits) || c.AnnualBenefitValue != before[n].AnnualBenefitValue || c.FirstYearBonusCents != before[n].FirstYearBonusCents {
			t.Fatal("community feed modified issuer/scoring inputs")
		}
	}
	if matched != 15 {
		t.Fatalf("mapped %d cards, expected 15", matched)
	}
	input := domain.RecommendationInput{MonthlyCategorySpend: map[string]int64{"other": 100000}, FeeToleranceCents: 100000, CreditTier: "excellent", RewardsGoal: "travel", TravelScope: "both"}
	a := recommendation.New().Recommend(input, before)
	b := recommendation.New().Recommend(input, after)
	if !reflect.DeepEqual(a.Items, b.Items) {
		t.Fatal("community data changed recommendation selection or value")
	}
	user := "33333333-3333-4333-8333-333333333333"
	if _, err := admin.Exec(ctx, `INSERT INTO auth.users(id,email) VALUES($1,'community-data@example.test')`, user); err != nil {
		t.Fatal(err)
	}
	defer repo.DeleteAccount(ctx, user)
	if _, err := repo.CreateWalletCard(ctx, user, domain.CreateWalletCard{CatalogCardID: "20000000-0000-4000-8000-000000000013", Status: "active"}); err != nil {
		t.Fatal(err)
	}
	wallet, err := repo.ListWallet(ctx, user)
	if err != nil {
		t.Fatal(err)
	}
	if len(wallet) != 1 || wallet[0].Card.CommunityData == nil {
		t.Fatal("wallet omitted cached product details")
	}
	if got := wallet[0].Card.CommunityData; got.ID != "us-chase-sapphire-reserve" || len(got.Benefits) < 2 {
		t.Fatal("wallet attached wrong/incomplete record")
	}
	testCommunityWalletTerms(t, ctx, admin, pool, repo, after)
}

// testCommunityWalletTerms: a search pick saved without terms is scored in the
// wallet with community terms, typed terms win, and recommendations never move.
func testCommunityWalletTerms(t *testing.T, ctx context.Context, admin, pool *pgxpool.Pool, repo *Postgres, catalog []domain.CatalogCard) {
	t.Helper()
	member := "44444444-4444-4444-8444-444444444444"
	if _, err := admin.Exec(ctx, `INSERT INTO auth.users(id,email) VALUES($1,'community-terms@example.test')`, member); err != nil {
		t.Fatal(err)
	}
	defer repo.DeleteAccount(ctx, member)
	draft := func(name, issuer string) domain.CreateCustomCard {
		return domain.CreateCustomCard{Name: name, Issuer: issuer, Network: "Visa", TravelScope: "none", RewardsType: "cash_back", MinimumCreditTier: "good", TermsUnknown: true, RewardRates: map[string]float64{}}
	}
	created, err := repo.CreateCustomCard(ctx, member, draft("Active Cash", "Wells Fargo"))
	if err != nil {
		t.Fatal(err)
	}
	if c := created.Card; c.TermsSource != domain.TermsSourceCommunity || c.TermsUnknown || c.RewardRates["other"] != 2 {
		t.Fatalf("created card not scored with community terms: %+v", c)
	}
	var linked bool
	if err := admin.QueryRow(ctx, `SELECT c.reference_card_id = r.id FROM revocred.catalog_cards c JOIN revocred.card_reference_index r ON r.slug = 'wells-fargo-active-cash' WHERE c.id = $1`, created.CatalogCardID).Scan(&linked); err != nil || !linked {
		t.Fatalf("custom card not linked to its search-index row: %v", err)
	}
	if _, err := repo.CreateCustomCard(ctx, member, draft("IHG One Rewards Traveler", "Chase")); err != nil {
		t.Fatal(err)
	}
	own := draft("Autograph", "Wells Fargo")
	own.TermsUnknown = false
	own.RewardRates = map[string]float64{"other": 1.25}
	own.AnnualFeeCents = 1000
	if _, err := repo.CreateCustomCard(ctx, member, own); err != nil {
		t.Fatal(err)
	}
	// The runtime role cannot rewrite the link after creation.
	if _, err := pool.Exec(ctx, `UPDATE revocred.catalog_cards SET reference_card_id = NULL WHERE id = $1`, created.CatalogCardID); err == nil {
		t.Fatal("runtime role may rewrite a card's reference link")
	}

	wallet, err := repo.ListWallet(ctx, member)
	if err != nil || len(wallet) != 3 {
		t.Fatalf("wallet: %+v %v", wallet, err)
	}
	for _, item := range wallet {
		c := item.Card
		switch c.Name {
		case "Active Cash":
			if c.TermsSource != domain.TermsSourceCommunity || c.CommunityTerms == nil || c.CommunityTerms.ProductID != "us-wells-fargo-active-cash" || !strings.Contains(c.SourceDisclaimer, "OpenCard DB") {
				t.Fatalf("Active Cash not labelled community data: %+v", c)
			}
		case "IHG One Rewards Traveler":
			if !c.TermsUnknown || c.TermsSource != "" {
				t.Fatalf("hotel-currency card was scored: %+v", c)
			}
		case "Autograph":
			if c.TermsSource != "" || c.RewardRates["other"] != 1.25 || c.AnnualFeeCents != 1000 || c.RewardRates["dining"] != 0 {
				t.Fatalf("typed terms did not win: %+v", c)
			}
		}
	}
	plain := NewPostgres(pool)
	plainWallet, err := plain.ListWallet(ctx, member)
	if err != nil {
		t.Fatal(err)
	}
	spend := map[string]int64{"dining": 40000, "other": 30000}
	scored, unscored := scoring.Metrics(wallet, spend, "none"), scoring.Metrics(plainWallet, spend, "none")
	if scored.Score <= unscored.Score || scored.OngoingValue.RewardsCents <= unscored.OngoingValue.RewardsCents {
		t.Fatalf("community terms did not reach wallet metrics: %+v vs %+v", scored, unscored)
	}
	owned := func(w []domain.WalletCard) []domain.CatalogCard {
		cards := []domain.CatalogCard{}
		for _, item := range w {
			cards = append(cards, *item.Card)
		}
		return cards
	}
	input := domain.RecommendationInput{MonthlyCategorySpend: spend, CreditTier: "excellent", RewardsGoal: "cash_back", TravelScope: "none", FeeToleranceCents: 100000}
	input.OwnedCards = owned(plainWallet)
	before := recommendation.New().Recommend(input, catalog)
	input.OwnedCards = owned(wallet)
	after := recommendation.New().Recommend(input, catalog)
	if !reflect.DeepEqual(before.Items, after.Items) || !reflect.DeepEqual(before.Exclusions, after.Exclusions) {
		t.Fatal("community wallet terms changed recommendations")
	}

	// Search shows the terms a skipped pick would use; the guest preview scores
	// the pick in the wallet without changing its recommendations.
	results, err := repo.SearchReferenceCards(ctx, "active cash", 5)
	if err != nil {
		t.Fatal(err)
	}
	var reference domain.ReferenceCard
	for _, card := range results {
		if card.Name == "Active Cash" {
			reference = card
		}
	}
	if reference.CommunityTerms == nil || reference.CommunityTerms.RewardRates["other"] != 2 {
		t.Fatalf("search row missing community terms: %+v", reference)
	}
	preview := domain.RecommendationInput{LifeStage: "adult", MonthlyCategorySpend: spend, CreditTier: "good", RewardsGoal: "cash_back", TravelScope: "none", FeeToleranceCents: 10000, AddedCards: []domain.OnboardingCard{{ReferenceID: reference.ID}}}
	withTerms, err := repo.PreviewPlan(ctx, preview)
	if err != nil {
		t.Fatal(err)
	}
	withoutTerms, err := plain.PreviewPlan(ctx, preview)
	if err != nil {
		t.Fatal(err)
	}
	if withTerms.WalletMetrics.Score <= withoutTerms.WalletMetrics.Score {
		t.Fatalf("preview did not score the pick: %+v vs %+v", withTerms.WalletMetrics, withoutTerms.WalletMetrics)
	}
	if !reflect.DeepEqual(withTerms.LatestRecommendations.Items, withoutTerms.LatestRecommendations.Items) || withTerms.Playbook.NextCard != withoutTerms.Playbook.NextCard {
		t.Fatal("preview recommendations changed with community terms")
	}
}
