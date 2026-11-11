package carddata

import (
	"fmt"
	"math"
	"regexp"
	"sort"
	"strings"
	"time"
)

// TermsMappingVersion identifies the label rules below. Bump it whenever a rule
// changes so every scored wallet card records which rules produced its rates.
const TermsMappingVersion = "opencard-terms-v2"

// TermsSourceName labels community-derived scoring terms everywhere they are shown.
const TermsSourceName = "OpenCard DB community data"

// Terms are conservative scoring inputs derived from one OpenCard DB record.
// They are wallet-only: they may score a card the member already holds when the
// member did not type the terms, and they never make any card a recommendation
// candidate or change recommendation inputs.
type Terms struct {
	ProductID          string             `json:"product_id"`
	ProductName        string             `json:"product_name"`
	SourceName         string             `json:"source_name"`
	SourceURL          string             `json:"source_url"`
	LicenseURL         string             `json:"license_url"`
	IssuerURL          string             `json:"issuer_url"`
	LastVerified       string             `json:"last_verified"`
	CapturedAt         time.Time          `json:"captured_at"`
	SnapshotSHA256     string             `json:"snapshot_sha256"`
	MappingVersion     string             `json:"mapping_version"`
	AnnualFeeCents     int                `json:"annual_fee_cents"`
	RewardsType        string             `json:"rewards_type"`
	TransferablePoints bool               `json:"transferable_points"`
	CurrencyLabel      string             `json:"currency_label"`
	RewardRates        map[string]float64 `json:"reward_rates"`
	Scored             []TermsRule        `json:"scored_rules"`
	NotScored          []TermsRule        `json:"not_scored_rules"`
}

// TermsRule records how one source earning rule was treated, so the client,
// REVO and reviewers can see exactly which source rates count and which do not.
type TermsRule struct {
	Label      string   `json:"label"`
	Rate       float64  `json:"rate"`
	Categories []string `json:"categories,omitempty"`
	Reason     string   `json:"reason,omitempty"`
}

// DatasetVersion is a stable, versioned identifier for the inputs that scored a card.
func (t *Terms) DatasetVersion() string {
	sha := t.SnapshotSHA256
	if len(sha) > 12 {
		sha = sha[:12]
	}
	return fmt.Sprintf("%s:%s:%s", t.MappingVersion, t.CapturedAt.UTC().Format("2006-01-02"), sha)
}

// Rate category keys shared with the engine, wallet score and spending sliders.
const (
	catOther     = "other"
	catDining    = "dining"
	catGroceries = "groceries"
	catGas       = "gas"
	catTravel    = "travel"
	catFlights   = "flights"
	catHotels    = "hotels"
	catStreaming = "streaming"
)

// maxScoredRate matches the cardholder-entered terms limit in the API.
const maxScoredRate = 20

var (
	parenthetical = regexp.MustCompile(`\(([^()]*)\)`)
	nonWord       = regexp.MustCompile(`[^a-z0-9$]+`)
)

// Conditions that make a source rate unsafe to treat as a flat everyday rate.
// Checked in order against the lowercased label; the first match is the reason.
var conditionRules = []struct {
	pattern *regexp.Regexp
	reason  string
}{
	{regexp.MustCompile(`rotat|quarter|activat|enroll`), "rotating or activation-required category"},
	{regexp.MustCompile(`choice|choose|chosen|select(ed)? (3x |2x )?categor|self-select|\btop\b|highest|each month|each billing|monthly|adaptive|accelerator`), "cardholder-chosen or top-spend category"},
	{regexp.MustCompile(`first year|first \d+ months|new cardmember|intro|\bthrough \d|\bthrough (jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)|until|\d{1,2}/\d{1,2}/\d{2,4}|\b20\d\d\b`), "temporary or introductory rate"},
	{regexp.MustCompile(`booked (through|on|in)|purchased through|through [a-z ]*travel|travel center|rewards center|portal|\bvia\b|\.com|\bapp\b|online|website|in-store`), "travel portal, app or online-only rate"},
	{regexp.MustCompile(`first \$|up to|\$\d|\d+k\b|then \d|thereafter|\bcaps?\b|maximum|per (calendar )?year|annually|combined|\blimit`), "spend-capped rate"},
	{regexp.MustCompile(`status|tier|member|prime|linked|bundle|when you|after \$|with [a-z]+\+|autopay|nights|friday|saturday`), "status, membership or timing condition"},
	{regexp.MustCompile(`\btotal\b|incl\. \d|card earn|base points|bonus`), "combines loyalty-program earnings with card earnings"},
}

