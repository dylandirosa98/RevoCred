package carddata

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"reflect"
	"strings"
	"testing"
	"time"
)

// terms_fixture.json holds real OpenCard DB rows copied verbatim from the
// 2026-11-09 snapshot, chosen to exercise every mapping rule.
func fixtureRecords(t *testing.T, path string) map[string]Card {
	t.Helper()
	body, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var records []Card
	if err := json.Unmarshal(body, &records); err != nil {
		t.Fatal(err)
	}
	byID := map[string]Card{}
	for _, r := range records {
		byID[r.ID] = r
	}
	return byID
}

func TestMapTermsRealRows(t *testing.T) {
	records := fixtureRecords(t, "testdata/terms_fixture.json")
	scored := []struct {
		id           string
		rates        map[string]float64
		feeCents     int
		rewardsType  string
		transferable bool
		notScored    map[string]string // label substring -> reason substring
	}{
		// Flat everyday dining is scored; portal, drugstore and dated Lyft rates are not.
		{"us-chase-freedom-unlimited", map[string]float64{"other": 1.5, "dining": 3}, 0, "cash_back", false,
			map[string]string{"Chase Travel": "portal", "Drugstore": "no supported", "Lyft": "temporary"}},
		{"us-citi-double-cash", map[string]float64{"other": 2}, 0, "cash_back", false,
			map[string]string{"Citi Travel": "portal"}},
		{"us-wells-fargo-active-cash", map[string]float64{"other": 2}, 0, "cash_back", false, nil},
		// Every bonus is capped at $6,000/year, so only the base rate counts.
		{"us-amex-blue-cash-everyday", map[string]float64{"other": 1}, 0, "cash_back", false,
			map[string]string{"supermarkets": "capped", "gas stations": "capped", "online retail": "online"}},
		// Uncapped 6% streaming and 3% gas count; capped 6% groceries does not.
		{"us-amex-blue-cash-preferred", map[string]float64{"other": 1, "streaming": 6, "gas": 3}, 9500, "cash_back", false,
			map[string]string{"supermarkets": "capped"}},
		// Membership Rewards with stated transfer partners; capped supermarkets excluded.
		{"us-amex-gold", map[string]float64{"other": 1, "dining": 4}, 32500, "travel", true,
			map[string]string{"supermarkets": "capped"}},
		{"us-discover-it-cash-back", map[string]float64{"other": 1}, 0, "cash_back", false,
			map[string]string{"Rotating": "rotating"}},
		{"us-us-bank-cash-plus", map[string]float64{"other": 1}, 0, "cash_back", false,
			map[string]string{"choose each quarter": "", "Travel Center": ""}},
		{"us-citi-custom-cash", map[string]float64{"other": 1}, 0, "cash_back", false,
			map[string]string{"Top eligible": "cardholder-chosen"}},
		{"us-capital-one-venture", map[string]float64{"other": 2}, 9500, "travel", true,
			map[string]string{"Capital One Travel": "portal"}},
		// Exclusion clauses ("excluding superstores") do not block a generic category.
		{"us-capital-one-savor", map[string]float64{"other": 1, "dining": 3, "groceries": 3, "streaming": 3}, 0, "cash_back", false,
			map[string]string{"Capital One Travel": "portal"}},
		{"us-wells-fargo-autograph", map[string]float64{"other": 1, "dining": 3, "travel": 3, "gas": 3, "streaming": 3}, 0, "travel", false,
			map[string]string{"Phone plans": "merchant-specific"}},
		// Merchant-specific United rates are not general flights; direct hotels and dining count.
		{"us-chase-united-explorer", map[string]float64{"other": 1, "dining": 2, "hotels": 2}, 15000, "travel", false,
			map[string]string{"United flights": "merchant-specific", "United purchases": "merchant-specific"}},
		// Airline currency is never transferable, whatever the redemption text says.
		{"us-chase-southwest-plus", map[string]float64{"other": 1}, 9900, "travel", false, nil},
		{"us-chase-sapphire-reserve", map[string]float64{"other": 1, "dining": 3, "flights": 4, "hotels": 4}, 79500, "travel", true,
			map[string]string{"Chase Travel": "portal"}},
	}
	for _, tc := range scored {
		t.Run(tc.id, func(t *testing.T) {
			r, ok := records[tc.id]
			if !ok {
				t.Fatal("fixture row missing")
			}
			terms, err := MapTerms(r)
			if err != nil {
				t.Fatalf("unexpectedly unscored: %v", err)
			}
			if !reflect.DeepEqual(terms.RewardRates, tc.rates) {
				t.Fatalf("rates = %v, want %v", terms.RewardRates, tc.rates)
			}
			if terms.AnnualFeeCents != tc.feeCents || terms.RewardsType != tc.rewardsType || terms.TransferablePoints != tc.transferable {
				t.Fatalf("fee/type/transfer = %d/%s/%v", terms.AnnualFeeCents, terms.RewardsType, terms.TransferablePoints)
			}
			if terms.ProductID != tc.id || terms.SourceName != TermsSourceName || terms.MappingVersion != TermsMappingVersion || terms.LastVerified != r.LastVerified {
				t.Fatalf("provenance missing: %+v", terms)
			}
			// Every source rule is accounted for exactly once.
			if len(terms.Scored)-1+len(terms.NotScored) != len(r.Rewards.Categories) {
				t.Fatalf("rules lost: %d scored + %d not scored for %d", len(terms.Scored)-1, len(terms.NotScored), len(r.Rewards.Categories))
			}
			for label, reason := range tc.notScored {
				found := false
				for _, rule := range terms.NotScored {
					if strings.Contains(rule.Label, label) && strings.Contains(rule.Reason, reason) {
						found = true
					}
				}
				if !found {
					t.Fatalf("expected %q excluded (%q): %+v", label, reason, terms.NotScored)
				}
			}
		})
	}

	unscored := map[string]string{
		"us-robinhood-gold-card":          "base rate is conditional",
		"us-barclays-arrival":             "not active",
		"us-us-bank-skypass-visa-classic": "not active",
		"us-citi-macys-credit-card":       "store card",
		"us-capital-one-platinum":         "no rewards currency",
		"us-us-bank-smartly":              "base rate is conditional",
		"us-wells-fargo-propel":           "not active",
		"us-synchrony-dicks-credit-card":  "store card",
		"us-citi-my-best-buy-credit-card": "",
	}
	for id, reason := range unscored {
		r, ok := records[id]
		if !ok {
			t.Fatalf("fixture row %s missing", id)
		}
		if terms, err := MapTerms(r); err == nil || !strings.Contains(err.Error(), reason) {
			t.Fatalf("%s should be unscored (%q): %+v %v", id, reason, terms, err)
		}
	}
}

