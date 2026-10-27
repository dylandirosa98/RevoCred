// Package purchaseguide compares purchase-specific earning rules, never card
// marketing keywords, annual fees, benefits, welcome bonuses, or AI choices.
package purchaseguide

import (
	"fmt"
	"math"
	"sort"

	"github.com/revocred/revocred-api/internal/domain"
)

type Settings struct {
	TravelMode    string `json:"travel_mode"`
	CapsAvailable bool   `json:"caps_available"`
}

func DefaultOptions() Settings { return Settings{TravelMode: "general", CapsAvailable: true} }

type Option struct {
	CardID       string   `json:"card_id"`
	CardName     string   `json:"card_name"`
	Rate         float64  `json:"rate"`
	EarnLabel    string   `json:"earn_label"`
	Reason       string   `json:"reason"`
	Conditions   []string `json:"conditions"`
	Source       string   `json:"source"`
	SourceURL    string   `json:"source_url,omitempty"`
	LastVerified string   `json:"last_verified,omitempty"`
}
type Category struct {
	ID             string   `json:"id"`
	Label          string   `json:"label"`
	Options        []Option `json:"options"`
	Conditional    []Option `json:"conditional"`
	Unknown        []string `json:"unknown"`
	UnknownCardIDs []string `json:"unknown_card_ids"`
	Assumptions    string   `json:"assumptions"`
	Tied           bool     `json:"tied"`
}

func (g *Category) addUnknown(card domain.CatalogCard, reason string) {
	g.Unknown = append(g.Unknown, card.Name+": "+reason)
	g.UnknownCardIDs = append(g.UnknownCardIDs, card.ID)
}

func validRate(v float64) bool { return !math.IsNaN(v) && !math.IsInf(v, 0) && v >= 0 && v <= 100 }
func Build(wallet []domain.WalletCard, settings Settings) []Category {
	categories := homeCategories
	result := make([]Category, 0, len(categories))
	for _, cat := range categories {
		g := Category{ID: cat[0], Label: cat[1], Options: []Option{}, Conditional: []Option{}, Unknown: []string{}, Assumptions: "Owned active cards only. Points and miles are compared at 1 cent each; cash-back rates use their face value. Eligible purchases assumed; issuer terms and merchant coding apply. No welcome bonuses, statement credits, annual fees or transfer-partner uplift included."}
		seen := map[string]bool{}
		for _, item := range wallet {
			card := item.Card
			if item.Status != "active" || card == nil || seen[card.ID] {
				continue
			}
			seen[card.ID] = true
			if card.TermsUnknown {
				g.addUnknown(*card, "terms not supplied")
				continue
			}
			rate, ok := card.RewardRates["other"]
			explicitOnly := false
			unit := "x"
			currency := "points per dollar"
			source := "Stored card terms"
			url := card.SourceURL
			date := ""
			if card.RewardsType == "cash_back" {
				unit = "%"
				currency = "cash back"
			}
			if card.CommunityData != nil {
				d := card.CommunityData
				for _, r := range d.Rewards.Categories {
					if _, reviewed := scopeFor(d.ID, r.Label); !reviewed {
						g.addUnknown(*card, "source contains unreviewed earning rules; comparison may be incomplete")
						break
					}
				}
				if base := d.Rewards.BaseRate.PointsPerDollar; base != nil && validRate(*base) {
					rate = *base
					ok = true
					source = "OpenCard DB (community snapshot)"
					url = d.IssuerURL
					date = d.LastVerified
					if d.Rewards.RateType == "cashback_percent" {
						unit = "%"
						currency = "cash back"
					} else {
						unit = "x"
						currency = d.Rewards.CurrencyLabel
					}
				}
			}
			if !ok || !validRate(rate) {
				if key := storedKey(cat[0], settings); key != "" {
					rate, ok = card.RewardRates[key]
					explicitOnly = ok
				}
			}
			if !ok || !validRate(rate) {
				g.addUnknown(*card, "base earning rate unknown")
				continue
			}
			option := Option{CardID: card.ID, CardName: card.Name, Rate: rate, EarnLabel: fmt.Sprintf("%g%s %s", rate, unit, currency), Reason: "Base earning rate for a purchase without a matching category bonus.", Conditions: []string{}, Source: source, SourceURL: url, LastVerified: date}
			option, conditional, applicable := applyRules(*card, cat[0], settings, option)
			if explicitOnly && applicable && cat[0] != "rent" {
				option.Reason = "Supplied earning rule for this category; no missing catch-all rate was assumed."
			}
			g.Conditional = append(g.Conditional, conditional...)
			if !applicable {
				g.addUnknown(*card, "no supported earning rule for this purchase")
				continue
			}
			g.Options = append(g.Options, option)
		}
		sort.Slice(g.Options, func(i, j int) bool {
			a, b := g.Options[i], g.Options[j]
			if a.Rate != b.Rate {
				return a.Rate > b.Rate
			}
			if a.CardName != b.CardName {
				return a.CardName < b.CardName
			}
			return a.CardID < b.CardID
		})
		g.Tied = len(g.Options) > 1 && g.Options[0].Rate == g.Options[1].Rate
		if settings.CapsAvailable {
			g.Assumptions += " Known capped rates assume unused allowance."
		} else {
			g.Assumptions += " Known capped bonuses are excluded because caps are unavailable."
		}
		if cat[0] == "travel" {
			g.Assumptions += " Booking context: " + TravelModes[settings.TravelMode] + "."
		}
		g.Assumptions += " Community snapshots may be outdated or incomplete; verify current issuer terms."
		result = append(result, g)
	}
	return result
}