// Words that name a scoring category. A label maps to every category it names.
var categoryWords = map[string]string{
	"dining": catDining, "restaurant": catDining, "restaurants": catDining, "takeout": catDining,
	"grocery": catGroceries, "groceries": catGroceries, "supermarket": catGroceries, "supermarkets": catGroceries,
	"gas": catGas, "fuel": catGas,
	"travel": catTravel,
	"air":    catFlights, "flights": catFlights, "flight": catFlights, "airfare": catFlights, "airline": catFlights, "airlines": catFlights,
	"hotel": catHotels, "hotels": catHotels,
	"streaming": catStreaming,
}

// Generic words that may appear beside category words without changing the
// meaning. Any other word (a merchant, brand, program or unknown term) makes the
// whole label merchant-specific, so it is not scored.
var fillerWords = toSet(`a all and any at bakeries bars booked by cafes cable car charging clubs
commuting delivery department direct directly drug drugstore drugstores dine eligible ev
entertainment fast food for from home improvement in including internet local mobile most
of office or other phone pharmacies pharmacy popular public purchase purchases purchased rail rental
rentals rideshare satellite select service services stations stays store stores streaming
subscriptions supply taxis telecommunications telephone the tickets to transit tv us utilities
vacation wholesale wireless with worldwide accommodations`)

func toSet(words string) map[string]bool {
	set := map[string]bool{}
	for _, w := range strings.Fields(words) {
		set[w] = true
	}
	return set
}

// A base description with these markers is not a flat unconditional rate.
var conditionalBase = regexp.MustCompile(`autopay|redeemed into|deposit account|\bif\b|linked|\btier|membership|with prime|relationship|after the first \$|refer to|on travel purchases and|spend above|after the first year|with autopay|only at|at participating|pro xtra|at amazon|at walgreens|family of stores|after first \$`)

// Only explicit whole-card earning gates in source notes trigger this check;
// ordinary redemption or benefit conditions do not become earning restrictions.
var earningGate = regexp.MustCompile(`(?i)(subscription|membership).{0,100}required.{0,100}(earn|points)|must make.{0,60}purchases.{0,60}earn`)

// Transferable only for issuer-flexible currencies, and only when the source
// states transfers to partners. Co-brand airline/hotel currencies never count.
var transferableCurrencies = map[string]bool{"membership_rewards": true, "ultimate_rewards": true, "thankyou_points": true, "wells_fargo_rewards": true, "bilt_points": true}

func transferable(r Card) bool {
	flexible := transferableCurrencies[r.Rewards.Currency] || (r.Rewards.Currency == "miles" && strings.HasPrefix(r.ID, "us-capital-one-"))
	return flexible && transferPartners.MatchString(strings.ToLower(r.Rewards.RedemptionNotes))
}

var transferPartners = regexp.MustCompile(`transfer(s|red)?( [a-z/]+){0,3} (to )?(\d+\+? )?(airline|hotel|travel|loyalty|participating|partner)|transfer partners`)

