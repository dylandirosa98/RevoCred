package chat

import (
	"fmt"
	"sort"
	"strings"

	"github.com/revocred/revocred-api/internal/domain"
	"github.com/revocred/revocred-api/internal/valuation"
)

// snapshot is everything REVO may know about one member. Exported JSON fields
// are what the model reads, in plain dollars so it never has to convert cents.
// Fields tagged "-" are server-only inputs for charts and guards.
type issuerSource struct {
	Name      string `json:"name"`
	SourceURL string `json:"source_url"`
}

type snapshot struct {
	OngoingWalletBreakdown domain.OngoingValue `json:"ongoing_wallet_breakdown_cents"`
	Member                 memberFacts         `json:"member"`
	Wallet                 []map[string]any    `json:"cards_owned"`
	PurchaseGuide          []categoryRanking   `json:"best_cards_by_purchase_category,omitempty"`
	Strategy               *strategyFacts      `json:"strategy,omitempty"`
	NextCard               string              `json:"next_card"`
	Reasons                []string            `json:"next_card_reasons,omitempty"`
	Ranking                []rankedFacts       `json:"ranked_options,omitempty"`
	RuledOut               []ruledOutFacts     `json:"ruled_out,omitempty"`
	WalletScore            int                 `json:"wallet_score"`
	WalletRating           string              `json:"wallet_rating"`
	YearlyValueUSD         int                 `json:"current_wallet_value_usd_per_year"`
	MonthlySpendUSD        map[string]float64  `json:"monthly_spend_usd,omitempty"`
	CreditTier             string              `json:"credit_tier,omitempty"`
	RewardsGoal            string              `json:"rewards_goal,omitempty"`
	TravelScope            string              `json:"travel_scope,omitempty"`
	FeeToleranceUSD        float64             `json:"annual_fee_comfort_usd,omitempty"`
	Catalog                []map[string]any    `json:"catalog_for_reference,omitempty"`
	IssuerSources          []issuerSource      `json:"-"`
	IssuerLookup           *IssuerLookup       `json:"current_official_page,omitempty"`
	WebLookup              *WebLookup          `json:"web_sources,omitempty"`
	Disclaimer             string              `json:"model_assumptions"`

	AllowedCards       []string         `json:"-"`
	MonthlySpend       map[string]int64 `json:"-"`
	WalletValueCents   int              `json:"-"`
	NextCardValueCents int              `json:"-"`
	AvailableCharts    []string         `json:"-"`
	StrategyCode       string           `json:"-"`
}

type memberFacts struct {
	FirstName string `json:"first_name,omitempty"`
	LifeStage string `json:"life_stage,omitempty"`
}

type strategyFacts struct {
	Code        string         `json:"code"`
	Title       string         `json:"title,omitempty"`
	Goal        string         `json:"goal,omitempty"`
	FeeLevel    string         `json:"fee_level,omitempty"`
	TravelScope string         `json:"travel_scope,omitempty"`
	Ecosystem   string         `json:"ecosystem,omitempty"`
	BankAccount string         `json:"suggested_bank_account,omitempty"`
	Roadmap     []roadmapFacts `json:"roadmap,omitempty"`
	Unused      []unusedFacts  `json:"cards_to_review,omitempty"`
}

type roadmapFacts struct {
	Card   string `json:"card"`
	Use    string `json:"use,omitempty"`
	Status string `json:"status"`
	Note   string `json:"note,omitempty"`
}

type unusedFacts struct {
	Card   string `json:"card"`
	Action string `json:"action"`
	Note   string `json:"note,omitempty"`
}

type rankedFacts struct {
	Rank         int      `json:"rank"`
	Card         string   `json:"card"`
	FirstYearUSD float64  `json:"first_year_value_usd"`
	OngoingUSD   float64  `json:"ongoing_value_usd_per_year"`
	Reasons      []string `json:"reasons,omitempty"`
}

type ruledOutFacts struct {
	Card   string `json:"card"`
	Reason string `json:"reason"`
}

