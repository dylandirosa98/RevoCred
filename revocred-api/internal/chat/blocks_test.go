package chat

import (
	"strings"
	"testing"

	"github.com/revocred/revocred-api/internal/domain"
)

func sampleFacts() snapshot {
	return Snapshot(Context{
		Metrics: domain.WalletMetrics{Score: 72, Rating: "Good", YearlyValue: 420},
		Wallet: []domain.WalletCard{{
			Status: "active",
			Card: &domain.CatalogCard{
				Name: "Freedom Unlimited", Issuer: "Chase", RewardRates: map[string]float64{"other": 1.5, "dining": 3, "groceries": 3},
			},
		}},
	})
}

func TestParseReplyBuildsBlocks(t *testing.T) {
	facts := sampleFacts()
	facts.MonthlySpend = map[string]int64{"dining": 40000, "groceries": 50000, "gas": 10000}
	facts.NextCard = "Freedom Unlimited"
	facts.NextCardValueCents = 12000
	facts.WalletValueCents = 42000

	blocks := ParseReply("### Your next move\nFreedom Unlimited fits your groceries.\n\n- Best modeled groceries rate\n- No annual fee\n\n[[chart:spend_by_category|Where your money goes]]\n\n#### Verify with the issuer.", facts)

	kinds := []string{}
	for _, block := range blocks {
		kinds = append(kinds, block.Type)
	}
	want := []string{"heading", "paragraph", "bullets", "chart", "note"}
	if strings.Join(kinds, ",") != strings.Join(want, ",") {
		t.Fatalf("block order = %v, want %v", kinds, want)
	}
	if len(blocks[2].Items) != 2 {
		t.Fatalf("bullets = %+v", blocks[2].Items)
	}
	chart := blocks[3].Chart
	if chart == nil || chart.Title != "Where your money goes" || chart.Unit != "usd" {
		t.Fatalf("chart = %+v", chart)
	}
	// Groceries were the largest entered category, so they must lead.
	if len(chart.Bars) != 3 || chart.Bars[0].Label != "Groceries" || chart.Bars[0].Value != 500 {
		t.Fatalf("bars = %+v", chart.Bars)
	}
	text := RenderText(blocks)
	if strings.Contains(text, "[[chart:") {
		t.Fatalf("raw chart marker leaked into text: %s", text)
	}
}

// The model may choose a chart but must never supply its numbers. A reply that
// tries to write values inside a chart marker, or invents a chart, is dropped.
func TestChartValuesComeFromTheServer(t *testing.T) {
	facts := sampleFacts()
	facts.MonthlySpend = map[string]int64{"dining": 40000}

	blocks := ParseReply("[[chart:dining=999999|Wallet]]", facts)
	for _, block := range blocks {
		if block.Type == "chart" {
			t.Fatal("an unknown chart reference produced a chart")
		}
	}
	if text := RenderText(blocks); strings.Contains(text, "999999") && strings.Contains(text, "dining") {
		t.Fatalf("invented chart values reached the user: %s", text)
	}

	blocks = ParseReply("[[chart:wallet_rates]]", facts)
	if len(blocks) != 1 || blocks[0].Chart == nil {
		t.Fatalf("known chart missing: %+v", blocks)
	}
	for _, bar := range blocks[0].Chart.Bars {
		if bar.Value > 100 {
			t.Fatalf("implausible rate survived: %+v", bar)
		}
		if bar.Caption != "" && !strings.Contains(factsText(facts), strings.ToLower(bar.Caption)) {
			t.Fatalf("chart caption %q is not a fact", bar.Caption)
		}
	}
}

func TestWalletRateChartUsesTheCardRewardUnit(t *testing.T) {
	blocks := ParseReply("[[chart:wallet_rates]]", Snapshot(DemoBrowseContext()))
	if len(blocks) != 1 || blocks[0].Chart == nil {
		t.Fatalf("wallet rate chart missing: %+v", blocks)
	}
	labels := map[string]string{}
	for _, bar := range blocks[0].Chart.Bars {
		labels[bar.Label] = bar.ValueLabel
	}
	if labels["Groceries"] != "4 points per dollar" {
		t.Fatalf("groceries value label = %q", labels["Groceries"])
	}
}

