package carddata

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"
)

type memoryStore struct {
	body    []byte
	checked time.Time
	saves   int
	hash    string
}

func (m *memoryStore) LoadCardData(context.Context) ([]byte, time.Time, string, error) {
	return m.body, m.checked, m.hash, nil
}
func (m *memoryStore) SaveCardData(_ context.Context, b []byte, hash string, at time.Time) error {
	m.hash = hash
	m.body = append([]byte(nil), b...)
	m.checked = at
	m.saves++
	return nil
}

func TestFetchUsesExactMappingsAndPreservesConditionalRewards(t *testing.T) {
	body, err := os.ReadFile("testdata/cards.json")
	if err != nil {
		t.Fatal(err)
	}
	s := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("User-Agent") == "" {
			t.Error("missing client identification")
		}
		w.Write(body)
	}))
	defer s.Close()
	saved := &memoryStore{}
	c := New(s.Client(), saved, s.URL)
	if err := c.Refresh(context.Background()); err != nil {
		t.Fatal(err)
	}
	reserve := c.Get("20000000-0000-4000-8000-000000000013")
	if reserve == nil {
		t.Fatal("Sapphire Reserve was not mapped")
	}
	if reserve.ID != "us-chase-sapphire-reserve" || reserve.LastVerified != "2026-07-23" {
		t.Fatalf("wrong record: %+v", reserve)
	}
	if !strings.Contains(strings.Join(reserve.Benefits, " "), "The Edit") {
		t.Fatal("missing hotel credit")
	}
	if !strings.Contains(strings.Join(reserve.RewardRates, " "), "8x") {
		t.Fatal("missing conditional portal rate")
	}
	flex := c.Get("20000000-0000-4000-8000-000000000010")
	text := strings.Join(flex.RewardRates, " ")
	if !strings.Contains(text, "5%") || !strings.Contains(text, "1500") || !strings.Contains(text, "quarter") || !strings.Contains(text, "activation") {
		t.Fatalf("lost cash units/cap/activation: %s", text)
	}
	quick := c.Get("20000000-0000-4000-8000-000000000008")
	if quick == nil {
		t.Fatal("base Quicksilver was not mapped to us-capital-one-quicksilver")
	}
	if quick.ID != "us-capital-one-quicksilver" || quick.IssuerURL != "https://www.capitalone.com/credit-cards/quicksilver/" {
		t.Fatalf("wrong record: %+v", quick)
	}
	if quick.SourceAnnualFee == nil || *quick.SourceAnnualFee != 0 {
		t.Fatalf("wrong annual fee: %+v", quick.SourceAnnualFee)
	}
	if !strings.Contains(strings.Join(quick.RewardRates, " "), "1.5%") {
		t.Fatal("missing base cash-back rate")
	}
	if !strings.Contains(strings.Join(quick.Benefits, " "), "Foreign Transaction") {
		t.Fatal("missing no-foreign-transaction-fee benefit")
	}
	if c.Get("user-owned-custom-card") != nil {
		t.Fatal("custom cards must not be enriched by name")
	}
	discover := c.Get("20000000-0000-4000-8000-000000000021")
	if discover == nil {
		t.Fatal("Discover it Cash Back was not mapped")
	}
	if discover.ID != "us-discover-it-cash-back" {
		t.Fatalf("wrong record: %+v", discover)
	}
	if !strings.Contains(strings.Join(discover.RewardRates, " "), "1%") {
		t.Fatal("missing base cash-back rate")
	}
	if saved.saves != 1 || reserve.Attribution == "" || reserve.LicenseURL == "" || reserve.SnapshotSHA256 == "" {
		t.Fatal("cache persistence or provenance missing")
	}
}
