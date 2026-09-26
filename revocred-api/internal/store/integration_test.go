package store

import (
	"context"
	"errors"
	"fmt"
	"os"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/revocred/revocred-api/internal/domain"
	"github.com/revocred/revocred-api/internal/recommendation"
)

func TestPostgresIntegration(t *testing.T) {
	url := os.Getenv("REVOCRED_TEST_DATABASE_URL")
	if url == "" {
		t.Skip("run make database-test for disposable PostgreSQL tests")
	}
	if !strings.Contains(url, "@127.0.0.1:") || !strings.Contains(url, "/revocred_test?") {
		t.Fatal("integration tests require disposable loopback revocred_test database")
	}
	ctx := context.Background()
	admin, err := pgxpool.New(ctx, url)
	if err != nil {
		t.Fatal(err)
	}
	defer admin.Close()
	config, err := pgxpool.ParseConfig(url)
	if err != nil {
		t.Fatal(err)
	}
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
	a, b := "11111111-1111-4111-8111-111111111111", "22222222-2222-4222-8222-222222222222"
	if _, err = admin.Exec(ctx, `INSERT INTO auth.users(id,email) VALUES ($1,'a@example.test'),($2,'b@example.test')`, a, b); err != nil {
		t.Fatal(err)
	}
	if err = repo.Ping(ctx); err != nil {
		t.Fatal(err)
	}
	cards, err := repo.ListCatalog(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if len(cards) != 14 {
		t.Fatalf("catalog count=%d", len(cards))
	}
	for _, c := range cards {
		if strings.Contains(c.Name, "Demo") || c.FirstYearBonusCents != 0 || c.AnnualBenefitValue != 0 {
			t.Fatalf("unsafe catalog card: %+v", c)
		}
	}
	t.Run("guest preview and atomic onboarding", func(t *testing.T) { testOnboarding(t, ctx, repo, a, b, cards) })
	draft := domain.CreateCustomCard{Name: "My  Card", Issuer: "Test", Network: "Visa", RewardRates: map[string]float64{"other": 2}, TravelScope: "none", RewardsType: "cash_back", MinimumCreditTier: "good"}
	mine, err := repo.CreateCustomCard(ctx, a, draft)
	if err != nil {
		t.Fatal(err)
	}
	if _, err = repo.CreateCustomCard(ctx, b, draft); err != nil {
		t.Fatalf("same name across accounts: %v", err)
	}
	if _, err = repo.CreateWalletCard(ctx, b, domain.CreateWalletCard{CatalogCardID: mine.CatalogCardID, Status: "active"}); !errors.Is(err, ErrNotFound) {
		t.Fatalf("cross-owner insert: %v", err)
	}
	if err = repo.DeleteWalletCard(ctx, b, mine.ID); !errors.Is(err, ErrNotFound) {
		t.Fatalf("cross-owner delete: %v", err)
	}
	if _, err = repo.CreateWalletCard(ctx, a, domain.CreateWalletCard{CatalogCardID: "20000000-0000-4000-8000-000000000001", Status: "active"}); !errors.Is(err, ErrNotFound) {
		t.Fatalf("inactive demo insert: %v", err)
	}
	// Database ownership enforcement must also protect callers bypassing the repository query.
	if _, err = pool.Exec(ctx, `INSERT INTO revocred.wallet_cards(user_id,catalog_card_id,status) VALUES ($1,$2,'active')`, b, mine.CatalogCardID); err == nil {
		t.Fatal("database allowed cross-owner insert")
	}
	if err = repo.DeleteWalletCard(ctx, a, mine.ID); err != nil {
		t.Fatal(err)
	}
	mine, err = repo.CreateCustomCard(ctx, a, draft)
	if err != nil {
		t.Fatalf("recreate deleted custom: %v", err)
	}
	if _, err = admin.Exec(ctx, `UPDATE revocred.card_catalog_versions SET annual_fee_cents=0 WHERE catalog_card_id=$1`, cards[0].ID); err == nil {
		t.Fatal("version update was allowed")
	}
	if _, err = pool.Exec(ctx, `DELETE FROM auth.users WHERE id=$1`, a); err == nil {
		t.Fatal("runtime role may directly mutate auth")
	}
	input := domain.RecommendationInput{MonthlyCategorySpend: map[string]int64{"other": 100000}, FeeToleranceCents: 10000, CreditTier: "good", RewardsGoal: "cash_back", TravelScope: "none"}
	result := recommendation.New().Recommend(input, cards)
	t.Run("affiliate lifecycle and ranking independence", func(t *testing.T) { testAffiliateOffers(t, ctx, admin, repo, input, cards) })
	result.StrategyCode = "S03"
	if _, err = repo.SaveRecommendation(ctx, a, input, result); err != nil {
		t.Fatal(err)
	}
	if _, err = repo.AppendChatExchange(ctx, a, "private prompt", "private response"); err != nil {
		t.Fatal(err)
	}
	messages, err := repo.ListMessages(ctx, a, 100)
	if err != nil || len(messages) != 2 || messages[0].Role != "user" {
		t.Fatalf("chat order: %+v %v", messages, err)
	}
	export, err := repo.ExportAccount(ctx, a)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(export["recommendation_runs"]), "conservative-2026") {
		t.Fatal("export missing exact catalog snapshot")
	}
	other, err := repo.ExportAccount(ctx, b)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(other["chat_messages"]), "private prompt") {
		t.Fatal("export leaked other account")
	}
	if _, err = pool.Exec(ctx, `INSERT INTO revocred.chat_messages(user_id,role,content) SELECT $1,'user','retention fixture' FROM generate_series(1,1002)`, a); err != nil {
		t.Fatal(err)
	}
	var retained int
	if err = pool.QueryRow(ctx, `SELECT count(*) FROM revocred.chat_messages WHERE user_id=$1`, a).Scan(&retained); err != nil || retained != 1000 {
		t.Fatalf("chat retention = %d, %v", retained, err)
	}
	for i := 0; i < 101; i++ {
		if _, err = repo.SaveRecommendation(ctx, a, input, result); err != nil {
			t.Fatal(err)
		}
	}
	if err = pool.QueryRow(ctx, `SELECT count(*) FROM revocred.recommendation_runs WHERE user_id=$1`, a).Scan(&retained); err != nil || retained != 100 {
		t.Fatalf("recommendation retention = %d, %v", retained, err)
	}
	current, err := repo.Bootstrap(ctx, a)
	if err != nil {
		t.Fatal(err)
	}
	if current.Profile.NextApplicationTarget != current.Playbook.NextCard {
		t.Fatal("profile and playbook disagree")
	}
	for i := 0; i < 99; i++ {
		draft.Name = fmt.Sprintf("Quota card %d", i)
		if _, err = repo.CreateCustomCard(ctx, a, draft); err != nil {
			t.Fatal(err)
		}
	}
	draft.Name = "Over quota"
	if _, err = repo.CreateCustomCard(ctx, a, draft); !errors.Is(err, ErrQuota) {
		t.Fatalf("expected card quota: %v", err)
	}
	if err = repo.DeleteAccount(ctx, a); err != nil {
		t.Fatal(err)
	}
	var n int
	if err = admin.QueryRow(ctx, `SELECT count(*) FROM auth.users WHERE id=$1`, a).Scan(&n); err != nil || n != 0 {
		t.Fatalf("auth account not deleted: %d %v", n, err)
	}
	export, err = repo.ExportAccount(ctx, a)
	if err != nil {
		t.Fatal(err)
	}
	for name, rows := range export {
		if string(rows) != "[]" {
			t.Fatalf("%s survived deletion: %s", name, rows)
		}
	}
	if err = repo.DeleteAccount(ctx, b); err != nil {
		t.Fatal(err)
	}
}
