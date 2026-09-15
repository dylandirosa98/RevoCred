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
		{name: "transfer partners", wallet: Wallet{TransferPartners: true}, want: 4},
		{name: "premium benefits", wallet: Wallet{PremiumBenefits: true}, want: 2},
		{name: "ecosystem diversity", wallet: Wallet{EcosystemDiversity: true}, want: 1},
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

func TestEmptyWalletDoesNotStackCatchAllPenalties(t *testing.T) {
	got := Score(Wallet{})
	if got.Penalties != -26 {
		t.Fatalf("penalties = %d, want -26", got.Penalties)
	}
	if got.Score != 24 {
		t.Fatalf("score = %d, want 24", got.Score)
	}
	if got.Rating != "Poor" {
		t.Fatalf("rating = %q, want Poor", got.Rating)
	}
}

func TestNoRewardsReplacesMissingCatchAllPenalty(t *testing.T) {
	got := Score(Wallet{})
	oneX := Score(Wallet{CatchAll: 1, Dining: 1, Groceries: 1, Gas: 1, Travel: 1, Flights: 1, Hotels: 1})
	if got.Penalties != oneX.Penalties {
		t.Fatalf("empty wallet penalties %d, explicit 1x wallet %d", got.Penalties, oneX.Penalties)
	}
}

func TestTwoXCatchAllSkipsOneXCategoryPenalties(t *testing.T) {
	got := Score(Wallet{CatchAll: 2})
	if got.Penalties != -4 {
		t.Fatalf("penalties = %d, want -4 (flights and hotels not above catch-all)", got.Penalties)
	}
	if got.Score != 56 {
		t.Fatalf("score = %d, want 56", got.Score)
	}
	if got.Rating != "Fair" {
		t.Fatalf("rating = %q, want Fair", got.Rating)
	}
}

func TestFlightAboveCatchAllDropsFlightPenalty(t *testing.T) {
	got := Score(Wallet{CatchAll: 2, Flights: 5, Hotels: 5})
	if got.Penalties != 0 {
		t.Fatalf("penalties = %d, want 0", got.Penalties)
	}
}

func TestOverlapPenaltiesDoNotStack(t *testing.T) {
	got := Score(Wallet{MajorOverlap: true, MultipleOverlap: true})
	if got.Penalties != -28 {
		t.Fatalf("penalties = %d, want -28", got.Penalties)
	}
	if got.Score != 22 {
		t.Fatalf("score = %d, want 22", got.Score)
	}
}

func TestMajorOverlapAloneIsMinusTwo(t *testing.T) {
	base := Score(Wallet{})
	got := Score(Wallet{MajorOverlap: true})
	if got.Penalties != base.Penalties-2 {
		t.Fatalf("penalties = %d, want %d", got.Penalties, base.Penalties-2)
	}
}

func TestScoreClampedToLimits(t *testing.T) {
	low := Score(Wallet{MultipleOverlap: true})
	if low.Score != 22 {
		t.Fatalf("floor score = %d, want 22", low.Score)
	}
	high := Score(maxedWallet())
	if high.Score != 95 {
		t.Fatalf("ceiling score = %d, want 95", high.Score)
	}
}

func TestMaxedWalletIsElite(t *testing.T) {
	got := Score(maxedWallet())
	if got.Score != 95 || got.Rating != "Elite" || got.Penalties != 0 || got.Additions != 45 {
		t.Fatalf("got %+v, want score 95 Elite additions 45 no penalties", got)
	}
}

func TestRatings(t *testing.T) {
	tests := []struct {
		score int
		want  string
	}{
		{22, "Poor"},
		{49, "Poor"},
		{50, "Fair"},
		{64, "Fair"},
		{65, "Good"},
		{79, "Good"},
		{80, "Great"},
		{89, "Great"},
		{90, "Elite"},
		{95, "Elite"},
	}
	for _, tc := range tests {
		if got := ratingFor(tc.score); got != tc.want {
			t.Fatalf("ratingFor(%d) = %q, want %q", tc.score, got, tc.want)
		}
	}
}

func maxedWallet() Wallet {
	return Wallet{
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
	}
}
