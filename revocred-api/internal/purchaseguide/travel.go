package purchaseguide

func travel(modes ...string) rule {
	return rule{Categories: []string{"travel"}, Modes: modes, Note: "Only for the stated booking channel and eligible purchase type. Purchases offset by issuer credits may not earn points."}
}

var travelReviewed = map[string]map[string]rule{
	"us-amex-gold": {
		"Flights booked directly with airlines or via Amex Travel": travel("flights-direct", "amex-flights"),
	},
	"us-amex-platinum": {
		"Flights booked directly with airlines or through American Express Travel": travel("flights-direct", "amex-flights"),
		"Prepaid hotels booked on American Express Travel":                         travel("amex-prepaid-hotels"),
	},
	"us-capital-one-venture-x": {
		"Hotels and rental cars booked through Capital One Travel":       travel("capital-one-hotels-cars"),
		"Flights and vacation rentals booked through Capital One Travel": travel("capital-one-flights-vacation"),
	},
	"us-chase-sapphire-preferred": {
		"Travel booked through Chase Travel": travel("chase-portal"),
		// Scope: https://www.chase.com/personal/credit-cards/rewards-category-faq
		// Issuer travel includes trains, buses, taxis, ferries, tolls and parking.
		// Portal-only and Reserve direct-flight/hotel rules do not share this scope.
		"Other travel": {Categories: []string{"travel", "transit"}, Note: "Eligible travel includes passenger trains, buses, taxis, limousines, ferries, toll bridges/highways and parking lots/garages. Merchant coding applies; Chase Travel has its own separate earning rule. Scope: https://www.chase.com/personal/credit-cards/rewards-category-faq"},
	},
	"us-chase-sapphire-reserve": {
		"Purchases through Chase Travel, including The Edit": travel("chase-portal"),
		"Flights booked direct":                              travel("flights-direct"),
		"Hotels booked direct":                               travel("hotels-direct"),
	},
	"us-chase-freedom-flex": {
		"Travel purchased through Chase Travel": travel("chase-portal"),
	},
	"us-chase-freedom-unlimited": {
		"Travel purchased through Chase Travel": travel("chase-portal"),
	},
	"us-citi-double-cash": {
		"Hotels, car rentals, and attractions booked through Citi Travel": travel("citi-hotels-cars-attractions"),
	},
	"us-citi-strata": {
		"Hotels, car rentals and attractions booked on cititravel.com": travel("citi-hotels-cars-attractions"),
	},
	"us-citi-strata-elite": {
		"Hotels, Car Rentals & Attractions booked on cititravel.com": travel("citi-hotels-cars-attractions"),
		"Air Travel booked on cititravel.com":                        travel("citi-flights"),
	},
}

var TravelModes = map[string]string{
	"general":                      "General travel (not a specific booking channel)",
	"flights-direct":               "Flights booked directly with an airline",
	"hotels-direct":                "Hotels booked directly",
	"chase-portal":                 "Purchases through Chase Travel",
	"capital-one-hotels-cars":      "Capital One Travel: hotels and rental cars",
	"capital-one-flights-vacation": "Capital One Travel: flights and vacation rentals",
	"citi-hotels-cars-attractions": "Citi Travel: hotels, cars and attractions",
	"citi-flights":                 "Citi Travel: flights",
	"amex-flights":                 "Amex Travel: flights",
	"amex-prepaid-hotels":          "Amex Travel: prepaid hotels",
}
