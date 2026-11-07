package store

import (
	"github.com/revocred/revocred-api/internal/domain"
	"github.com/revocred/revocred-api/internal/strategy"
)

// Resolve UI/product identity, not earning terms or substitution eligibility.
// Gold is the matrix's documented name for the catalog's Amex Gold product;
// no fuzzy or cross-product matching is allowed for future applications.
func bindPlaybookProducts(playbook *strategy.Playbook, catalog []domain.CatalogCard, wallet []domain.WalletCard) {
	for i := range playbook.Steps {
		step := &playbook.Steps[i]
		if step.CardID != "" {
			continue
		}
		if step.Status == "have" {
			id := ""
			matches := 0
			for _, held := range wallet {
				if held.Status == "active" && held.Card != nil && held.Card.Name == step.CoveredBy {
					id = held.CatalogCardID
					matches++
				}
			}
			if matches == 1 {
				step.CardID = id
			}
			continue
		}
		name := step.Name
		if name == "Gold" {
			name = "Amex Gold"
		}
		for _, card := range catalog {
			if card.Name == name {
				step.CardID = card.ID
				break
			}
		}
	}
}

func walletNamesExcept(wallet, exclude []domain.WalletCard) []string {
	skip := map[string]bool{}
	for _, held := range exclude {
		skip[held.CatalogCardID] = true
	}
	names := make([]string, 0, len(wallet))
	for _, held := range wallet {
		if held.Status != "active" || held.Card == nil || skip[held.CatalogCardID] {
			continue
		}
		names = append(names, held.Card.Name)
	}
	return names
}
