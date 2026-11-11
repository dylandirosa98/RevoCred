package store

import (
	"fmt"
	"sort"
	"strings"

	"github.com/revocred/revocred-api/internal/carddata"
	"github.com/revocred/revocred-api/internal/domain"
)

// communityTermsFor returns wallet-only scoring terms for a search-index row,
// or nil when there is no cache, no exact binding or no conservative mapping.
func (p *Postgres) communityTermsFor(referenceSlug string) *carddata.Terms {
	if p.cardData == nil || referenceSlug == "" {
		return nil
	}
	return p.cardData.TermsForReference(referenceSlug)
}

// applyCommunityTerms scores an owned card the cardholder added from search
// without typing terms. It only ever fills a card whose terms are unknown:
// catalog issuer terms and the cardholder's own terms always win. The card
// stays wallet-only (see domain.CatalogCard.ShapesRecommendations).
func applyCommunityTerms(card *domain.CatalogCard, terms *carddata.Terms) {
	if card == nil || terms == nil || !card.TermsUnknown {
		return
	}
	rates := make(map[string]float64, len(terms.RewardRates))
	for category, rate := range terms.RewardRates {
		rates[category] = rate
	}
	card.TermsUnknown = false
	card.TermsSource = domain.TermsSourceCommunity
	card.CommunityTerms = terms
	card.RewardRates = rates
	card.PointValueCents = terms.PointValueCents
	card.AnnualFeeCents = terms.AnnualFeeCents
	card.RewardsType = terms.RewardsType
	card.TransferablePoints = terms.TransferablePoints
	card.DatasetVersion = terms.DatasetVersion()
	card.SourceName = terms.SourceName
	card.SourceURL = terms.SourceURL
	card.SourceDisclaimer = communityDisclaimer(terms)
	card.Summary = "Added from search. Scored with community earning rates because no terms were entered."
	card.BestUse = communityBestUse(terms)
	card.Benefits = []string{"Earning rates and annual fee from " + terms.SourceName + "; not issuer-verified"}
}

func communityDisclaimer(terms *carddata.Terms) string {
	return fmt.Sprintf("Earning rates and annual fee from %s (CC BY 4.0), last verified by the source on %s and captured %s. "+
		"Community-maintained, not issuer-verified. Rotating, capped, portal-only, merchant-specific and other conditional rates are not counted. "+
		"Rewards use an estimated %g cents per point/mile (Hilton/IHG 0.5, Marriott/Bonvoy/Ritz-Carlton 0.7, Wyndham 0.8; otherwise 1), not guaranteed redemption value. Displayed earning rates stay nominal. Enter your own terms to replace these. Verify current terms with the issuer.",
		terms.SourceName, terms.LastVerified, terms.CapturedAt.UTC().Format("2006-01-02"), domain.CatalogCard{PointValueCents: terms.PointValueCents}.CashEquivalentRate(1))
}

// communityBestUse summarizes the strongest scored categories, e.g.
// "3% dining, 3% groceries" or "2% on everything".
func communityBestUse(terms *carddata.Terms) string {
	unit := "x"
	if terms.RewardsType == "cash_back" {
		unit = "%"
	}
	base := terms.RewardRates["other"]
	type entry struct {
		category string
		rate     float64
	}
	bonus := []entry{}
	for category, rate := range terms.RewardRates {
		if category != "other" && rate > base {
			bonus = append(bonus, entry{category, rate})
		}
	}
	sort.Slice(bonus, func(i, j int) bool {
		if bonus[i].rate == bonus[j].rate {
			return bonus[i].category < bonus[j].category
		}
		return bonus[i].rate > bonus[j].rate
	})
	if len(bonus) == 0 {
		return fmt.Sprintf("%g%s on everything", base, unit)
	}
	if len(bonus) > 3 {
		bonus = bonus[:3]
	}
	parts := make([]string, len(bonus))
	for i, b := range bonus {
		parts[i] = fmt.Sprintf("%g%s %s", b.rate, unit, b.category)
	}
	return strings.Join(parts, ", ")
}
