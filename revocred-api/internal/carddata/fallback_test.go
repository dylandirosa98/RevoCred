package carddata

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"
)

func TestRefreshFailureRetainsPersistentSnapshotAndRestartLoadsIt(t *testing.T) {
	body, err := os.ReadFile("testdata/cards.json")
	if err != nil {
		t.Fatal(err)
	}
	status := http.StatusOK
	s := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(status); w.Write(body) }))
	defer s.Close()
	saved := &memoryStore{}
	c := New(s.Client(), saved, s.URL)
	if err := c.Refresh(context.Background()); err != nil {
		t.Fatal(err)
	}
	previous := c.Get("20000000-0000-4000-8000-000000000013")
	status = http.StatusServiceUnavailable
	if c.Refresh(context.Background()) == nil {
		t.Fatal("upstream outage accepted")
	}
	status = http.StatusOK
	body = []byte(`[{"id":"unexpected-product"}]`)
	if c.Refresh(context.Background()) == nil {
		t.Fatal("incomplete snapshot accepted")
	}
	if saved.saves != 1 || c.Get("20000000-0000-4000-8000-000000000013") != previous {
		t.Fatal("failed fetch replaced last good cache")
	}
	restarted := New(s.Client(), saved, s.URL)
	if err := restarted.Load(context.Background()); err != nil {
		t.Fatal(err)
	}
	if got := restarted.Get("20000000-0000-4000-8000-000000000013"); got == nil || got.SnapshotSHA256 != previous.SnapshotSHA256 {
		t.Fatal("persistent fallback not restored")
	}
}

func TestMissingBaseRateAndUnknownRewardUnitsAreRejected(t *testing.T) {
	body, _ := os.ReadFile("testdata/cards.json")
	var rows []map[string]any
	if err := json.Unmarshal(body, &rows); err != nil {
		t.Fatal(err)
	}
	for _, kind := range []string{"base_rate", "rate_type"} {
		t.Run(kind, func(t *testing.T) {
			fresh := make([]map[string]any, len(rows))
			raw, _ := json.Marshal(rows)
			json.Unmarshal(raw, &fresh)
			rewards := fresh[0]["rewards"].(map[string]any)
			if kind == "base_rate" {
				rewards["base_rate"] = nil
			} else {
				rewards["rate_type"] = "unknown_unit"
			}
			invalid, _ := json.Marshal(fresh)
			if _, err := decode(invalid, time.Now()); err == nil {
				t.Fatal("ambiguous reward semantics accepted")
			}
		})
	}
}
