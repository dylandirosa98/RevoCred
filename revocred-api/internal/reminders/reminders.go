package reminders

import (
	"fmt"
	"math"
	"sort"
	"strings"
	"time"

	"github.com/revocred/revocred-api/internal/domain"
	"github.com/revocred/revocred-api/internal/strategy"
	"github.com/revocred/revocred-api/internal/valuation"
)

const (
	KindCredit    = "credit"
	KindAnnualFee = "annual_fee"
	KindWallet    = "wallet"
	KindStrategy  = "strategy"

	StatusActive    = "active"
	StatusCompleted = "completed"
	StatusDismissed = "dismissed"
	StatusSnoozed   = "snoozed"

	PriorityHigh   = "high"
	PriorityMedium = "medium"
	PriorityLow    = "low"

	ActionMarkUsed        = "mark_used"
	ActionSetRenewalMonth = "set_renewal_month"
	ActionReviewCard      = "review_card"
	ActionOpenStrategy    = "open_strategy"
)

// Reminder is one deterministic, server-derived in-app card reminder.
type Reminder struct {
	Key              string     `json:"key"`
	Kind             string     `json:"kind"`
	Priority         string     `json:"priority"`
	Status           string     `json:"status"`
	Title            string     `json:"title"`
	Detail           string     `json:"detail"`
	CardID           string     `json:"card_id,omitempty"`
	WalletCardID     string     `json:"wallet_card_id,omitempty"`
	CardName         string     `json:"card_name,omitempty"`
	AmountCents      int64      `json:"amount_cents,omitempty"`
	PeriodLabel      string     `json:"period_label,omitempty"`
	DueAt            *time.Time `json:"due_at,omitempty"`
	SnoozedUntil     *time.Time `json:"snoozed_until,omitempty"`
	ActionKind       string     `json:"action_kind"`
	ActionLabel      string     `json:"action_label"`
	Route            string     `json:"route,omitempty"`
	SourceURL        string     `json:"source_url,omitempty"`
	SourceVerifiedOn string     `json:"source_verified_on,omitempty"`
	Conditions       string     `json:"conditions,omitempty"`
	CanComplete      bool       `json:"can_complete"`
}

// Feed is the deterministic reminder response returned by GET /v1/reminders
// and embedded in GET /v1/bootstrap.
type Feed struct {
	GeneratedAt time.Time  `json:"generated_at"`
	ActiveCount int        `json:"active_count"`
	Reminders   []Reminder `json:"reminders"`
}

// supplementalCreditRules covers vetted issuer-snapshot credits published in
// migrations (such as 000023_sourced_card_credits.sql) that are excluded from
// ongoing dollar valuation but still warrant an actionable cardholder reminder.
var supplementalCreditRules = []valuation.CreditRule{
	{
		CardID:           "20000000-0000-4000-8000-000000000012",
		ProductID:        "us-chase-sapphire-preferred",
		ID:               "us-chase-sapphire-preferred:hotel-credit",
		Title:            "Chase Travel hotel credit",
		FaceCents:        10000,
		Category:         "travel",
		Frequency:        "account anniversary year",
		Conditions:       "Eligible hotel stays must be purchased through Chase Travel; verify current terms with Chase.",
		SourceURL:        "https://creditcards.chase.com/rewards-credit-cards/sapphire/preferred",
		ReviewedOn:       "2026-10-13",
		SourceVerifiedOn: "2026-10-13",
		EvidenceVersion:  "benefit-display-2026-10-13-v1",
	},
}

