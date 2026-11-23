package reminders

import (
	"strings"
	"testing"
	"time"

	"github.com/revocred/revocred-api/internal/domain"
	"github.com/revocred/revocred-api/internal/strategy"
)

func intPtr(v int) *int { return &v }

func TestBuildSourcedCreditsAndDecemberBonus(t *testing.T) {
	wallet := []domain.WalletCard{
		{
			ID:            "11111111-1111-4111-8111-111111111111",
			CatalogCardID: "20000000-0000-4000-8000-000000000016",
			Status:        "active",
			RenewalMonth:  intPtr(6),
			Card: &domain.CatalogCard{
				ID:             "20000000-0000-4000-8000-000000000016",
				Name:           "American Express Gold Card",
				AnnualFeeCents: 32500,
			},
		},
		{
			ID:            "22222222-2222-4222-8222-222222222222",
			CatalogCardID: "20000000-0000-4000-8000-000000000017",
			Status:        "active",
			RenewalMonth:  intPtr(6),
			Card: &domain.CatalogCard{
				ID:             "20000000-0000-4000-8000-000000000017",
				Name:           "The Platinum Card from American Express",
				AnnualFeeCents: 69500,
			},
		},
	}

	nov := time.Date(2026, time.November, 24, 12, 0, 0, 0, time.UTC)
	feedNov := Build(nov, wallet, nil, nil)

	foundGoldUber := false
	foundGoldResy := false
	foundPlatUberNov := false
	for _, r := range feedNov.Reminders {
		if strings.Contains(r.Key, "us-amex-gold-uber") {
			foundGoldUber = true
			if r.AmountCents != 1000 || r.PeriodLabel != "Nov 2026" || r.Priority != PriorityHigh {
				t.Fatalf("unexpected Gold Uber credit in late Nov: %+v", r)
			}
			if !r.CanComplete || r.ActionKind != ActionMarkUsed {
				t.Fatalf("credit must be completable: %+v", r)
			}
		}
		if strings.Contains(r.Key, "us-amex-gold-resy") {
			foundGoldResy = true
			if r.AmountCents != 5000 || r.PeriodLabel != "Jul–Dec 2026" {
				t.Fatalf("unexpected Gold Resy H2 credit: %+v", r)
			}
		}
		if strings.Contains(r.Key, "us-amex-platinum-benefit-2") {
			foundPlatUberNov = true
			if r.AmountCents != 1500 {
				t.Fatalf("expected $15 Platinum Uber Cash in Nov, got %d", r.AmountCents)
			}
		}
	}
	if !foundGoldUber || !foundGoldResy || !foundPlatUberNov {
		t.Fatalf("missing expected credit reminders: goldUber=%v goldResy=%v platUber=%v", foundGoldUber, foundGoldResy, foundPlatUberNov)
	}

	// December Platinum Uber Cash includes the $20 December bonus ($35 total).
	dec := time.Date(2026, time.December, 5, 12, 0, 0, 0, time.UTC)
	feedDec := Build(dec, wallet, nil, nil)
	foundPlatUberDec := false
	for _, r := range feedDec.Reminders {
		if strings.Contains(r.Key, "us-amex-platinum-benefit-2") {
			foundPlatUberDec = true
			if r.AmountCents != 3500 || r.PeriodLabel != "Dec 2026" {
				t.Fatalf("expected $35 Platinum Uber Cash in Dec, got %+v", r)
			}
		}
	}
	if !foundPlatUberDec {
		t.Fatal("missing Platinum Uber Cash in Dec")
	}
}

func TestBuildAnnualFeeWindowAndRenewalPrompt(t *testing.T) {
	decCard := domain.WalletCard{
		ID:            "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
		CatalogCardID: "20000000-0000-4000-8000-000000000015",
		Status:        "active",
		RenewalMonth:  intPtr(12),
		Card: &domain.CatalogCard{
			ID:             "20000000-0000-4000-8000-000000000015",
			Name:           "Capital One Venture X",
			AnnualFeeCents: 39500,
		},
	}
	missingMonthCard := domain.WalletCard{
		ID:            "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
		CatalogCardID: "20000000-0000-4000-8000-000000000012",
		Status:        "active",
		Card: &domain.CatalogCard{
			ID:             "20000000-0000-4000-8000-000000000012",
			Name:           "Chase Sapphire Preferred",
			AnnualFeeCents: 9500,
		},
	}
	farCard := domain.WalletCard{
		ID:            "cccccccc-cccc-4ccc-8ccc-cccccccccccc",
		CatalogCardID: "20000000-0000-4000-8000-000000000013",
		Status:        "active",
		RenewalMonth:  intPtr(6),
		Card: &domain.CatalogCard{
			ID:             "20000000-0000-4000-8000-000000000013",
			Name:           "Chase Sapphire Reserve",
			AnnualFeeCents: 55000,
		},
	}

	now := time.Date(2026, time.November, 20, 12, 0, 0, 0, time.UTC)
	feed := Build(now, []domain.WalletCard{decCard, missingMonthCard, farCard}, nil, nil)

	var foundUpcoming, foundPrompt, foundFar bool
	for _, r := range feed.Reminders {
		if r.Kind != KindAnnualFee {
			continue
		}
		switch r.WalletCardID {
		case decCard.ID:
			foundUpcoming = true
			if r.Priority != PriorityHigh || r.PeriodLabel != "Dec 2026 renewal" || !r.CanComplete {
				t.Fatalf("unexpected upcoming annual fee reminder: %+v", r)
			}
		case missingMonthCard.ID:
			foundPrompt = true
			if r.ActionKind != ActionSetRenewalMonth || r.CanComplete {
				t.Fatalf("unexpected renewal month prompt: %+v", r)
			}
		case farCard.ID:
			foundFar = true
		}
	}
	if !foundUpcoming || !foundPrompt || foundFar {
		t.Fatalf("annual fee window mismatch: upcoming=%v prompt=%v far=%v", foundUpcoming, foundPrompt, foundFar)
	}

	// Year rollover: mid-December with January renewal month should trigger high-priority check-in.
	janCard := decCard
	janCard.RenewalMonth = intPtr(1)
	decNow := time.Date(2026, time.December, 15, 12, 0, 0, 0, time.UTC)
	rolloverFeed := Build(decNow, []domain.WalletCard{janCard}, nil, nil)
	foundJan := false
	for _, r := range rolloverFeed.Reminders {
		if r.Kind == KindAnnualFee && r.WalletCardID == janCard.ID {
			foundJan = true
			if r.PeriodLabel != "Jan 2027 renewal" || !strings.HasSuffix(r.Key, ".2027-01") {
				t.Fatalf("expected Jan 2027 rollover check-in, got %+v", r)
			}
		}
	}
	if !foundJan {
		t.Fatal("missing Jan renewal check-in during mid-December")
	}
}