func TestParseReplyPreservesFinalSourceURL(t *testing.T) {
	blocks := ParseReply("Use Amex Gold for this purchase.\nSource: https://issuer.example/benefit_guide.pdf", Snapshot(DemoBrowseContext()))
	text := RenderText(blocks)
	if !strings.Contains(text, "https://issuer.example/benefit_guide.pdf") {
		t.Fatalf("source lost: %s", text)
	}
}

func factsText(facts snapshot) string {
	var b strings.Builder
	for _, card := range facts.Wallet {
		b.WriteString(strings.ToLower(strings.TrimSpace(card["name"].(string))) + " ")
	}
	return b.String()
}

func TestParseReplyFallsBackWhenEmpty(t *testing.T) {
	blocks := ParseReply("   \n  \n", sampleFacts())
	if len(blocks) == 0 || blocks[0].Text == "" {
		t.Fatalf("an empty reply must still produce something readable: %+v", blocks)
	}
}

func TestRenderTextRespectsStorageLimit(t *testing.T) {
	blocks := []Block{}
	for i := 0; i < 400; i++ {
		blocks = append(blocks, Block{Type: "paragraph", Text: strings.Repeat("x", 300)})
	}
	if text := RenderText(blocks); len([]rune(text)) > maxReplyChars {
		t.Fatalf("rendered text is %d runes, over the %d limit", len([]rune(text)), maxReplyChars)
	}
}

func TestParseReplyStripsUnsupportedEmphasis(t *testing.T) {
	facts := sampleFacts()
	blocks := ParseReply("The server's next card is **Freedom Unlimited** and *not* a guess.\n* star bullet\n- dash bullet", facts)
	for _, block := range blocks {
		for _, text := range append([]string{block.Text}, block.Items...) {
			if strings.Contains(text, "*") {
				t.Fatalf("an asterisk reached the reader: %+v", blocks)
			}
		}
	}
	if len(blocks) != 2 || blocks[1].Type != "bullets" || len(blocks[1].Items) != 2 {
		t.Fatalf("a star bullet must still read as a bullet: %+v", blocks)
	}
}

func TestParseReplyDropsInternalLabels(t *testing.T) {
	blocks := ParseReply("I checked FACTS_JSON for that. Your next card is Freedom Unlimited.\n- The next_card field says so.\n- It has no annual fee.\nThe JSON shows your score.", sampleFacts())
	text := RenderText(blocks)
	for _, leak := range []string{"FACTS_JSON", "next_card", "JSON"} {
		if strings.Contains(text, leak) {
			t.Fatalf("%q leaked: %s", leak, text)
		}
	}
	if !strings.Contains(text, "Your next card is Freedom Unlimited.") || !strings.Contains(text, "It has no annual fee.") {
		t.Fatalf("clean sentences were lost: %s", text)
	}
}

func TestRecommendationChartComparesRankedOptions(t *testing.T) {
	facts := sampleFacts()
	facts.Ranking = []rankedFacts{
		{Rank: 1, Card: "Strata", OngoingUSD: 148.8},
		{Rank: 2, Card: "Double Cash", OngoingUSD: 114},
		{Rank: 3, Card: "SavorOne", OngoingUSD: 0},
	}
	blocks := ParseReply("[[chart:recommendation_value]]", facts)
	if len(blocks) != 1 || blocks[0].Chart == nil {
		t.Fatalf("chart missing: %+v", blocks)
	}
	bars := blocks[0].Chart.Bars
	if len(bars) != 2 || bars[0].Label != "Strata" || bars[0].Caption != "recommended next" || bars[1].Value != 114 {
		t.Fatalf("bars = %+v", bars)
	}
}
