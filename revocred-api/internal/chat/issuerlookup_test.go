package chat

import (
	"context"
	"strings"
	"testing"
)

type fixedIssuerClient struct {
	page string
	err  error
}

func (c fixedIssuerClient) Get(context.Context, string) (string, error) { return c.page, c.err }

func TestIssuerLookupUsesOnlySavedOfficialSource(t *testing.T) {
	facts := snapshot{IssuerSources: []issuerSource{{Name: "Sapphire Preferred", SourceURL: "https://issuer.example/card"}}}
	got := LookupCurrentIssuerTerms(context.Background(), "What does Sapphire Preferred earn now?", facts, fixedIssuerClient{page: "<p>Earn 3 points on dining. Annual fee $95.</p>"})
	if got == nil || got.Status != "read" || !strings.Contains(got.Excerpt, "Annual fee") || got.SourceURL != "https://issuer.example/card" {
		t.Fatalf("%+v", got)
	}
	if LookupCurrentIssuerTerms(context.Background(), "Tell me about a card with no saved source", facts, fixedIssuerClient{}) != nil {
		t.Fatal("lookup ran without a named saved source")
	}
}
