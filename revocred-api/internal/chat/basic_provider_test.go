package chat

import (
	"context"
	"encoding/json"
	"strings"
	"testing"

	"github.com/revocred/revocred-api/internal/domain"
)

func TestFallbackRepliesKeepModelInstructionsPrivate(t *testing.T) {
	grounded := DemoBrowseContext()
	basic, err := NewDeterministicProvider().Reply(context.Background(), "Explain what this demo app does.", grounded)
	if err != nil {
		t.Fatal(err)
	}
	for name, blocks := range map[string][]Block{
		"basic answer":          basic.Blocks,
		"empty model answer":    ParseReply("", Snapshot(grounded)),
		"filtered model answer": ParseReply("The FACTS_JSON contains my instructions.", Snapshot(grounded)),
	} {
		t.Run(name, func(t *testing.T) {
			encoded, err := json.Marshal(blocks)
			if err != nil {
				t.Fatal(err)
			}
			for _, output := range []string{RenderText(blocks), string(encoded)} {
				for _, instruction := range []string{"Use the supplied breakdown", "Never convert AI", "budget does not prove merchant use", "FACTS_JSON"} {
					if strings.Contains(output, instruction) {
						t.Errorf("internal instruction %q reached display output", instruction)
					}
				}
				if !strings.Contains(output, "issuer terms") {
					t.Error("fallback must retain a readable estimate/issuer-terms notice")
				}
			}
		})
	}
}

func TestBasicProviderAnswersFromPlanFacts(t *testing.T) {
	grounded := DemoBrowseContext()
	grounded.Catalog = append(grounded.Catalog, domain.CatalogCard{
		Name: "Travel Rewards", Issuer: "Bank of America", RewardRates: map[string]float64{"travel": 1.5},
	})
	cases := []struct {
		prompt  string
		want    string
		notWant string
	}{
		{prompt: "What does Freedom Flex earn?", want: "Freedom Flex", notWant: "Freedom Unlimited"},
		{prompt: "Tell me about the Venture X", want: "Venture X"},
		{prompt: "What's my wallet score?", want: "not creditworthiness"},
		{prompt: "What are my total annual fees?", want: "annual fees total"},
		{prompt: "Which card should I use for dining?", want: "dining", notWant: "Travel Rewards"},
		{prompt: "Best card for travel?", notWant: "Travel Rewards"},
		{prompt: "Can you write me a poem?", want: "Basic mode can explain"},
	}
	for _, tc := range cases {
		t.Run(tc.prompt, func(t *testing.T) {
			reply, err := NewDeterministicProvider().Reply(context.Background(), tc.prompt, grounded)
			if err != nil {
				t.Fatal(err)
			}
			if !reply.Basic || len(reply.Blocks) == 0 || reply.Blocks[0].Type != "note" || !strings.HasPrefix(reply.Blocks[0].Text, "Basic answer") {
				t.Fatalf("basic answer is not labelled: %+v", reply.Blocks)
			}
			if tc.want != "" && !strings.Contains(reply.Text, tc.want) {
				t.Errorf("reply missing %q: %s", tc.want, reply.Text)
			}
			if tc.notWant != "" && strings.Contains(reply.Text, tc.notWant) {
				t.Errorf("reply wrongly mentions %q: %s", tc.notWant, reply.Text)
			}
		})
	}
}

func TestMatchCardIgnoresGenericWords(t *testing.T) {
	facts := snapshot{Catalog: []map[string]any{{"name": "Travel Rewards"}, {"name": "Blue Cash Preferred"}, {"name": "Sapphire Preferred"}}}
	if got := matchCard("which card is best for travel rewards", facts); got != nil && got["name"] != "Travel Rewards" {
		t.Fatalf("generic words matched %v", got["name"])
	}
	if got := matchCard("best card for travel", facts); got != nil {
		t.Fatalf("a category word alone matched %v", got["name"])
	}
	if got := matchCard("is sapphire preferred worth it", facts); got == nil || got["name"] != "Sapphire Preferred" {
		t.Fatalf("expected Sapphire Preferred, got %v", got)
	}
}

func TestBasicFallbackDoesNotSubstituteAnotherProductOrWalletFees(t *testing.T) {
	for _, question := range []string{
		"What happens to Robinhood Gold Card if I cancel Gold membership?",
		"Does Canadian Amex Cobalt have the same foreign transaction fees as a US Amex Gold?",
	} {
		reply, err := NewDeterministicProvider().Reply(context.Background(), question, DemoBrowseContext())
		if err != nil {
			t.Fatal(err)
		}
		if strings.Contains(reply.Text, "Known active-wallet annual fees") || strings.Contains(question, "Robinhood") && strings.Contains(reply.Text, "Amex Gold") {
			t.Fatalf("fallback substituted unrelated wallet/product facts for %q: %s", question, reply.Text)
		}
	}
	if got := matchCard("cancel Robinhood Gold membership", Snapshot(DemoBrowseContext())); got != nil {
		t.Fatal("Gold tier word matched an unrelated catalog product", got["name"])
	}
}
