package carddata

// referenceBindings ties search-index rows (card_reference_index.slug) to the
// exact OpenCard product with the same issuer and product name. Reviewed by
// hand against the 2026-11-09 snapshot; never fuzzy-matched at runtime.
//
// Deliberately unbound:
//   - "*-index" rows: they resolve to the vetted catalog card, whose issuer
//     terms always win.
//   - slate: OpenCard only has "Slate Edge", a different product name.
//   - Kohl's, BJ's One/One+, Bass Pro Shops, Cabela's, One Key+, Citi Secured
//     Mastercard and Altitude Go Secured: not in the feed.
//
// A binding identifies the product only. MapTerms still decides whether its
// rates can be scored (hotel currencies, for example, stay unscored).
var referenceBindings = map[string]string{
	// American Express (index rows verified 2026-10-13)
	"amex-blue-cash-everyday":        "us-amex-blue-cash-everyday",
	"amex-blue-cash-preferred":       "us-amex-blue-cash-preferred",
	"amex-delta-skymiles-blue":       "us-amex-delta-skymiles-blue",
	"amex-delta-skymiles-gold":       "us-amex-delta-skymiles-gold",
	"amex-delta-skymiles-platinum":   "us-amex-delta-skymiles-platinum",
	"amex-delta-skymiles-reserve":    "us-amex-delta-skymiles-reserve",
	"amex-hilton-honors":             "us-amex-hilton-honors",
	"amex-hilton-honors-surpass":     "us-amex-hilton-honors-surpass",
	"amex-hilton-honors-aspire":      "us-amex-hilton-honors-aspire",
	"amex-marriott-bonvoy-brilliant": "us-amex-marriott-bonvoy-brilliant",
	"amex-marriott-bonvoy-bevy":      "us-amex-marriott-bonvoy-bevy",
	// Chase (index rows captured 2026-09-26)
	"aer-lingus-visa-signature":        "us-chase-aer-lingus-signature",
	"air-canada-aeroplan-card":         "us-chase-aeroplan",
	"amazon-visa":                      "us-chase-amazon-visa",
	"british-airways-visa-signature":   "us-chase-british-airways-signature",
	"disney-inspire-visa-card":         "us-chase-disney-inspire",
	"disney-premier-visa-card":         "us-chase-disney-premier",
	"disney-visa-card":                 "us-chase-disney",
	"doordash-rewards-mastercard":      "us-chase-doordash-rewards-mastercard",
	"ihg-one-rewards-premier":          "us-chase-ihg-premier",
	"ihg-one-rewards-traveler":         "us-chase-ihg-traveler",
	"iberia-visa-signature":            "us-chase-iberia-signature",
	"instacart-mastercard":             "us-chase-instacart-mastercard",
	"marriott-bonvoy-bold":             "us-chase-marriott-bonvoy-bold",
	"marriott-bonvoy-boundless":        "us-chase-marriott-bonvoy-boundless",
	"marriott-bonvoy-bountiful":        "us-chase-marriott-bonvoy-bountiful",
	"prime-visa":                       "us-chase-amazon-prime",
	"southwest-rapid-rewards-plus":     "us-chase-southwest-plus",
	"southwest-rapid-rewards-premier":  "us-chase-southwest-premier",
	"southwest-rapid-rewards-priority": "us-chase-southwest-priority",
	// Chase renamed United Club Infinite to United Club Card; OpenCard keeps
	// the old name under the same product ID and the same $695 fee.
	"united-club-card":     "us-chase-united-club",
	"united-explorer-card": "us-chase-united-explorer",
	"united-gateway-card":  "us-chase-united-gateway",
	"united-quest-card":    "us-chase-united-quest",
	"world-of-hyatt":       "us-chase-world-of-hyatt",
	// Discover
	"discover-discover-it-cash-back":                  "us-discover-it-cash-back",
	"discover-discover-it-miles":                      "us-discover-it-miles",
	"discover-discover-it-chrome-gas-and-restaurants": "us-discover-it-chrome",
	"discover-discover-it-student-cash-back":          "us-discover-it-student-cash-back",
	"discover-discover-it-student-chrome":             "us-discover-it-student-chrome",
	// Capital One
	"capital-one-venture-rewards":                  "us-capital-one-venture",
	"capital-one-ventureone-rewards":               "us-capital-one-ventureone",
	"capital-one-savor-rewards":                    "us-capital-one-savor",
	"capital-one-quicksilverone-rewards":           "us-capital-one-quicksilverone",
	"capital-one-quicksilver-secured-rewards":      "us-capital-one-quicksilver-secured-cash-rewards",
	"capital-one-quicksilver-rewards-for-students": "us-capital-one-quicksilver-student-cash-rewards",
	"capital-one-platinum":                         "us-capital-one-platinum",
	"capital-one-platinum-secured":                 "us-capital-one-platinum-secured",
	"capital-one-t-mobile-visa":                    "us-capital-one-t-mobile-visa",
	"capital-one-rei-co-op-mastercard":             "us-capital-one-rei-co-op-mastercard",
	// Citi
	"citi-strata-premier":                      "us-citi-strata-premier",
	"citi-simplicity":                          "us-citi-simplicity",
	"citi-diamond-preferred":                   "us-citi-diamond-preferred",
	"citi-aadvantage-platinum-select":          "us-citi-aadvantage-platinum-select-world-elite",
	"citi-aadvantage-executive":                "us-citi-aadvantage-executive",
	"citi-aadvantage-globe":                    "us-citi-aadvantage-globe",
	"citi-aadvantage-mileup":                   "us-citi-aadvantage-mileup",
	"citi-costco-anywhere-visa":                "us-citi-costco-anywhere-visa-card-by-citi",
	"citi-at-and-t-points-plus":                "us-citi-at-and-t-points-plus",
	"citi-my-best-buy-credit-card":             "us-citi-my-best-buy-credit-card",
	"citi-the-home-depot-consumer-credit-card": "us-citi-home-depot-consumer",
	"citi-macys-credit-card":                   "us-citi-macys-credit-card",
	// Wells Fargo
	"wells-fargo-active-cash":                         "us-wells-fargo-active-cash",
	"wells-fargo-autograph":                           "us-wells-fargo-autograph",
	"wells-fargo-autograph-journey":                   "us-wells-fargo-autograph-journey",
	"wells-fargo-reflect":                             "us-wells-fargo-reflect",
	"wells-fargo-one-key":                             "us-wells-fargo-expedia-one-key",
	"wells-fargo-choice-privileges-mastercard":        "us-wells-fargo-choice-privileges",
	"wells-fargo-choice-privileges-select-mastercard": "us-wells-fargo-choice-privileges-select",
	// U.S. Bank
	"u-s-bank-altitude-go-visa-signature":      "us-us-bank-altitude-go",
	"u-s-bank-altitude-connect-visa-signature": "us-us-bank-altitude-connect",
	"u-s-bank-cash-plus-visa-signature":        "us-us-bank-cash-plus",
	"u-s-bank-smartly-visa-signature":          "us-us-bank-smartly",
	"u-s-bank-shield-visa":                     "us-us-bank-shield-visa",
	// Bank of America (index rows captured 2026-09-30)
	"bank-of-america-atmos-rewards-ascent-visa-signature": "us-bank-of-america-atmos-rewards-ascent",
	"bank-of-america-atmos-rewards-summit-visa-infinite":  "us-bank-of-america-atmos-rewards-summit",
}