// Build deterministically derives all current reminders from the member's
// active wallet, strategy playbook, and persisted reminder states.
func Build(now time.Time, wallet []domain.WalletCard, playbook *strategy.Playbook, states map[string]domain.ReminderState) Feed {
	nowUTC := now.UTC()
	out := Feed{
		GeneratedAt: nowUTC,
		Reminders:   make([]Reminder, 0),
	}

	rulesByCard := make(map[string][]valuation.CreditRule)
	for _, rule := range valuation.ReviewedCreditRules() {
		rulesByCard[rule.CardID] = append(rulesByCard[rule.CardID], rule)
	}
	for _, rule := range supplementalCreditRules {
		rulesByCard[rule.CardID] = append(rulesByCard[rule.CardID], rule)
	}

	activeWallet := make([]domain.WalletCard, 0, len(wallet))
	ownedNames := make(map[string]bool, len(wallet))
	seenCards := make(map[string]bool, len(wallet))
	for _, item := range wallet {
		if item.Status != "active" || item.Card == nil {
			continue
		}
		if item.CatalogCardID != "" && seenCards[item.CatalogCardID] {
			continue
		}
		seenCards[item.CatalogCardID] = true
		activeWallet = append(activeWallet, item)
		ownedNames[strings.ToLower(strings.TrimSpace(item.Card.Name))] = true
	}

	// Stable iteration order over wallet cards regardless of DB order.
	sort.SliceStable(activeWallet, func(i, j int) bool {
		if activeWallet[i].Card.Name != activeWallet[j].Card.Name {
			return activeWallet[i].Card.Name < activeWallet[j].Card.Name
		}
		return activeWallet[i].ID < activeWallet[j].ID
	})

	for _, item := range activeWallet {
		card := item.Card
		renewalMonth := effectiveRenewalMonth(item)

		// 1. Sourced recurring card credits (never on terms_unknown cards).
		if !card.TermsUnknown {
			for _, rule := range rulesByCard[card.ID] {
				rem := buildCreditReminder(nowUTC, item, rule, renewalMonth)
				applyState(&rem, nowUTC, states)
				out.Reminders = append(out.Reminders, rem)
			}
		}

		// 2. Annual fee check-ins & renewal-month prompt for fee-bearing cards.
		if card.AnnualFeeCents > 0 {
			if rem, ok := buildAnnualFeeReminder(nowUTC, item, renewalMonth); ok {
				applyState(&rem, nowUTC, states)
				out.Reminders = append(out.Reminders, rem)
			}
		}

		// 3. Wallet completeness nudge for cards added without terms.
		if card.TermsUnknown {
			rem := Reminder{
				Key:          fmt.Sprintf("wallet-terms.%s", sanitizeKeyPart(item.ID)),
				Kind:         KindWallet,
				Priority:     PriorityLow,
				Status:       StatusActive,
				Title:        fmt.Sprintf("Add terms for %s", card.Name),
				Detail:       "This card is excluded from your wallet score and purchase guide because its rates are missing. Re-add it with terms to improve accuracy.",
				CardID:       card.ID,
				WalletCardID: item.ID,
				CardName:     card.Name,
				ActionKind:   ActionReviewCard,
				ActionLabel:  "Open wallet",
				Route:        "/cards",
				CanComplete:  false,
			}
			applyState(&rem, nowUTC, states)
			out.Reminders = append(out.Reminders, rem)
		}
	}

	// 4. Strategy next-step nudge when a playbook recommends an unowned next card.
	if playbook != nil && strings.TrimSpace(string(playbook.Code)) != "" && strings.TrimSpace(playbook.NextCard) != "" {
		codeStr := strings.TrimSpace(string(playbook.Code))
		nextName := strings.TrimSpace(playbook.NextCard)
		if !ownedNames[strings.ToLower(nextName)] {
			rem := Reminder{
				Key:         fmt.Sprintf("strategy-next.%s.%s", sanitizeKeyPart(codeStr), sanitizeKeyPart(nextName)),
				Kind:        KindStrategy,
				Priority:    PriorityLow,
				Status:      StatusActive,
				Title:       fmt.Sprintf("Next strategy step: %s", nextName),
				Detail:      fmt.Sprintf("Your %s roadmap highlights %s when you are ready for your next card. Verify current issuer terms before applying.", codeStr, nextName),
				CardName:    nextName,
				ActionKind:  ActionOpenStrategy,
				ActionLabel: "View strategy",
				Route:       "/strategy",
				CanComplete: false,
			}
			applyState(&rem, nowUTC, states)
			out.Reminders = append(out.Reminders, rem)
		}
	}

	sort.SliceStable(out.Reminders, func(i, j int) bool {
		a, b := out.Reminders[i], out.Reminders[j]
		if sr := statusRank(a.Status) - statusRank(b.Status); sr != 0 {
			return sr < 0
		}
		if pr := priorityRank(a.Priority) - priorityRank(b.Priority); pr != 0 {
			return pr < 0
		}
		if kr := kindRank(a.Kind) - kindRank(b.Kind); kr != 0 {
			return kr < 0
		}
		if a.DueAt != nil && b.DueAt != nil && !a.DueAt.Equal(*b.DueAt) {
			return a.DueAt.Before(*b.DueAt)
		}
		if (a.DueAt != nil) != (b.DueAt != nil) {
			return a.DueAt != nil
		}
		return a.Key < b.Key
	})

	for _, rem := range out.Reminders {
		if rem.Status == StatusActive {
			out.ActiveCount++
		}
	}
	return out
}

