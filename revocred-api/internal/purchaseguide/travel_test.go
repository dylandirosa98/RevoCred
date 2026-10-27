package purchaseguide

import (
	"testing"
)

func TestDirectAndPortalBookingsNeverBorrowEachOthersMultipliers(t *testing.T) {
	wallet := exampleWallet(t)
	for _, id := range []string{"us-amex-platinum", "us-capital-one-venture-x", "us-citi-strata-elite", "us-chase-sapphire-preferred"} {
		wallet = append(wallet, sourceCard(t, id))
	}
	cases := []struct {
		mode, card string
		rate       float64
	}{
		{"general", "us-capital-one-venture-x", 2},
		{"flights-direct", "us-amex-platinum", 5},
		{"hotels-direct", "us-chase-sapphire-reserve", 4},
		{"chase-portal", "us-chase-sapphire-reserve", 8},
		{"capital-one-hotels-cars", "us-capital-one-venture-x", 10},
		{"capital-one-flights-vacation", "us-capital-one-venture-x", 5},
		{"citi-hotels-cars-attractions", "us-citi-strata-elite", 12},
		{"citi-flights", "us-citi-strata-elite", 6},
		{"amex-flights", "us-amex-platinum", 5},
		{"amex-prepaid-hotels", "us-amex-platinum", 5},
	}
	for _, tc := range cases {
		t.Run(tc.mode, func(t *testing.T) {
			settings := DefaultOptions()
			settings.TravelMode = tc.mode
			g := category(t, Build(wallet, settings), "travel")
			if len(g.Options) == 0 || g.Options[0].CardID != tc.card || g.Options[0].Rate != tc.rate {
				t.Fatalf("wrong %s winner: %+v", tc.mode, g.Options)
			}
		})
	}
}
