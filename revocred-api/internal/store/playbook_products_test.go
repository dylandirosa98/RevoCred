package store

import (
	"github.com/revocred/revocred-api/internal/domain"
	"github.com/revocred/revocred-api/internal/strategy"
	"testing"
	"time"
)

func TestCanonicalNextReusesItsTemplateRoleWithoutDuplicateAlias(t *testing.T) {
	book := strategy.Build("S05", nil, nil)
	cards := []domain.CatalogCard{{ID: "gold", Name: "Amex Gold"}, {ID: "venture", Name: "Venture X"}, {ID: "platinum", Name: "Platinum"}}
	bindPlaybookProducts(&book, cards, nil)
	selected := applyRecommendation(&book, &domain.RecommendationResult{Items: []domain.RecommendationItem{{CardID: "gold", CardName: "Amex Gold"}}})
	if selected == nil || selected.CardID != "gold" || len(book.Steps) != 3 {
		t.Fatalf("next duplicated template: %+v", book)
	}
	count := 0
	for _, step := range book.Steps {
		if step.CardID == "gold" {
			count++
			if step.Status != "next" {
				t.Fatalf("wrong status: %+v", step)
			}
		}
	}
	if count != 1 {
		t.Fatalf("Gold/Amex Gold appeared %d times", count)
	}
}

func TestCompletedOrderDoesNotFollowTemplateOrCurrentWalletSort(t *testing.T) {
	held := func(id, name string, order int) domain.WalletCard {
		return domain.WalletCard{CatalogCardID: id, Status: "active", CreatedAt: time.Unix(int64(order), 0), Card: &domain.CatalogCard{ID: id, Name: name}}
	}
	first, second, third := held("double", "Double Cash", 1), held("student", "Savor for Students", 2), held("strata", "Strata", 3)
	wallet := []domain.WalletCard{third, second, first}
	book := strategy.Build("S03", []string{"Savor for Students", "Double Cash", "Strata"}, nil)
	book = strategy.Build("S03", walletNamesExcept(wallet, wallet), nil)
	bindPlaybookProducts(&book, []domain.CatalogCard{
		{ID: "savorone", Name: "SavorOne"},
		{ID: "quicksilver", Name: "Quicksilver"},
		{ID: "student", Name: "Savor for Students"},
		{ID: "double", Name: "Double Cash"},
		{ID: "strata", Name: "Strata"},
	}, wallet)
	restoreCompletedRecommendations(&book, []domain.WalletCard{third, first, second}, wallet)
	restoreCompletedRecommendations(&book, []domain.WalletCard{third, first, second}, wallet)
	detachIssuedFamilyCoverage(&book, []domain.WalletCard{third, first, second})
	orders := map[string]int{}
	for _, step := range book.Steps {
		if step.CompletedRecommendation {
			if _, duplicate := orders[step.CardID]; duplicate {
				t.Fatal("duplicate completed card")
			}
			orders[step.CardID] = step.CompletedOrder
		}
	}
	if len(orders) != 3 || orders["double"] != 1 || orders["student"] != 2 || orders["strata"] != 3 {
		t.Fatalf("completed order shifted: %+v", orders)
	}
}

func TestIssuedCardDoesNotSlideIntoADifferentTemplateRole(t *testing.T) {
	held := func(id, name string, order int) domain.WalletCard {
		return domain.WalletCard{CatalogCardID: id, Status: "active", CreatedAt: time.Unix(int64(order), 0), Card: &domain.CatalogCard{ID: id, Name: name}}
	}
	first, second := held("double", "Double Cash", 1), held("student", "Savor for Students", 2)
	wallet := []domain.WalletCard{first, second}
	book := strategy.Build("S03", []string{"Double Cash", "Savor for Students"}, nil)
	book = strategy.Build("S03", walletNamesExcept(wallet, wallet), nil)
	bindPlaybookProducts(&book, []domain.CatalogCard{
		{ID: "savorone", Name: "SavorOne"},
		{ID: "quicksilver", Name: "Quicksilver"},
		{ID: "student", Name: "Savor for Students"},
		{ID: "double", Name: "Double Cash"},
	}, wallet)
	restoreCompletedRecommendations(&book, wallet, wallet)
	detachIssuedFamilyCoverage(&book, wallet)
	bindPlaybookProducts(&book, []domain.CatalogCard{
		{ID: "savorone", Name: "SavorOne"},
		{ID: "quicksilver", Name: "Quicksilver"},
		{ID: "student", Name: "Savor for Students"},
		{ID: "double", Name: "Double Cash"},
	}, wallet)
	selected := applyRecommendation(&book, &domain.RecommendationResult{Items: []domain.RecommendationItem{
		{CardID: "strata", CardName: "Strata"},
	}})
	if selected == nil || selected.CardID != "strata" {
		t.Fatalf("next shifted off Strata: %+v", book)
	}
	byID := map[string]strategy.PlaybookStep{}
	for _, step := range book.Steps {
		if step.CardID != "" {
			if _, dup := byID[step.CardID]; dup {
				t.Fatalf("duplicate product in roadmap: %+v", book.Steps)
			}
			byID[step.CardID] = step
		}
		if step.Name == "SavorOne" && (step.Status == "have" || step.CoveredBy == "Savor for Students") {
			t.Fatalf("issued Savor for Students covered the SavorOne template role: %+v", step)
		}
	}
	if byID["double"].CompletedOrder != 1 || byID["student"].CompletedOrder != 2 {
		t.Fatalf("completed cards did not stay in issuance order: %+v", book.Steps)
	}
}

func TestIssuedCardAbsorbsItsRedundantTemplateRole(t *testing.T) {
	held := func(id, name string, order int) domain.WalletCard {
		return domain.WalletCard{CatalogCardID: id, Status: "active", CreatedAt: time.Unix(int64(order), 0), Card: &domain.CatalogCard{ID: id, Name: name}}
	}
	double := held("double", "Double Cash", 1)
	wallet := []domain.WalletCard{double}
	book := strategy.Build("S03", walletNamesExcept(wallet, wallet), nil)
	bindPlaybookProducts(&book, []domain.CatalogCard{
		{ID: "savorone", Name: "SavorOne"},
		{ID: "quicksilver", Name: "Quicksilver"},
		{ID: "student", Name: "Savor for Students"},
		{ID: "double", Name: "Double Cash"},
		{ID: "strata", Name: "Strata"},
	}, wallet)
	restoreCompletedRecommendations(&book, wallet, wallet)
	detachIssuedFamilyCoverage(&book, wallet)
	bindPlaybookProducts(&book, []domain.CatalogCard{
		{ID: "savorone", Name: "SavorOne"},
		{ID: "quicksilver", Name: "Quicksilver"},
		{ID: "student", Name: "Savor for Students"},
		{ID: "double", Name: "Double Cash"},
		{ID: "strata", Name: "Strata"},
	}, wallet)
	selected := applyRecommendation(&book, &domain.RecommendationResult{Items: []domain.RecommendationItem{
		{CardID: "student", CardName: "Savor for Students"},
	}})
	if selected == nil || selected.CardID != "student" {
		t.Fatalf("next shifted off Savor for Students: %+v", book)
	}
	absorbFamilyRoles(&book)
	if len(book.Steps) != 3 {
		t.Fatalf("expected 3 roles, got %+v", book.Steps)
	}
	for _, step := range book.Steps {
		if step.Name == "SavorOne" {
			t.Fatalf("redundant SavorOne role survived alongside Savor for Students: %+v", book.Steps)
		}
	}
}