func buildCreditReminder(now time.Time, item domain.WalletCard, rule valuation.CreditRule, renewalMonth int) Reminder {
	card := item.Card
	freqLower := strings.ToLower(rule.Frequency)

	var (
		periodKey    string
		periodLabel  string
		periodAmount int64
		dueAt        *time.Time
		cadenceNote  string
		priority     = PriorityMedium
	)

	switch {
	case strings.Contains(freqLower, "monthly"):
		periodKey = fmt.Sprintf("%04d-%02d", now.Year(), int(now.Month()))
		periodLabel = fmt.Sprintf("%s %d", now.Month().String()[:3], now.Year())
		end := endOfMonth(now.Year(), now.Month())
		dueAt = &end
		nextMonth := time.Date(now.Year(), now.Month()+1, 1, 0, 0, 0, 0, time.UTC)
		cadenceNote = fmt.Sprintf("Monthly credit · Resets %s 1", nextMonth.Month().String()[:3])

		if strings.Contains(freqLower, "december") && strings.Contains(freqLower, "$15") && strings.Contains(freqLower, "$20") {
			if now.Month() == time.December {
				periodAmount = 3500
				cadenceNote = "Monthly credit ($15 + $20 Dec bonus) · Resets Jan 1"
			} else {
				periodAmount = 1500
			}
		} else {
			periodAmount = rule.FaceCents / 12
		}

		daysLeft := daysBetween(now, end)
		if daysLeft <= 7 {
			priority = PriorityHigh
		}

	case strings.Contains(freqLower, "half-year"):
		if now.Month() <= time.June {
			periodKey = fmt.Sprintf("%04d-h1", now.Year())
			periodLabel = fmt.Sprintf("Jan–Jun %d", now.Year())
			end := endOfMonth(now.Year(), time.June)
			dueAt = &end
			cadenceNote = "Semi-annual credit · Resets Jul 1"
			if daysBetween(now, end) <= 21 {
				priority = PriorityHigh
			}
		} else {
			periodKey = fmt.Sprintf("%04d-h2", now.Year())
			periodLabel = fmt.Sprintf("Jul–Dec %d", now.Year())
			end := endOfMonth(now.Year(), time.December)
			dueAt = &end
			cadenceNote = "Semi-annual credit · Resets Jan 1"
			if daysBetween(now, end) <= 21 {
				priority = PriorityHigh
			}
		}
		periodAmount = rule.FaceCents / 2

	case strings.Contains(freqLower, "anniversary"):
		periodAmount = rule.FaceCents
		if renewalMonth >= 1 && renewalMonth <= 12 {
			endYear := now.Year()
			if int(now.Month()) >= renewalMonth {
				endYear = now.Year() + 1
			}
			resetDate := time.Date(endYear, time.Month(renewalMonth), 1, 0, 0, 0, 0, time.UTC)
			end := resetDate.Add(-time.Second)
			dueAt = &end
			periodKey = fmt.Sprintf("anniv-%04d-%02d", endYear, renewalMonth)
			periodLabel = fmt.Sprintf("Through %s %d", end.Month().String()[:3], end.Year())
			cadenceNote = fmt.Sprintf("Anniversary-year credit · Resets %s %d", resetDate.Month().String()[:3], resetDate.Year())
			daysLeft := daysBetween(now, end)
			if daysLeft <= 30 {
				priority = PriorityHigh
			} else if daysLeft <= 90 {
				priority = PriorityMedium
			} else {
				priority = PriorityLow
			}
		} else {
			periodKey = fmt.Sprintf("%04d", now.Year())
			periodLabel = "Cardmember year"
			cadenceNote = "Anniversary-year credit · Set renewal month for exact reset date"
			priority = PriorityLow
		}

	default:
		// Calendar year / annual credit.
		periodKey = fmt.Sprintf("%04d", now.Year())
		periodLabel = fmt.Sprintf("%d", now.Year())
		periodAmount = rule.FaceCents
		end := endOfMonth(now.Year(), time.December)
		dueAt = &end
		cadenceNote = fmt.Sprintf("Annual credit · Resets Jan 1, %d", now.Year()+1)
		daysLeft := daysBetween(now, end)
		if daysLeft <= 30 {
			priority = PriorityHigh
		} else if daysLeft <= 90 {
			priority = PriorityMedium
		} else {
			priority = PriorityLow
		}
	}

	title := creditTitle(rule.Title, periodAmount)
	detail := cadenceNote
	if rule.Conditions != "" {
		detail = fmt.Sprintf("%s · %s", cadenceNote, rule.Conditions)
	}

	return Reminder{
		Key:              fmt.Sprintf("credit.%s.%s.%s", sanitizeKeyPart(card.ID), sanitizeKeyPart(rule.ID), periodKey),
		Kind:             KindCredit,
		Priority:         priority,
		Status:           StatusActive,
		Title:            title,
		Detail:           detail,
		CardID:           card.ID,
		WalletCardID:     item.ID,
		CardName:         card.Name,
		AmountCents:      periodAmount,
		PeriodLabel:      periodLabel,
		DueAt:            dueAt,
		ActionKind:       ActionMarkUsed,
		ActionLabel:      "Mark used",
		Route:            "/cards",
		SourceURL:        rule.SourceURL,
		SourceVerifiedOn: rule.SourceVerifiedOn,
		Conditions:       rule.Conditions,
		CanComplete:      true,
	}
}

