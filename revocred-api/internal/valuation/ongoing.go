package valuation

import (
	_ "embed"
	"encoding/json"
	"sort"

	"github.com/revocred/revocred-api/internal/domain"
)

// reviewedEvidence is a bounded human-reviewed adapter, not a prose parser.
// Every valued rule requires an exact catalog/product binding AND source text.
//
//go:embed benefits.json
var reviewedEvidence []byte

type benefitRule struct {
	domain.BenefitValue
	ProductID string `json:"product_id"`
	Evidence  string `json:"evidence"`
	Category  string `json:"category"`
}

// Ongoing is wallet-only. Net remains rewards less fees for application rankings.
func Ongoing(spend map[string]int64, cards []domain.CatalogCard, travelScope string) domain.OngoingValue {
	out := domain.OngoingValue{ModelVersion: "ongoing-v1", Benefits: []domain.BenefitValue{}, Assumptions: []string{
		"Spending rewards use best known base rates, 1 cent per point, no housing rewards or conditional uplift. Annual fees are subtracted.",
		"Relevant credits use a conditional 70% usage assumption, not observed merchant use or guaranteed savings. Budget/travel scope is only a relevance screen: you must actually use each eligible merchant, portal or service. Enrollment, monthly/half-year caps and expiry still apply.",
		"Credits sharing a spending category share a conservative budget cap of 70% of annual category spending, in stable product/benefit order. This is not a forecast of merchant use. Rewards are modeled separately on entered spending; credited purchases may not earn rewards, so actual rewards can be lower.",
		"Anniversary rewards assume renewal and continued eligibility, starting at the first eligible anniversary. This is not a first-year estimate. Welcome bonuses are excluded; automatic bonus eligibility is not implemented.",
		"Lounges, insurance, per-stay perks, temporary offers, multi-year application-fee credits and unknown relationship eligibility have no assigned annual cash value. Missing or changed evidence contributes zero, not proof of no benefit.",
	}}
	rules := []benefitRule{}
	if err := json.Unmarshal(reviewedEvidence, &rules); err != nil {
		panic("invalid embedded reviewed benefit evidence")
	}
	unique := []domain.CatalogCard{}
	seen := map[string]bool{}
	for _, c := range cards {
		if c.TermsUnknown {
			continue
		}
		if c.ID != "" && seen[c.ID] {
			continue
		}
		seen[c.ID] = true
		unique = append(unique, c)
	}
	sort.SliceStable(unique, func(i, j int) bool { return unique[i].ID < unique[j].ID })
	out.RewardsCents = Gross(spend, unique)
	budgets := map[string]int64{}
	budgets["travel"] = max(0, spend["travel"]+spend["flights"]+spend["hotels"]) * 12 * 70 / 100
	budgets["food"] = max(0, spend["food"]+spend["dining"]+spend["groceries"]) * 12 * 70 / 100
	budgets["everyday"] = max(0, spend["everyday"]+spend["other"]) * 12 * 70 / 100
	for _, card := range unique {
		out.FeesCents += int64(card.AnnualFeeCents)
		matched := false
		for _, r := range rules {
			if r.CardID != card.ID {
				continue
			}
			matched = true
			b := r.BenefitValue
			b.CatalogVersion = card.DatasetVersion
			if card.CommunityData != nil {
				b.SnapshotSHA256 = card.CommunityData.SnapshotSHA256
			}
			b.CardName = card.Name
			b.Status = "excluded"
			b.EstimatedCents = 0
			sourceOK := card.CommunityData != nil && card.CommunityData.ID == r.ProductID
			found := r.Evidence == ""
			if sourceOK {
				for _, text := range card.CommunityData.Benefits {
					if text == r.Evidence {
						found = true
						break
					}
				}
			}
			if !sourceOK || !found {
				b.Status = "source_missing_or_changed"
				b.Conditions += " Reviewed OpenCard evidence is missing or changed; estimate disabled."
			} else if r.Kind == "anniversary" {
				b.EstimatedCents = r.FaceCents
				b.Status = "conditional_on_renewal"
				out.AnniversaryCents += b.EstimatedCents
			} else if r.Kind == "credit" {
				b.Status = "conditional_70_percent"
				if r.Category == "travel" && (travelScope == "none" || travelScope == "no_travel") {
					b.Status = "incompatible_profile"
				} else {
					b.EstimatedCents = min(r.FaceCents*70/100, budgets[r.Category])
					budgets[r.Category] -= b.EstimatedCents
					if b.EstimatedCents == 0 {
						b.Status = "no_relevant_budget"
					}
				}
				out.CreditsCents += b.EstimatedCents
			}
			out.Benefits = append(out.Benefits, b)
		}
		if !matched {
			out.Benefits = append(out.Benefits, domain.BenefitValue{CardID: card.ID, CardName: card.Name, Title: "No reviewed recurring benefit adapter", Kind: "excluded", Status: "missing_data", Conditions: "Custom, demo or unmatched product: no cash value inferred from display benefits or AI output."})
		}
	}
	out.TotalCents = out.RewardsCents + out.CreditsCents + out.AnniversaryCents - out.FeesCents
	return out
}
