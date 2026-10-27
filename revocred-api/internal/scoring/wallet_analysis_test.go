package scoring

import (
	"testing"

	"github.com/revocred/revocred-api/internal/domain"
)

func TestAnalyzeWalletUsesActiveCardsAndLatestRates(t *testing.T) {
	wallet := []domain.WalletCard{
		{Status: "active", Card: &domain.CatalogCard{
			Issuer: "Bank A", AnnualFeeCents: 39500, TransferablePoints: true,
			RewardRates: map[string]float64{"other": 2, "dining": 3, "travel": 5},
		}},
		{Status: "active", Card: &domain.CatalogCard{
			Issuer: "Bank B", RewardRates: map[string]float64{"groceries": 4, "gas": 3},
		}},
		{Status: "inactive", Card: &domain.CatalogCard{
			Issuer: "Bank C", RewardRates: map[string]float64{"dining": 10},
		}},
	}

	got := AnalyzeWallet(wallet)
	if got.CatchAll != 2 || got.Dining != 3 || got.Groceries != 4 || got.Gas != 3 || got.Travel != 5 {
		t.Fatalf("rates = %+v", got)
	}
	if !got.TransferPartners || !got.PremiumBenefits || !got.EcosystemDiversity {
		t.Fatalf("benefits = %+v", got)
	}
}

func TestAnalyzeWalletHandlesMissingCatalogCard(t *testing.T) {
	got := AnalyzeWallet([]domain.WalletCard{{Status: "active"}})
	if got != (Wallet{}) {
		t.Fatalf("got %+v, want empty wallet", got)
	}
}

func TestMetricsReturnsScoreAndYearlyValue(t *testing.T) {
	wallet := []domain.WalletCard{{Status: "active", Card: &domain.CatalogCard{
		RewardRates: map[string]float64{"other": 2, "dining": 4},
	}}}
	got := Metrics(wallet, map[string]int64{"food": 10000, "everyday": 10000})
	if got.Score != 64 || got.Rating != "Fair" || got.YearlyValue != 48 {
		t.Fatalf("got %+v", got)
	}
}

func TestMetricsExposesOngoingBreakdownAndIgnoresInactive(t *testing.T) {
	c := domain.CatalogCard{AnnualFeeCents: 1000, RewardRates: map[string]float64{"other": 2}}
	got := Metrics([]domain.WalletCard{{Status: "active", Card: &c}, {Status: "inactive", Card: &c}}, map[string]int64{"everyday": 10000})
	if got.OngoingValue.TotalCents != 1400 || got.OngoingValue.FeesCents != 1000 || got.YearlyValue != 14 {
		t.Fatalf("%+v", got)
	}
}

func TestMonthlySpendingFromCategoryCents(t *testing.T) {
	got := MonthlySpendingFromCategoryCents(map[string]int64{
		"rent":      150050,
		"dining":    20000,
		"groceries": 30000,
		"travel":    40000,
		"other":     50000,
	})
	want := MonthlySpending{RentOrHousing: 1501, DiningGrocery: 500, Traveling: 400, Other: 500}
	if got != want {
		t.Fatalf("got %+v, want %+v", got, want)
	}
}
