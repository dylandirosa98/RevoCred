package purchaseguide

func regular(categories ...string) rule {
	return rule{Categories: categories, Note: "Eligible merchants only; issuer merchant coding and exclusions apply."}
}
func conditional(note string, categories ...string) rule {
	return rule{Categories: categories, Conditional: true, Note: note}
}

var categoryReviewed = map[string]map[string]rule{
	"us-capital-one-quicksilver": {
		"Capital One Entertainment purchases":                                                    conditional("Only purchases through Capital One Entertainment, not general entertainment merchants.", "entertainment"),
		"Hotels, rental cars, vacation rentals and activities booked through Capital One Travel": {Categories: []string{"travel"}, Modes: []string{"capital-one-hotels-cars", "capital-one-flights-vacation"}, Note: "Only the stated eligible Capital One Travel purchase types; not flights booked direct or general travel."},
	},
	"us-capital-one-savor-student-cash-rewards": {
		"Grocery stores (excludes superstores like Walmart & Target)":           regular("groceries"),
		"Dining (restaurants, cafes, bars, fast food, bakeries)":                regular("dining"),
		"Entertainment (movie theaters, live events, amusement parks and more)": regular("entertainment"),
		"Popular streaming services (e.g. Netflix, Hulu, Disney+)":              regular("streaming"),
	},
	"us-capital-one-savorone": {
		"Grocery stores, dining, entertainment and popular streaming services": regular("groceries", "dining", "entertainment", "streaming"),
	},
	"us-capital-one-venture-x": {
		"Capital One Entertainment purchases": conditional("Only purchases through Capital One Entertainment, not general entertainment merchants.", "entertainment"),
	},
	"us-chase-freedom-flex": {
		"Quarterly bonus categories after activation":                             conditional("Current-quarter category eligibility and activation are not known. Do not assume a specific category qualifies. $1,500 quarterly combined spending cap applies.", "groceries", "gas", "online-shopping", "wholesale-clubs", "general-purchases"),
		"Dining at restaurants, including takeout and eligible delivery services": regular("dining"),
		"Drugstore purchases":                       regular("drugstores"),
		"Lyft purchases through September 30, 2027": conditional("Only eligible Lyft purchases through September 30, 2027; not general transit.", "transit"),
	},
	"us-chase-freedom-rise": {
		"Dining at restaurants incl. takeout & eligible delivery (new cardmembers, first 6 months)":   conditional("New-cardmember first-six-month eligibility is not known. Do not assume this promotional rate applies.", "dining"),
		"Lyft rideshare, bike/scooter, and membership purchased in the Lyft app (through 09/30/2027)": conditional("Eligible Lyft app purchases only through September 30, 2027; not general transit.", "transit"),
	},
	"us-chase-freedom-unlimited": {
		"Dining at restaurants, including takeout and eligible delivery services": regular("dining"),
		"Drugstore purchases":                          regular("drugstores"),
		"Qualifying Lyft purchases through 09/30/2027": conditional("Qualifying Lyft purchases only through September 30, 2027; not general transit.", "transit"),
	},
	"us-chase-sapphire-preferred": {
		"Dining including eligible delivery services":                           regular("dining"),
		"Select streaming services":                                             regular("streaming"),
		"Online grocery purchases (excluding Target, Walmart, wholesale clubs)": conditional("Only eligible online grocery purchases; not in-store groceries, ordinary online shopping, Target, Walmart or wholesale clubs.", "groceries"),
	},
	"us-chase-sapphire-reserve": {
		"Dining worldwide": regular("dining"),
	},
	"us-citi-strata": {
		"Supermarkets": regular("groceries"),
		"Gas and EV charging stations and select transit": regular("gas", "transit"),
		"One self-select category (fitness clubs, select streaming, live entertainment, cosmetic stores/barber shops/hair salons, or pet supply stores)": conditional("The cardholder's selected category is not known. Only the elected category qualifies.", "streaming", "entertainment"),
		"Restaurants": regular("dining"),
	},
	"us-citi-strata-elite": {
		"Restaurants on Citi Nights (Friday & Saturday 6 PM - 6 AM ET)": conditional("Only eligible restaurant transactions during Citi Nights: Friday/Saturday 6 PM–6 AM Eastern. Confirm transaction eligibility; not a universal dining rate.", "dining"),
		"Restaurants (any other time)":                                  regular("dining"),
	},
	"us-discover-it-cash-back": {
		"Rotating quarterly categories (activation required)": conditional("Current-quarter category eligibility and activation are not known. Do not assume a specific category qualifies. $1,500 quarterly combined spending cap applies.", "groceries", "gas", "online-shopping", "wholesale-clubs", "general-purchases"),
	},
}
