package carddata

import (
	"encoding/json"
	"os"
	"testing"
	"time"
)

func TestRejectsIssuerLinksOutsideExpectedBank(t *testing.T) {
	raw, _ := os.ReadFile("testdata/cards.json")
	var cards []map[string]any
	json.Unmarshal(raw, &cards)
	for _, target := range []string{"https://evil.example/card", "https://www.americanexpress.com.evil.example/card", "https://name:password@www.americanexpress.com/card"} {
		cards[0]["official_url"] = target
		bad, _ := json.Marshal(cards)
		if _, err := decode(bad, time.Now()); err == nil {
			t.Fatalf("untrusted issuer link accepted: %s", target)
		}
	}
}
