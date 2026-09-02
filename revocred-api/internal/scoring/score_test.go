package scoring

import "testing"

func TestCatchAllTwoXAddsTenTotal(t *testing.T) {
	got := Score(Wallet{CatchAll: 2})
	if got.Additions != 10 {
		t.Fatalf("additions = %d, want 10", got.Additions)
	}
}

func TestAdditionTiersDoNotStack(t *testing.T) {
	tests := []struct {
		name   string
		wallet Wallet
		want   int
	}{
		{name: "1.5x catch-all", wallet: Wallet{CatchAll: 1.5}, want: 5},
		{name: "2x catch-all replaces 1.5x", wallet: Wallet{CatchAll: 2}, want: 10},
		{name: "3x dining", wallet: Wallet{Dining: 3}, want: 4},
		{name: "4x dining replaces 3x", wallet: Wallet{Dining: 4}, want: 8},
		{name: "groceries 3x", wallet: Wallet{Groceries: 3}, want: 6},
		{name: "gas 3x", wallet: Wallet{Gas: 3}, want: 3},
		{name: "travel 2x", wallet: Wallet{Travel: 2}, want: 4},
		{name: "flights 5x", wallet: Wallet{Flights: 5}, want: 4},
		{name: "hotels 5x", wallet: Wallet{Hotels: 5}, want: 3},
		{
			name:   "transfer partners",
			wallet: Wallet{TransferPartners: true},
			want:   4,
		},
		{
			name:   "premium benefits",
			wallet: Wallet{PremiumBenefits: true},
			want:   2,
		},
		{
			name:   "ecosystem diversity",
			wallet: Wallet{EcosystemDiversity: true},
			want:   1,
		},
		{
			name: "all max additions",
			wallet: Wallet{
				CatchAll:           2,
				Dining:             4,
				Groceries:          3,
				Gas:                3,
				Travel:             2,
				Flights:            5,
				Hotels:             5,
				TransferPartners:   true,
				PremiumBenefits:    true,
				EcosystemDiversity: true,
			},
			want: 45,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := Score(tc.wallet)
			if got.Additions != tc.want {
				t.Fatalf("additions = %d, want %d", got.Additions, tc.want)
			}
		})
	}
}