// MapTerms converts one OpenCard record into conservative scoring terms.
// An error explains why the card cannot be scored; callers keep it unscored.
func MapTerms(r Card) (*Terms, error) {
	if r.Country != "us" {
		return nil, fmt.Errorf("not a US product")
	}
	if r.Status != "active" && r.Status != "invite_only" {
		return nil, fmt.Errorf("product status %q is not active", r.Status)
	}
	if r.Network == "other" {
		// Closed-loop store cards earn only at the merchant.
		return nil, fmt.Errorf("store card: rewards earn only at the merchant")
	}
	if r.AnnualFee.Currency != "USD" || r.AnnualFee.Amount == nil || *r.AnnualFee.Amount < 0 || *r.AnnualFee.Amount > 10000 {
		return nil, fmt.Errorf("annual fee missing or invalid")
	}
	if _, err := time.Parse("2006-01-02", r.LastVerified); err != nil {
		return nil, fmt.Errorf("invalid verification date")
	}
	rewardsType := ""
	switch r.Rewards.RateType {
	case "cashback_percent":
		rewardsType = "cash_back"
	case "points_multiplier", "miles_multiplier":
		// The catalog vocabulary calls point and mile currencies "travel".
		rewardsType = "travel"
	default:
		return nil, fmt.Errorf("unsupported reward units")
	}
	if r.Rewards.Currency == "" || r.Rewards.Currency == "none" {
		return nil, fmt.Errorf("no rewards currency")
	}
	base := r.Rewards.BaseRate.PointsPerDollar
	if base == nil || (math.IsNaN(*base) || math.IsInf(*base, 0)) || *base < 0 {
		return nil, fmt.Errorf("no base earning rate")
	}
	if *base > maxScoredRate {
		return nil, fmt.Errorf("base rate %g is above supported maximum %d", *base, maxScoredRate)
	}
	if conditionalBase.MatchString(strings.ToLower(r.Rewards.BaseRate.Description)) || earningGate.MatchString(r.Notes) {
		return nil, fmt.Errorf("base rate is conditional")
	}
	t := &Terms{
		ProductID: r.ID, ProductName: r.Name, SourceName: TermsSourceName,
		SourceURL: ProjectURL, LicenseURL: LicenseURL, IssuerURL: r.OfficialURL,
		LastVerified: r.LastVerified, MappingVersion: TermsMappingVersion,
		AnnualFeeCents: int(math.Round(*r.AnnualFee.Amount * 100)),
		RewardsType:    rewardsType, CurrencyLabel: r.Rewards.CurrencyLabel,
		TransferablePoints: rewardsType == "travel" && transferable(r),
		RewardRates:        map[string]float64{catOther: *base},
		Scored:             []TermsRule{{Label: "Base rate", Rate: *base, Categories: []string{catOther}}},
		NotScored:          []TermsRule{},
	}
	for _, rule := range r.Rewards.Categories {
		if rule.PointsPerDollar == nil {
			t.NotScored = append(t.NotScored, TermsRule{Label: rule.Label, Reason: "no rate in source"})
			continue
		}
		rate := *rule.PointsPerDollar
		categories, reason := classifyLabel(rule.Label)
		switch {
		case reason != "":
		case math.IsNaN(rate) || math.IsInf(rate, 0) || rate < 0 || rate > maxScoredRate:
			reason = "rate outside the supported range"
		case len(rule.Cap) > 0 && string(rule.Cap) != "null":
			reason = "spend-capped rate"
		case rate <= *base:
			reason = "not above the base rate"
		}
		if reason != "" {
			t.NotScored = append(t.NotScored, TermsRule{Label: rule.Label, Rate: rate, Reason: reason})
			continue
		}
		t.Scored = append(t.Scored, TermsRule{Label: rule.Label, Rate: rate, Categories: categories})
		for _, category := range categories {
			t.RewardRates[category] = max(t.RewardRates[category], rate)
		}
	}
	return t, nil
}

// classifyLabel returns the scoring categories a source label names, or the
// reason it cannot be scored as a flat everyday category rate.
func classifyLabel(label string) ([]string, string) {
	text := strings.ToLower(label)
	text = strings.NewReplacer("®", "", "™", "", "℠", "", "&", " and ", "u.s.", "us", "e.g.", "eg", "air travel", "airfare").Replace(text)
	for _, rule := range conditionRules {
		if rule.pattern.MatchString(text) {
			return nil, rule.reason
		}
	}
	// Exclusion and example clauses narrow or illustrate a generic category;
	// they do not make it merchant-specific. Other parentheticals stay in.
	text = parenthetical.ReplaceAllStringFunc(text, func(group string) string {
		inner := strings.TrimSpace(strings.Trim(group, "()"))
		for _, prefix := range []string{"exclud", "eg ", "such as", "like "} {
			if strings.HasPrefix(inner, prefix) {
				return " "
			}
		}
		return " " + inner + " "
	})
	seen := map[string]bool{}
	categories := []string{}
	for _, word := range strings.Fields(nonWord.ReplaceAllString(text, " ")) {
		if category, ok := categoryWords[word]; ok {
			if !seen[category] {
				seen[category] = true
				categories = append(categories, category)
			}
			continue
		}
		if !fillerWords[word] {
			return nil, "merchant-specific or unrecognized category"
		}
	}
	if len(categories) == 0 {
		return nil, "no supported spending category"
	}
	sort.Strings(categories)
	return categories, ""
}
