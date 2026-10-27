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
		Benefits:           []string{"4x restaurants worldwide; caps can apply", "4x U.S. supermarkets; caps can apply", "3x flights booked with airlines or Amex Travel"},
		TransferablePoints: true,
	}
	venture := domain.CatalogCard{
		Name: "Venture X", Issuer: "Capital One", AnnualFeeCents: 39500,
		BestUse: "Premium travel", RewardsType: "travel",
		RewardRates:        map[string]float64{"hotels": 10, "flights": 5, "other": 2},
		Benefits:           []string{"10x hotels and rental cars through Capital One Travel", "5x flights through Capital One Travel", "2x miles on other purchases"},
		TransferablePoints: true,
	}
	unlimited := domain.CatalogCard{
		Name: "Freedom Unlimited", Issuer: "Chase", AnnualFeeCents: 0,
		BestUse: "Everyday catch-all", RewardsType: "cash_back",
		RewardRates: map[string]float64{"dining": 3, "other": 1.5},
		Benefits:    []string{"3% cash back on dining and drugstores", "1.5% cash back on other purchases", "$0 annual fee"},
	}
	flex := domain.CatalogCard{
		Name: "Freedom Flex", Issuer: "Chase", AnnualFeeCents: 0,
		BestUse: "Rotating categories and dining", RewardsType: "cash_back",
		RewardRates: map[string]float64{"dining": 3, "other": 1},
		Benefits:    []string{"5% rotating categories when activated; quarterly cap applies", "3% cash back on dining and drugstores", "$0 annual fee"},
	}
	preferred := domain.CatalogCard{
		Name: "Sapphire Preferred", Issuer: "Chase", AnnualFeeCents: 9500,
		BestUse: "Transferable travel points starter", RewardsType: "travel",
		RewardRates:        map[string]float64{"dining": 3, "travel": 2, "other": 1},
		Benefits:           []string{"$95 annual fee", "5x Chase Travel", "3x dining", "2x other travel"},
		TransferablePoints: true,
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
			Items: []domain.RecommendationItem{
				{
					CardName: "Freedom Flex", Rank: 1, OngoingEstimate: 12000,
					Reasons: []string{"Adds rotating categories and dining to the Chase setup in this demo."},
				},
				{
					CardName: "Sapphire Preferred", Rank: 2, OngoingEstimate: 9000,
					Reasons: []string{"A later travel-points hub in the same Chase roadmap."},
				},
			},
		},
		Catalog: []domain.CatalogCard{flex, preferred},
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