func TestClassifyLabelRules(t *testing.T) {
	cases := map[string]string{
		"Restaurants worldwide":                                       "dining",
		"U.S. supermarkets":                                           "groceries",
		"Gas stations and EV charging stations":                       "gas",
		"Air travel and hotel stays":                                  "flights,hotels",
		"Travel (flights, hotels, car rentals)":                       "flights,hotels,travel",
		"Popular streaming services (e.g. Netflix, Hulu, Disney+)":    "streaming",
		"Grocery stores (excludes superstores like Walmart & Target)": "groceries",
		"Hilton hotels and resorts":                                   "",
		"Gas at Costco":                                               "",
		"Dining (through 12/31/2026)":                                 "",
		"Hotels and rental cars booked through Capital One Travel":    "",
		"Grocery stores and dining at restaurants (first $8,000 combined each account anniversary year, then 1x)": "",
		"Restaurants on Citi Nights (Friday & Saturday 6 PM - 6 AM ET)":                                           "",
		"Eligible Purchases": "",
	}
	for label, want := range cases {
		categories, reason := classifyLabel(label)
		if got := strings.Join(categories, ","); got != want || (want == "" && reason == "") {
			t.Errorf("%q => %q (%s), want %q", label, got, reason, want)
		}
	}
}

func TestReferenceTermsComeFromExactBindingsOnly(t *testing.T) {
	body, err := os.ReadFile("testdata/wallet_cards.json")
	if err != nil {
		t.Fatal(err)
	}
	s := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.Write(body) }))
	defer s.Close()
	store := &memoryStore{}
	c := New(s.Client(), store, s.URL)
	if err := c.Refresh(context.Background()); err != nil {
		t.Fatal(err)
	}
	active := c.TermsForReference("us-wells-fargo-active-cash")
	if active == nil || active.ProductID != "us-wells-fargo-active-cash" || active.RewardRates["other"] != 2 {
		t.Fatalf("bound product not scored: %+v", active)
	}
	if active.SnapshotSHA256 != store.hash || active.CapturedAt.IsZero() || !strings.HasPrefix(active.DatasetVersion(), TermsMappingVersion+":") {
		t.Fatalf("missing snapshot provenance: %+v", active)
	}
	if terms := c.TermsForReference("ihg-one-rewards-traveler"); terms == nil || terms.RewardRates["other"] != 2 {
		t.Errorf("hotel nominal earning rate missing: %+v", terms)
	}
	if c.TermsForReference("wells-fargo-one-key-plus") != nil || c.TermsForReference("") != nil {
		t.Fatal("unbound reference was scored")
	}
	// Catalog details and their exact bindings are unchanged by the extra rows.
	if c.Get("20000000-0000-4000-8000-000000000013") == nil {
		t.Fatal("catalog detail binding lost")
	}
	// Reloading the persisted snapshot restores identical terms.
	restarted := New(s.Client(), store, s.URL)
	if err := restarted.Load(context.Background()); err != nil {
		t.Fatal(err)
	}
	again := restarted.TermsForReference("wells-fargo-active-cash")
	if again == nil || !reflect.DeepEqual(again.RewardRates, active.RewardRates) || again.SnapshotSHA256 != active.SnapshotSHA256 {
		t.Fatalf("reload changed terms: %+v", again)
	}
}

