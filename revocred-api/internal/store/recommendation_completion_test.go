package store

import (
	"context"
	"encoding/json"
	"reflect"
	"sync"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/revocred/revocred-api/internal/domain"
	"github.com/revocred/revocred-api/internal/recommendation"
)

func testRecommendationCompletion(t *testing.T, ctx context.Context, admin *pgxpool.Pool, repo *Postgres, cards []domain.CatalogCard) {
	const user = "33333333-3333-4333-8333-333333333327"
	const discover = "20000000-0000-4000-8000-000000000021"
	const double = "20000000-0000-4000-8000-000000000018"
	if _, err := admin.Exec(ctx, `INSERT INTO auth.users(id,email) VALUES ($1,'completion@example.test')`, user); err != nil {
		t.Fatal(err)
	}
	if _, err := repo.CreateWalletCard(ctx, user, domain.CreateWalletCard{CatalogCardID: discover, Status: "active"}); err != nil {
		t.Fatal(err)
	}
	input := domain.RecommendationInput{MonthlyCategorySpend: map[string]int64{"other": 100000}, FeeToleranceCents: 0, TravelScope: "none", RewardsGoal: "cash_back", CreditTier: "good", ExistingCardIDs: []string{discover}}
	result := recommendation.New().Recommend(input, cards)
	result.StrategyCode = "S03"
	if len(result.Items) == 0 || result.Items[0].CardID != double {
		t.Fatalf("fixture must genuinely recommend Double Cash, got %+v", result.Items)
	}
	if _, err := repo.SaveRecommendation(ctx, user, input, result); err != nil {
		t.Fatal(err)
	}
	// Legacy recovery must work even if this recommendation was issued before
	// completion tracking existed, with no intermediate bootstrap request.
	if _, err := admin.Exec(ctx, `DELETE FROM revocred.issued_recommendations WHERE user_id=$1`, user); err != nil {
		t.Fatal(err)
	}
	if _, err := repo.CreateWalletCard(ctx, user, domain.CreateWalletCard{CatalogCardID: double, Status: "active"}); err != nil {
		t.Fatal(err)
	}
	data, err := repo.Bootstrap(ctx, user)
	if err != nil {
		t.Fatal(err)
	}
	assertCompletedRecommendation(t, data, double, true)
	assertCompletedRecommendation(t, data, discover, false)
	if data.Playbook.NextCard != "" {
		t.Fatalf("no-improvement state invented another card: %s", data.Playbook.NextCard)
	}
	var source string
	if err = admin.QueryRow(ctx, `SELECT source FROM revocred.issued_recommendations WHERE user_id=$1 AND catalog_card_id=$2`, user, double).Scan(&source); err != nil || source != "legacy_questionnaire_rank1" {
		t.Fatalf("legacy source=%s: %v", source, err)
	}
	storedBefore, _ := repo.latestRecommendation(ctx, user)
	baseline, _ := json.Marshal(storedBefore)
	var group sync.WaitGroup
	errors := make(chan error, 8)
	for i := 0; i < 8; i++ {
		group.Add(1)
		go func() { defer group.Done(); _, err := repo.Bootstrap(ctx, user); errors <- err }()
	}
	group.Wait()
	close(errors)
	for err := range errors {
		if err != nil {
			t.Fatal(err)
		}
	}
	storedAfter, _ := repo.latestRecommendation(ctx, user)
	after, _ := json.Marshal(storedAfter)
	if string(baseline) != string(after) {
		t.Fatal("Bootstrap rewrote immutable recommendation history")
	}
	var count int
	if err = admin.QueryRow(ctx, `SELECT count(*) FROM revocred.issued_recommendations WHERE user_id=$1 AND catalog_card_id=$2`, user, double).Scan(&count); err != nil || count != 1 {
		t.Fatalf("duplicate issuance count=%d: %v", count, err)
	}
	// Completion evidence must survive deletion of rolling rank snapshots.
	for i := 0; i < 101; i++ {
		if _, err = repo.SaveRecommendation(ctx, user, input, result); err != nil {
			t.Fatal(err)
		}
	}
	data, err = repo.Bootstrap(ctx, user)
	if err != nil {
		t.Fatal(err)
	}
	assertCompletedRecommendation(t, data, double, true)
	if err = admin.QueryRow(ctx, `SELECT count(*) FROM revocred.recommendation_runs WHERE user_id=$1`, user).Scan(&count); err != nil || count != 100 {
		t.Fatalf("run retention=%d: %v", count, err)
	}
	if err = admin.QueryRow(ctx, `SELECT count(*) FROM revocred.issued_recommendations WHERE user_id=$1 AND source_run_id IS NULL`, user).Scan(&count); err != nil || count < 1 {
		t.Fatalf("trimmed source removed durable evidence: %v", err)
	}

	// The next outside-template card must survive even when it was selected
	// only by Bootstrap, never saved as the rank-one questionnaire result.
	input.MonthlyCategorySpend = map[string]int64{"gas": 20000, "other": 20000, "dining": 20000, "travel": 20000, "groceries": 20000, "streaming": 20000}
	input.LifeStage = "student"
	input.ExistingCardIDs = []string{discover, double}
	input.OwnedCards = nil
	for _, held := range data.Wallet {
		if held.Status == "active" && held.Card != nil {
			input.OwnedCards = append(input.OwnedCards, *held.Card)
		}
	}
	result = recommendation.New().Recommend(input, cards)
	result.StrategyCode = "S03"
	if len(result.Items) == 0 || result.Items[0].CardName != "Savor for Students" {
		t.Fatalf("fixture saved next=%+v", result.Items)
	}
	if _, err = repo.SaveRecommendation(ctx, user, input, result); err != nil {
		t.Fatal(err)
	}
	data, err = repo.Bootstrap(ctx, user)
	if err != nil {
		t.Fatal(err)
	}
	if data.Playbook.NextCard != "Savor for Students" {
		t.Fatalf("fixture next=%s", data.Playbook.NextCard)
	}
	const student = "20000000-0000-4000-8000-000000000007"
	if _, err = repo.CreateWalletCard(ctx, user, domain.CreateWalletCard{CatalogCardID: student, Status: "active"}); err != nil {
		t.Fatal(err)
	}
	data, err = repo.Bootstrap(ctx, user)
	if err != nil {
		t.Fatal(err)
	}
	assertCompletedRecommendation(t, data, student, true)
	if data.Playbook.NextCard != "Strata" {
		t.Fatalf("fixture next=%s", data.Playbook.NextCard)
	}
	const strata = "20000000-0000-4000-8000-000000000019"
	if err = admin.QueryRow(ctx, `SELECT source FROM revocred.issued_recommendations WHERE user_id=$1 AND strategy_code='S03' AND catalog_card_id=$2`, user, strata).Scan(&source); err != nil || source != "bootstrap_next" {
		t.Fatalf("dynamic issuance source=%s: %v", source, err)
	}
	added, err := repo.CreateWalletCard(ctx, user, domain.CreateWalletCard{CatalogCardID: strata, Status: "active"})
	if err != nil {
		t.Fatal(err)
	}
	data, err = repo.Bootstrap(ctx, user)
	if err != nil {
		t.Fatal(err)
	}
	for _, id := range []string{double, student, strata} {
		assertCompletedRecommendation(t, data, id, true)
	}
	current := recommendation.New().Recommend(*data.LatestQuestionnaire, cards)
	if !reflect.DeepEqual(current.Items, data.LatestRecommendations.Items) || !reflect.DeepEqual(current.Exclusions, data.LatestRecommendations.Exclusions) {
		t.Fatal("completion changed recommendation ranking")
	}
	if err = repo.DeleteWalletCard(ctx, user, added.ID); err != nil {
		t.Fatal(err)
	}
	if _, err = repo.CreateCustomCard(ctx, user, domain.CreateCustomCard{Name: "Strata", Issuer: "Member entered", Network: "Visa", TravelScope: "none", RewardsType: "cash_back", MinimumCreditTier: "good", TermsUnknown: true}); err != nil {
		t.Fatal(err)
	}
	data, err = repo.Bootstrap(ctx, user)
	if err != nil {
		t.Fatal(err)
	}
	assertCompletedRecommendation(t, data, strata, false)
	for _, step := range data.Playbook.Steps {
		if step.Status == "next" && step.Name == "Strata" && step.CardID != strata {
			t.Fatal("same-name custom product replaced the canonical next card")
		}
	}
	if _, err = repo.CreateWalletCard(ctx, user, domain.CreateWalletCard{CatalogCardID: strata, Status: "active"}); err != nil {
		t.Fatal(err)
	}
	data, err = repo.Bootstrap(ctx, user)
	if err != nil {
		t.Fatal(err)
	}
	assertCompletedRecommendation(t, data, strata, true)
	if _, err = admin.Exec(ctx, `UPDATE revocred.profiles SET credit_card_strategy='S04' WHERE user_id=$1`, user); err != nil {
		t.Fatal(err)
	}
	data, err = repo.Bootstrap(ctx, user)
	if err != nil {
		t.Fatal(err)
	}
	for _, id := range []string{double, student, strata} {
		assertCompletedRecommendation(t, data, id, false)
	}
	if _, err = admin.Exec(ctx, `UPDATE revocred.profiles SET credit_card_strategy='S03' WHERE user_id=$1`, user); err != nil {
		t.Fatal(err)
	}
	data, err = repo.Bootstrap(ctx, user)
	if err != nil {
		t.Fatal(err)
	}
	assertCompletedRecommendation(t, data, double, true)

	const other = "44444444-4444-4444-8444-444444444427"
	if _, err = admin.Exec(ctx, `INSERT INTO auth.users(id,email) VALUES ($1,'completion-other@example.test')`, other); err != nil {
		t.Fatal(err)
	}
	if _, err = repo.CreateWalletCard(ctx, other, domain.CreateWalletCard{CatalogCardID: double, Status: "active"}); err != nil {
		t.Fatal(err)
	}
	otherInput := domain.RecommendationInput{MonthlyCategorySpend: map[string]int64{"other": 100000}, CreditTier: "good", RewardsGoal: "cash_back", TravelScope: "none", ExistingCardIDs: []string{double}}
	for _, card := range cards {
		if card.ID == double {
			otherInput.OwnedCards = append(otherInput.OwnedCards, card)
		}
	}
	otherResult := recommendation.New().Recommend(otherInput, cards)
	otherResult.StrategyCode = "S03"
	if _, err = repo.SaveRecommendation(ctx, other, otherInput, otherResult); err != nil {
		t.Fatal(err)
	}
	otherData, err := repo.Bootstrap(ctx, other)
	if err != nil {
		t.Fatal(err)
	}
	assertCompletedRecommendation(t, otherData, double, false)
	export, err := repo.ExportAccount(ctx, user)
	if err != nil {
		t.Fatal(err)
	}
	var evidence []map[string]any
	if err = json.Unmarshal(export["issued_recommendations"], &evidence); err != nil || len(evidence) < 3 {
		t.Fatalf("export omitted history: %v", err)
	}
	otherExport, err := repo.ExportAccount(ctx, other)
	if err != nil {
		t.Fatal(err)
	}
	if string(otherExport["issued_recommendations"]) != "[]" {
		t.Fatal("account history leaked")
	}
	if err = repo.DeleteAccount(ctx, user); err != nil {
		t.Fatal(err)
	}
	if err = admin.QueryRow(ctx, `SELECT count(*) FROM revocred.issued_recommendations WHERE user_id=$1`, user).Scan(&count); err != nil || count != 0 {
		t.Fatalf("delete retained provenance: %v", err)
	}
	if err = repo.DeleteAccount(ctx, other); err != nil {
		t.Fatal(err)
	}
}

func assertCompletedRecommendation(t *testing.T, data domain.Bootstrap, id string, want bool) {
	t.Helper()
	count := 0
	for _, step := range data.Playbook.Steps {
		if step.CompletedRecommendation && step.CardID == id {
			count++
			if step.Status != "have" || step.Timing != "Completed recommendation" {
				t.Fatalf("invalid completion: %+v", step)
			}
			if step.CompletedOrder < 1 {
				t.Fatal("completed recommendation has no stable completion order")
			}
		}
	}
	expected := 0
	if want {
		expected = 1
	}
	if count != expected {
		t.Fatalf("completed %s count=%d want=%d: %+v", id, count, expected, data.Playbook.Steps)
	}
}