func buildAnnualFeeReminder(now time.Time, item domain.WalletCard, renewalMonth int) (Reminder, bool) {
	card := item.Card
	feeText := formatDollars(int64(card.AnnualFeeCents))

	if renewalMonth < 1 || renewalMonth > 12 {
		return Reminder{
			Key:          fmt.Sprintf("renewal-month.%s", sanitizeKeyPart(item.ID)),
			Kind:         KindAnnualFee,
			Priority:     PriorityLow,
			Status:       StatusActive,
			Title:        fmt.Sprintf("Set renewal month for %s", card.Name),
			Detail:       fmt.Sprintf("%s/yr annual fee. Add your renewal month so RevoCred reminds you 30 days before renewal.", feeText),
			CardID:       card.ID,
			WalletCardID: item.ID,
			CardName:     card.Name,
			AmountCents:  int64(card.AnnualFeeCents),
			ActionKind:   ActionSetRenewalMonth,
			ActionLabel:  "Set month",
			Route:        "/cards",
			CanComplete:  false,
		}, true
	}

	m := time.Month(renewalMonth)
	if now.Month() == m {
		end := endOfMonth(now.Year(), m)
		return Reminder{
			Key:          fmt.Sprintf("annual-fee.%s.%04d-%02d", sanitizeKeyPart(item.ID), now.Year(), renewalMonth),
			Kind:         KindAnnualFee,
			Priority:     PriorityHigh,
			Status:       StatusActive,
			Title:        fmt.Sprintf("%s annual fee renews this month", card.Name),
			Detail:       fmt.Sprintf("%s/yr fee renews in %s. Review whether your ongoing rewards and credits still outweigh the annual fee.", feeText, m.String()),
			CardID:       card.ID,
			WalletCardID: item.ID,
			CardName:     card.Name,
			AmountCents:  int64(card.AnnualFeeCents),
			PeriodLabel:  fmt.Sprintf("%s %d renewal", m.String()[:3], now.Year()),
			DueAt:        &end,
			ActionKind:   ActionMarkUsed,
			ActionLabel:  "Mark reviewed",
			Route:        "/cards",
			CanComplete:  true,
		}, true
	}

	nextRenewal := time.Date(now.Year(), m, 1, 0, 0, 0, 0, time.UTC)
	if !nextRenewal.After(now) {
		nextRenewal = time.Date(now.Year()+1, m, 1, 0, 0, 0, 0, time.UTC)
	}
	daysUntil := daysBetween(now, nextRenewal)
	if daysUntil > 35 {
		return Reminder{}, false
	}

	return Reminder{
		Key:          fmt.Sprintf("annual-fee.%s.%04d-%02d", sanitizeKeyPart(item.ID), nextRenewal.Year(), renewalMonth),
		Kind:         KindAnnualFee,
		Priority:     PriorityHigh,
		Status:       StatusActive,
		Title:        fmt.Sprintf("%s annual fee check-in", card.Name),
		Detail:       fmt.Sprintf("%s/yr fee renews in %s (about %d %s away). Review whether your ongoing rewards and credits outweigh the fee.", feeText, m.String(), daysUntil, pluralDays(daysUntil)),
		CardID:       card.ID,
		WalletCardID: item.ID,
		CardName:     card.Name,
		AmountCents:  int64(card.AnnualFeeCents),
		PeriodLabel:  fmt.Sprintf("%s %d renewal", m.String()[:3], nextRenewal.Year()),
		DueAt:        &nextRenewal,
		ActionKind:   ActionMarkUsed,
		ActionLabel:  "Mark reviewed",
		Route:        "/cards",
		CanComplete:  true,
	}, true
}