func TestBuildWalletNudgesStrategyAndStateOverlay(t *testing.T) {
	now := time.Date(2026, time.November, 10, 12, 0, 0, 0, time.UTC)
	wallet := []domain.WalletCard{
		{
			ID:            "dddddddd-dddd-4ddd-8ddd-dddddddddddd",
			CatalogCardID: "custom-card-1",
			Status:        "active",
			Card: &domain.CatalogCard{
				ID:           "custom-card-1",
				Name:         "Local Credit Union Card",
				TermsUnknown: true,
			},
		},
	}
	pb := &strategy.Playbook{
		Code:     "S03",
		NextCard: "Chase Freedom Unlimited",
	}

	initial := Build(now, wallet, pb, nil)
	if initial.ActiveCount != 2 || len(initial.Reminders) != 2 {
		t.Fatalf("expected 2 active nudges (wallet terms + strategy next), got %+v", initial)
	}

	termsKey := initial.Reminders[0].Key
	strategyKey := initial.Reminders[1].Key
	future := now.Add(48 * time.Hour)
	past := now.Add(-1 * time.Hour)

	states := map[string]domain.ReminderState{
		termsKey:    {ReminderKey: termsKey, Status: StatusDismissed, UpdatedAt: now},
		strategyKey: {ReminderKey: strategyKey, Status: StatusSnoozed, SnoozedUntil: &future, UpdatedAt: now},
	}
	updated := Build(now, wallet, pb, states)
	if updated.ActiveCount != 0 {
		t.Fatalf("expected 0 active reminders after dismiss+snooze, got %d", updated.ActiveCount)
	}
	// Snoozed sorts ahead of dismissed.
	if updated.Reminders[0].Status != StatusSnoozed || updated.Reminders[1].Status != StatusDismissed {
		t.Fatalf("unexpected status ordering: %+v", updated.Reminders)
	}

	// Expired snooze automatically wakes back to active.
	states[strategyKey] = domain.ReminderState{ReminderKey: strategyKey, Status: StatusSnoozed, SnoozedUntil: &past, UpdatedAt: now}
	woke := Build(now, wallet, pb, states)
	if woke.ActiveCount != 1 || woke.Reminders[0].Key != strategyKey || woke.Reminders[0].Status != StatusActive {
		t.Fatalf("expired snooze should reactivate: %+v", woke)
	}
}

func TestBuildIsOrderIndependentAndDeterministic(t *testing.T) {
	now := time.Date(2026, time.May, 15, 10, 0, 0, 0, time.UTC)
	a := domain.WalletCard{
		ID:            "11111111-1111-4111-8111-111111111111",
		CatalogCardID: "20000000-0000-4000-8000-000000000016",
		Status:        "active",
		Card:          &domain.CatalogCard{ID: "20000000-0000-4000-8000-000000000016", Name: "Amex Gold", AnnualFeeCents: 32500},
	}
	b := domain.WalletCard{
		ID:            "22222222-2222-4222-8222-222222222222",
		CatalogCardID: "20000000-0000-4000-8000-000000000015",
		Status:        "active",
		Card:          &domain.CatalogCard{ID: "20000000-0000-4000-8000-000000000015", Name: "Venture X", AnnualFeeCents: 39500},
	}
	first := Build(now, []domain.WalletCard{a, b}, nil, nil)
	second := Build(now, []domain.WalletCard{b, a}, nil, nil)
	if len(first.Reminders) != len(second.Reminders) || len(first.Reminders) == 0 {
		t.Fatalf("counts differ: %d vs %d", len(first.Reminders), len(second.Reminders))
	}
	for i := range first.Reminders {
		if first.Reminders[i].Key != second.Reminders[i].Key {
			t.Fatalf("order mismatch at %d: %s vs %s", i, first.Reminders[i].Key, second.Reminders[i].Key)
		}
	}
}