type categoryRanking struct {
	Category string             `json:"category"`
	Options  []purchaseCardFact `json:"options"`
}

type purchaseCardFact struct {
	Rank                  int     `json:"rank"`
	Card                  string  `json:"card"`
	ModeledRate           float64 `json:"modeled_rate"`
	EarnLabel             string  `json:"earn_label"`
	ModeledValuePer100USD float64 `json:"modeled_value_per_100_usd"`
	AnnualFeeUSD          float64 `json:"annual_fee_usd"`
}

func dollars(cents int64) float64 { return float64(cents) / 100 }

func communityFacts(card *domain.CatalogCard) map[string]any {
	if card.CommunityData == nil {
		return nil
	}
	d := card.CommunityData
	return map[string]any{
		"source":     "OpenCard DB (community-maintained, not independently verified)",
		"source_url": d.SourceURL, "issuer_url": d.IssuerURL, "last_verified_by_source": d.LastVerified,
		"currency": d.CurrencyLabel, "earning_rules": d.RewardRates, "benefits": d.Benefits,
		"warning": d.Warning, "usage": "Explain conditionally and cite source; never replace modeled rankings or assume credits are guaranteed value.",
	}
}

func Snapshot(input Context) snapshot {
	facts := snapshot{
		AllowedCards:           []string{},
		Wallet:                 []map[string]any{},
		WalletScore:            input.Metrics.Score,
		WalletRating:           input.Metrics.Rating,
		YearlyValueUSD:         input.Metrics.YearlyValue,
		OngoingWalletBreakdown: input.Metrics.OngoingValue,
		Disclaimer:             "Wallet ongoing value = spending rewards + conditional usable credits (70% assumption for relevant reviewed credits, budget capped) + recurring anniversary rewards - fees. Use the supplied breakdown in cents, divide by 100 for dollars; explain each condition/source and that budget does not prove merchant use. Renewal/anniversary eligibility assumed; welcome bonuses are excluded, automatic bonus eligibility is not implemented. Missing/changed benefit evidence is zero, not no benefit. Application rankings still use the separate conservative rewards-minus-fees model and exclude credits and bonuses. Never convert AI web/marketing prose into modeled value or alter rankings.",
	}
	seen := map[string]bool{}
	add := func(name string) {
		name = strings.TrimSpace(name)
		if name == "" || seen[strings.ToLower(name)] {
			return
		}
		seen[strings.ToLower(name)] = true
		facts.AllowedCards = append(facts.AllowedCards, name)
	}

	owned := map[string]bool{}
	for _, item := range input.Wallet {
		if item.Status != "active" || item.Card == nil {
			continue
		}
		card := item.Card
		owned[card.ID] = true
		add(card.Name)
		if safeIssuerURL(card.SourceURL) {
			facts.IssuerSources = append(facts.IssuerSources, issuerSource{Name: card.Name, SourceURL: card.SourceURL})
		}
		entry := map[string]any{
			"name":                card.Name,
			"issuer":              card.Issuer,
			"rewards_type":        card.RewardsType,
			"annual_fee_usd":      dollars(int64(card.AnnualFeeCents)),
			"best_use":            card.BestUse,
			"summary":             card.Summary,
			"benefits":            card.Benefits,
			"transferable_points": card.TransferablePoints,
		}
		if card.CommunityData != nil {
			entry["community_product_data"] = communityFacts(card)
		}
		if card.TermsUnknown {
			entry["terms_known"] = false
			entry["note"] = "The member skipped entering terms, so this card is left out of the score and value."
		} else {
			entry["reward_rates"] = card.RewardRates
			entry["base_rate"] = valuation.Rate(card.RewardRates, "other")
		}
		facts.Wallet = append(facts.Wallet, compact(entry))
	}
	facts.PurchaseGuide = purchaseRankings(input.Wallet)
	facts.WalletValueCents = input.Metrics.YearlyValue * 100

	names := map[string]string{}
	for _, card := range input.Catalog {
		names[card.Slug] = card.Name
		names[card.ID] = card.Name
	}
	if input.Recommendations != nil {
		for _, card := range input.Recommendations.CatalogSnapshot {
			names[card.Slug] = card.Name
			names[card.ID] = card.Name
		}
		facts.StrategyCode = input.Recommendations.StrategyCode
		for i, item := range input.Recommendations.Items {
			if i == 0 {
				facts.NextCard = item.CardName
				facts.Reasons = item.Reasons
				facts.NextCardValueCents = int(item.OngoingEstimate)
			}
			add(item.CardName)
			facts.Ranking = append(facts.Ranking, rankedFacts{
				Rank: i + 1, Card: item.CardName, Reasons: item.Reasons,
				FirstYearUSD: dollars(item.FirstYearEstimate),
				OngoingUSD:   dollars(item.OngoingEstimate),
			})
		}
		for _, excluded := range input.Recommendations.Exclusions {
			name := firstNonEmpty(names[excluded.CardID], names[excluded.CardSlug])
			if name == "" {
				continue
			}
			add(name)
			facts.RuledOut = append(facts.RuledOut, ruledOutFacts{Card: name, Reason: excluded.Reason})
		}
	}

	if input.Playbook != nil {
		pb := input.Playbook
		if facts.StrategyCode == "" {
			facts.StrategyCode = string(pb.Code)
		}
		if facts.NextCard == "" {
			facts.NextCard = pb.NextCard
		}
		add(pb.NextCard)
		plan := &strategyFacts{
			Code: string(pb.Code), Title: pb.Title, Goal: pb.Goal, FeeLevel: pb.FeeLevel,
			TravelScope: pb.TravelScope, Ecosystem: pb.Ecosystem, BankAccount: pb.DebitCard,
		}
		for _, step := range pb.Steps {
			add(step.Name)
			plan.Roadmap = append(plan.Roadmap, roadmapFacts{
				Card: step.Name, Use: step.Use, Status: roadmapStatus(step.Status), Note: step.Note,
			})
		}
		for _, card := range pb.Unused {
			add(card.Name)
			plan.Unused = append(plan.Unused, unusedFacts{Card: card.Name, Action: card.Action, Note: card.Note})
		}
		facts.Strategy = plan
	}
	if input.Profile != nil {
		if facts.StrategyCode == "" {
			facts.StrategyCode = input.Profile.CreditCardStrategy
		}
		if facts.NextCard == "" {
			facts.NextCard = input.Profile.NextApplicationTarget
			add(input.Profile.NextApplicationTarget)
		}
		facts.Member.FirstName = firstWord(input.Profile.DisplayName)
	}
	if facts.Strategy == nil && facts.StrategyCode != "" {
		facts.Strategy = &strategyFacts{Code: facts.StrategyCode}
	}
	if input.Questionnaire != nil {
		q := input.Questionnaire
		facts.MonthlySpend = q.MonthlyCategorySpend
		if len(q.MonthlyCategorySpend) > 0 {
			facts.MonthlySpendUSD = map[string]float64{}
			for category, cents := range q.MonthlyCategorySpend {
				facts.MonthlySpendUSD[category] = dollars(cents)
			}
		}
		facts.CreditTier = q.CreditTier
		facts.RewardsGoal = q.RewardsGoal
		facts.TravelScope = q.TravelScope
		facts.FeeToleranceUSD = dollars(int64(q.FeeToleranceCents))
		facts.Member.LifeStage = q.LifeStage
		if facts.Member.FirstName == "" {
			facts.Member.FirstName = firstWord(q.DisplayName)
		}
	}

	// The catalog is reference material: REVO may explain any card in it when
	// asked, but only the ranking above says what the member should get.
	for _, card := range input.Catalog {
		if owned[card.ID] || card.TermsUnknown {
			continue
		}
		add(card.Name)
		if safeIssuerURL(card.SourceURL) {
			facts.IssuerSources = append(facts.IssuerSources, issuerSource{Name: card.Name, SourceURL: card.SourceURL})
		}
		facts.Catalog = append(facts.Catalog, compact(map[string]any{
			"name":                   card.Name,
			"issuer":                 card.Issuer,
			"annual_fee_usd":         dollars(int64(card.AnnualFeeCents)),
			"reward_rates":           card.RewardRates,
			"best_use":               card.BestUse,
			"summary":                card.Summary,
			"benefits":               card.Benefits,
			"transferable_points":    card.TransferablePoints,
			"community_product_data": communityFacts(&card),
		}))
	}

	for name := range chartNames {
		facts.AvailableCharts = append(facts.AvailableCharts, name)
	}
	sort.Strings(facts.AvailableCharts)
	return facts
}