func TestReferenceBindingsAreWellFormed(t *testing.T) {
	products := map[string]string{}
	for slug, product := range referenceBindings {
		if !strings.HasPrefix(product, "us-") || slug == "" || strings.HasSuffix(slug, "-index") {
			t.Fatalf("bad binding %s => %s", slug, product)
		}
		if other, dup := products[product]; dup {
			t.Fatalf("%s bound twice (%s, %s)", product, other, slug)
		}
		products[product] = slug
	}
}

// With OPENCARD_SNAPSHOT pointing at a full exports/cards-all.json, every
// binding must name a real US product. Not run by default: the full feed is
// not vendored.
func TestReferenceBindingsExistInFullSnapshot(t *testing.T) {
	path := os.Getenv("OPENCARD_SNAPSHOT")
	if path == "" {
		t.Skip("set OPENCARD_SNAPSHOT to a full OpenCard export")
	}
	records := fixtureRecords(t, path)
	scoredProducts, usProducts := 0, 0
	for _, r := range records {
		if r.Country == "us" {
			usProducts++
			if _, err := MapTerms(r); err == nil {
				scoredProducts++
			}
		}
	}
	t.Logf("US products: %d; conservative scoring: %d", usProducts, scoredProducts)
	scored := 0
	for slug, product := range referenceBindings {
		r, ok := records[product]
		if !ok || r.Country != "us" {
			t.Errorf("%s => %s not in snapshot", slug, product)
			continue
		}
		if _, err := MapTerms(r); err == nil {
			scored++
		}
	}
	t.Logf("%d bindings, %d scorable", len(referenceBindings), scored)
}

func TestTermsStatusCountsScorableBindings(t *testing.T) {
	body, err := os.ReadFile("testdata/wallet_cards.json")
	if err != nil {
		t.Fatal(err)
	}
	c := New(nil, &memoryStore{}, "")
	_, terms, err := decode(body, time.Now())
	if err != nil {
		t.Fatal(err)
	}
	c.terms = terms
	products, scorable, bindings := c.TermsStatus()
	// Fixture: Active Cash, Autograph and Discover it Cash Back are bound and
	// scorable; IHG also retains its nominal point earning rates.
	if scorable != 4 || bindings != len(referenceBindings) || products < scorable {
		t.Fatalf("status = %d products, %d/%d bindings", products, scorable, bindings)
	}
}

func TestAmbiguousBaseRatesFailClosed(t *testing.T) {
	r := fixtureRecords(t, "testdata/terms_fixture.json")["us-wells-fargo-active-cash"]
	for _, description := range []string{
		"Earn 2x miles on travel purchases and 1x mile on all other purchases.",
		"Refer to the Cardmember Agreement for the earning rate.",
		"2% cash back after the first year", "2% at participating merchants only",
	} {
		r.Rewards.BaseRate.Description = description
		if terms, err := MapTerms(r); err == nil {
			t.Fatalf("ambiguous base accepted: %s: %+v", description, terms)
		}
	}
}

func TestHotelAndHighBaseCurrenciesKeepActualEarningUnits(t *testing.T) {
	records := fixtureRecords(t, "testdata/terms_fixture.json")
	for id, base := range map[string]float64{"us-amex-hilton-honors": 3, "us-chase-ihg-traveler": 2, "us-fetch-american-express": 5} {
		terms, err := MapTerms(records[id])
		if err != nil || terms.RewardRates["other"] != base || terms.TransferablePoints || terms.RewardsType != "travel" {
			t.Fatalf("%s: %+v %v", id, terms, err)
		}
	}
}

func TestPointValueCents(t *testing.T) {
	for currency, want := range map[string]float64{
		"hilton_honors_points": .5, "ihg_points": .5, "marriott_bonvoy_points": .7,
		"bonvoy_points": .7, "ritz-carlton_points": .7, "wyndham_rewards_points": .8,
		"cash_back": 1, "membership_rewards": 1, "miles": 1, "hyatt_points": 1, "": 1,
	} {
		if got := PointValueCents(currency); got != want {
			t.Errorf("%s = %g, want %g", currency, got, want)
		}
	}
	records := fixtureRecords(t, "testdata/terms_fixture.json")
	terms, err := MapTerms(records["us-amex-hilton-honors"])
	if err != nil || terms.PointValueCents != .5 || terms.RewardRates["other"] != 3 {
		t.Fatalf("Hilton terms = %+v, %v", terms, err)
	}
}
