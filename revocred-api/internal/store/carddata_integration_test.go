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
}