// purchaseRankings gives REVO a deterministic winner and runner-up for common
// checkout categories. The model explains this order; it never has to infer or
// select the cards itself.
func purchaseRankings(wallet []domain.WalletCard) []categoryRanking {
	categories := []string{"dining", "groceries", "gas", "travel", "flights", "hotels", "other"}
	seen := map[string]bool{}
	for _, category := range categories {
		seen[category] = true
	}
	extra := []string{}
	for _, item := range wallet {
		if item.Status != "active" || item.Card == nil || item.Card.TermsUnknown {
			continue
		}
		for category := range item.Card.RewardRates {
			category = strings.TrimSpace(strings.ToLower(category))
			if category == "" || category == "housing" || category == "rent" || seen[category] {
				continue
			}
			seen[category] = true
			extra = append(extra, category)
		}
	}
	sort.Strings(extra)
	categories = append(categories, extra...)

	guide := make([]categoryRanking, 0, len(categories))
	for _, category := range categories {
		options := []purchaseCardFact{}
		for _, item := range wallet {
			if item.Status != "active" || item.Card == nil || item.Card.TermsUnknown {
				continue
			}
			card := item.Card
			rate := valuation.Rate(card.RewardRates, category)
			if rate <= 0 {
				continue
			}
			unit := "% cash back"
			if card.TransferablePoints {
				unit = "points per dollar"
			}
			options = append(options, purchaseCardFact{
				Card: card.Name, ModeledRate: rate,
				EarnLabel:             formatRate(rate, unit),
				ModeledValuePer100USD: rate,
				AnnualFeeUSD:          dollars(int64(card.AnnualFeeCents)),
			})
		}
		sort.SliceStable(options, func(i, j int) bool {
			if options[i].ModeledRate == options[j].ModeledRate {
				return options[i].Card < options[j].Card
			}
			return options[i].ModeledRate > options[j].ModeledRate
		})
		if len(options) > 3 {
			options = options[:3]
		}
		for i := range options {
			options[i].Rank = i + 1
		}
		if len(options) > 0 {
			guide = append(guide, categoryRanking{Category: category, Options: options})
		}
	}
	return guide
}

func formatRate(rate float64, unit string) string {
	value := strings.TrimRight(strings.TrimRight(fmt.Sprintf("%.2f", rate), "0"), ".")
	if strings.HasPrefix(unit, "%") {
		return value + unit
	}
	return value + " " + unit
}

// compact drops empty values so the model is not shown blank fields it might
// feel it has to comment on.
func compact(entry map[string]any) map[string]any {
	for key, value := range entry {
		switch v := value.(type) {
		case string:
			if strings.TrimSpace(v) == "" {
				delete(entry, key)
			}
		case []string:
			if len(v) == 0 {
				delete(entry, key)
			}
		case nil:
			delete(entry, key)
		}
	}
	return entry
}

func roadmapStatus(status string) string {
	switch status {
	case "have":
		return "already owned"
	case "next":
		return "recommended next"
	case "unavailable":
		return "not currently recommended"
	case "later":
		return "later option"
	}
	return status
}

func firstWord(name string) string {
	if fields := strings.Fields(name); len(fields) > 0 {
		return fields[0]
	}
	return ""
}
