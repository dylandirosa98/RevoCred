package purchaseguide

import (
	"encoding/json"
	"reflect"
	"strings"
	"testing"

	"github.com/revocred/revocred-api/internal/domain"
)

func fallbackOptions(t *testing.T, c Category) []Option {
	t.Helper()
	raw, err := json.Marshal(c)
	if err != nil {
		t.Fatal(err)
	}
	var response struct {
		Fallback []Option `json:"fallback_options"`
	}
	if err := json.Unmarshal(raw, &response); err != nil {
		t.Fatal(err)
	}
	return response.Fallback
}

func TestRentShowsHighestBaseAsConditionalFallback(t *testing.T) {
	discover := sourceCard(t, "us-discover-it-cash-back")
	double := sourceCard(t, "us-citi-double-cash")
	got := category(t, Build([]domain.WalletCard{discover, double}, DefaultOptions()), "rent")
	if len(got.Options) != 0 {
		t.Fatal("unconfirmed rent cannot become a supported earning rule")
	}
	fallback := fallbackOptions(t, got)
	if len(fallback) != 2 || fallback[0].CardID != double.Card.ID || fallback[0].Rate != 2 || fallback[1].Rate != 1 {
		t.Fatalf("want ordered known base rates, got %+v", fallback)
	}
	if fallback[0].Reason == "" || len(fallback[0].Conditions) == 0 {
		t.Fatal("rent fallback must disclose eligibility and payment fees")
	}
}

func TestRentKnownRuleKeepsPriorityOverUnconfirmedBase(t *testing.T) {
	known := domain.WalletCard{Status: "active", Card: &domain.CatalogCard{ID: "rent-card", Name: "Rent card", RewardsType: "cash_back", RewardRates: map[string]float64{"rent": 1}}}
	double := sourceCard(t, "us-citi-double-cash")
	got := category(t, Build([]domain.WalletCard{double, known}, DefaultOptions()), "rent")
	if len(got.Options) != 1 || got.Options[0].CardID != "rent-card" || got.Options[0].Rate != 1 {
		t.Fatalf("known rent rule must remain separate from conditional base: %+v", got)
	}
	if len(fallbackOptions(t, got)) != 1 || got.Tied {
		t.Fatalf("wrong fallback or tie: %+v", got)
	}
}

func TestRentFallbackNeverUsesUnknownInactiveOrZeroTerms(t *testing.T) {
	wallet := []domain.WalletCard{
		{Status: "active", Card: &domain.CatalogCard{ID: "unknown", Name: "Unknown", TermsUnknown: true, RewardRates: map[string]float64{"other": 99}}},
		{Status: "inactive", Card: &domain.CatalogCard{ID: "inactive", Name: "Inactive", RewardRates: map[string]float64{"other": 99}}},
		{Status: "active", Card: &domain.CatalogCard{ID: "missing", Name: "Missing"}},
		{Status: "active", Card: &domain.CatalogCard{ID: "zero", Name: "Zero", RewardRates: map[string]float64{"other": 0}}},
	}
	got := category(t, Build(wallet, DefaultOptions()), "rent")
	if len(got.Options) != 0 || len(fallbackOptions(t, got)) != 0 {
		t.Fatalf("invented eligibility/rate: %+v", got)
	}
}

func TestRentFallbackTiesAreStableAndDuplicatesDoNotCountTwice(t *testing.T) {
	a := domain.WalletCard{Status: "active", Card: &domain.CatalogCard{ID: "a", Name: "Same name", RewardsType: "cash_back", RewardRates: map[string]float64{"other": 2}}}
	b := domain.WalletCard{Status: "active", Card: &domain.CatalogCard{ID: "b", Name: "Same name", RewardsType: "cash_back", RewardRates: map[string]float64{"other": 2}}}
	first := category(t, Build([]domain.WalletCard{b, a, b}, DefaultOptions()), "rent")
	second := category(t, Build([]domain.WalletCard{a, b}, DefaultOptions()), "rent")
	fallback := fallbackOptions(t, first)
	if !first.Tied || len(fallback) != 2 || fallback[0].CardID != "a" || !reflect.DeepEqual(first, second) {
		t.Fatalf("unstable tie: %+v vs %+v", first, second)
	}
}

func TestOrdinaryPurchasesStillUseApplicableRateOrHighestBase(t *testing.T) {
	double := sourceCard(t, "us-citi-double-cash")
	discover := sourceCard(t, "us-discover-it-cash-back")
	guides := Build([]domain.WalletCard{discover, double}, DefaultOptions())
	for _, id := range []string{"dining", "groceries", "travel", "gas", "transit", "online-shopping"} {
		got := category(t, guides, id)
		if got.Options[0].CardID != double.Card.ID || got.Options[0].Rate != 2 || len(fallbackOptions(t, got)) != 0 {
			t.Fatalf("%s: %+v", id, got)
		}
	}
	gold := sourceCard(t, "us-amex-gold")
	dining := category(t, Build([]domain.WalletCard{double, gold}, DefaultOptions()), "dining")
	if dining.Options[0].CardID != gold.Card.ID || dining.Options[0].Rate != 4 {
		t.Fatalf("lost valid category bonus: %+v", dining)
	}
	rent := category(t, guides, "rent")
	if strings.Contains(rent.Assumptions, "Eligible purchases assumed") || !strings.Contains(rent.Assumptions, "before fees") {
		t.Fatal("rent fallback mislabeled as confirmed eligibility")
	}
}