func effectiveRenewalMonth(item domain.WalletCard) int {
	if item.RenewalMonth != nil && *item.RenewalMonth >= 1 && *item.RenewalMonth <= 12 {
		return *item.RenewalMonth
	}
	if item.OpenedOn != nil {
		return int(item.OpenedOn.UTC().Month())
	}
	return 0
}

func applyState(rem *Reminder, now time.Time, states map[string]domain.ReminderState) {
	if states == nil {
		return
	}
	st, ok := states[rem.Key]
	if !ok {
		return
	}
	switch st.Status {
	case StatusCompleted, StatusDismissed:
		rem.Status = st.Status
	case StatusSnoozed:
		if st.SnoozedUntil != nil && st.SnoozedUntil.After(now) {
			rem.Status = StatusSnoozed
			until := st.SnoozedUntil.UTC()
			rem.SnoozedUntil = &until
		}
	}
}

func creditTitle(rawTitle string, periodAmountCents int64) string {
	clean := strings.TrimSpace(rawTitle)
	if periodAmountCents <= 0 {
		return fmt.Sprintf("Use %s", clean)
	}
	amount := formatDollars(periodAmountCents)
	if strings.Contains(clean, "$") {
		// If the title already states a different annual figure (e.g. "Up to $200 Annual Blacklane Credit"
		// when the semi-annual period amount is $100), prefix the period amount cleanly.
		if strings.Contains(clean, amount) {
			return fmt.Sprintf("Use %s", clean)
		}
		return fmt.Sprintf("Use %s (%s)", amount, clean)
	}
	return fmt.Sprintf("Use %s %s", amount, clean)
}

func formatDollars(cents int64) string {
	if cents%100 == 0 {
		return fmt.Sprintf("$%d", cents/100)
	}
	return fmt.Sprintf("$%.2f", float64(cents)/100.0)
}

func endOfMonth(year int, month time.Month) time.Time {
	return time.Date(year, month+1, 1, 0, 0, 0, 0, time.UTC).Add(-time.Second)
}

func daysBetween(from, to time.Time) int {
	diff := to.Sub(from)
	if diff <= 0 {
		return 0
	}
	return int(math.Ceil(diff.Hours() / 24.0))
}

func pluralDays(n int) string {
	if n == 1 {
		return "day"
	}
	return "days"
}

func sanitizeKeyPart(value string) string {
	var b strings.Builder
	lastDash := false
	for _, r := range strings.ToLower(strings.TrimSpace(value)) {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') {
			b.WriteRune(r)
			lastDash = false
		} else if !lastDash && b.Len() > 0 {
			b.WriteByte('-')
			lastDash = true
		}
	}
	s := strings.Trim(b.String(), "-")
	if s == "" {
		return "item"
	}
	if len(s) > 48 {
		s = strings.TrimRight(s[:48], "-")
	}
	return s
}

func statusRank(status string) int {
	switch status {
	case StatusActive:
		return 0
	case StatusSnoozed:
		return 1
	case StatusCompleted:
		return 2
	case StatusDismissed:
		return 3
	default:
		return 4
	}
}

func priorityRank(priority string) int {
	switch priority {
	case PriorityHigh:
		return 0
	case PriorityMedium:
		return 1
	case PriorityLow:
		return 2
	default:
		return 3
	}
}

func kindRank(kind string) int {
	switch kind {
	case KindAnnualFee:
		return 0
	case KindCredit:
		return 1
	case KindWallet:
		return 2
	case KindStrategy:
		return 3
	default:
		return 4
	}
}
