package chat

import (
	"github.com/revocred/revocred-api/internal/domain"
	"github.com/revocred/revocred-api/internal/strategy"
)

// DemoBrowseContext is the on-screen guest wallet. It is not a live account.
func DemoBrowseContext() Context {
	gold := domain.CatalogCard{
		Name: "Amex Gold", Issuer: "American Express", AnnualFeeCents: 32500,
		BestUse: "Dining and groceries", RewardsType: "travel",
		RewardRates:        map[string]float64{"dining": 4, "groceries": 4, "flights": 3, "other": 1},
		TransferablePoints: true,
	}
	venture := domain.CatalogCard{
		Name: "Venture X", Issuer: "Capital One", AnnualFeeCents: 39500,
		BestUse: "Premium travel", RewardsType: "travel",
		RewardRates:        map[string]float64{"hotels": 10, "flights": 5, "other": 2},
		TransferablePoints: true,
	}
	unlimited := domain.CatalogCard{
		Name: "Freedom Unlimited", Issuer: "Chase", AnnualFeeCents: 0,
		BestUse: "Everyday catch-all", RewardsType: "cash_back",
		RewardRates: map[string]float64{"dining": 3, "other": 1.5},
	}
	playbook := strategy.Build("S04", []string{gold.Name, venture.Name, unlimited.Name}, nil)
	return Context{
		SessionID: "demo-browse",
		Wallet: []domain.WalletCard{
			{Status: "active", Card: &gold},
			{Status: "active", Card: &venture},
			{Status: "active", Card: &unlimited},
		},
		Recommendations: &domain.RecommendationResult{
			StrategyCode: "S04",
			Items: []domain.RecommendationItem{{
				CardName: "Sapphire Preferred",
				Reasons:  []string{"Demo next card in the S04 playbook. Not a live recommendation."},
			}},
		},
		Questionnaire: &domain.RecommendationInput{
			MonthlyCategorySpend: map[string]int64{"food": 45000, "travel": 15000, "everyday": 30000},
			CreditTier:           "fair",
			RewardsGoal:          "travel",
			TravelScope:          "both",
			FeeToleranceCents:    10000,
		},
		Metrics:  domain.WalletMetrics{Score: 88, Rating: "Great", YearlyValue: 468},
		Playbook: &playbook,
	}
}
