package chat

import (
	"github.com/revocred/revocred-api/internal/domain"
	"strings"
	"testing"
)

func TestChatGetsActualOngoingBreakdownAndSeparateRankingModel(t *testing.T) {
	input := Context{Metrics: domain.WalletMetrics{YearlyValue: 203, OngoingValue: domain.OngoingValue{RewardsCents: 28800, CreditsCents: 21000, AnniversaryCents: 10000, FeesCents: 39500, TotalCents: 20300}}}
	got := Snapshot(input)
	if got.YearlyValueUSD != 203 || got.OngoingWalletBreakdown.CreditsCents != 21000 {
		t.Fatalf("%+v", got)
	}
	for _, s := range []string{"70%", "budget does not prove merchant use", "welcome bonuses are excluded", "Application rankings still use"} {
		if !strings.Contains(got.Disclaimer, s) {
			t.Fatalf("missing %q", s)
		}
	}
}
