package chat

import (
	"fmt"
	"regexp"
	"sort"
	"strings"
)

// REVO replies are a small, fixed vocabulary rather than free prose. The model
// chooses the shape of the answer; every number in it comes from the server
// snapshot, so a chart can never contain a value the model remembered or made up.

type Block struct {
	Type  string   `json:"type"` // heading, paragraph, bullets, chart, note
	Text  string   `json:"text,omitempty"`
	Items []string `json:"items,omitempty"`
	Chart *Chart   `json:"chart,omitempty"`
}

type Chart struct {
	Title string `json:"title"`
	Unit  string `json:"unit"` // usd or percent
	Note  string `json:"note,omitempty"`
	Bars  []Bar  `json:"bars"`
}

type Bar struct {
	Label      string  `json:"label"`
	Value      float64 `json:"value"`
	ValueLabel string  `json:"value_label,omitempty"`
	Caption    string  `json:"caption,omitempty"`
}

// Reply is what a provider returns: display blocks plus the plain text kept for
// storage, export and any text-only consumer.
type Reply struct {
	Text   string  `json:"text"`
	Blocks []Block `json:"blocks"`
}

const maxReplyChars = 4000

// chartNames is the only set of charts REVO may reference.
var chartNames = map[string]bool{
	"spend_by_category":    true,
	"wallet_rates":         true,
	"recommendation_value": true,
}

// ParseReply turns a model reply into blocks, resolving every chart reference
// against the snapshot. Unresolvable references are dropped rather than shown,
// and stray numeric chart syntax never reaches the user.
func ParseReply(markdown string, facts snapshot) []Block {
	blocks := []Block{}
	lines := strings.Split(strings.ReplaceAll(markdown, "\r\n", "\n"), "\n")
	var bullets []string
	flushBullets := func() {
		if len(bullets) > 0 {
			blocks = append(blocks, Block{Type: "bullets", Items: bullets})
			bullets = nil
		}
	}
	for _, raw := range lines {
		line := strings.TrimSpace(raw)
		switch {
		case line == "":
			flushBullets()
		case strings.HasPrefix(line, "### "):
			flushBullets()
			if text := clip(strings.TrimPrefix(line, "### "), 120); text != "" {
				blocks = append(blocks, Block{Type: "heading", Text: text})
			}
		case strings.HasPrefix(line, "#### "):
			flushBullets()
			if text := clip(strings.TrimPrefix(line, "#### "), 200); text != "" {
				blocks = append(blocks, Block{Type: "note", Text: text})
			}
		case strings.HasPrefix(line, "- "), strings.HasPrefix(line, "* "):
			if item := clip(stripCharts(line[2:]), 360); item != "" {
				bullets = append(bullets, item)
			}
		case strings.HasPrefix(line, "[[chart:"):
			flushBullets()
			if chart, ok := buildChart(strings.TrimSpace(line), facts); ok {
				blocks = append(blocks, Block{Type: "chart", Chart: &chart})
			}
		default:
			flushBullets()
			if text := clip(stripCharts(line), 1400); text != "" {
				blocks = append(blocks, Block{Type: "paragraph", Text: text})
			}
		}
	}
	flushBullets()
	// A final URL or markdown citation need not end in punctuation.
	if len(blocks) == 0 {
		return fallbackBlocks(facts)
	}
	return blocks
}

// A provider can occasionally stop after returning valid JSON but before it
// finishes its final prose sentence. Do not show that broken fragment. This is
// intentionally limited to a trailing paragraph because headings, bullets and
// notes commonly omit terminal punctuation by design.
func dropIncompleteEnding(blocks []Block) []Block {
	if len(blocks) == 0 || blocks[len(blocks)-1].Type != "paragraph" {
		return blocks
	}
	text := strings.TrimSpace(blocks[len(blocks)-1].Text)
	if text == "" {
		return blocks[:len(blocks)-1]
	}
	for _, ending := range []string{".", "!", "?", "…", ".\"", "!\"", "?\""} {
		if strings.HasSuffix(text, ending) {
			return blocks
		}
	}
	return blocks[:len(blocks)-1]
}

// stripEmphasis removes markdown emphasis the format does not use. REVO is told
// never to write an asterisk, so any that slips through is dropped rather than
// shown to the reader as a literal character.
func stripEmphasis(value string) string {
	value = strings.ReplaceAll(value, "*", "")
	return strings.ReplaceAll(value, "__", "")
}

// leakPattern matches wording that exposes how REVO works rather than the
// member's plan: data labels such as FACTS_JSON or snake_case field names, and
// talk about JSON, prompts or instructions.
var leakPattern = regexp.MustCompile(`(?i)\bjson\b|\bsystem prompt\b|\bmy instructions\b|\bmember information\b|\b[a-z0-9]+(?:_[a-z0-9]+)+\b`)

// dropLeaks removes any sentence that matches leakPattern and keeps the rest.
func dropLeaks(value string) string {
	if !leakPattern.MatchString(value) {
		return value
	}
	kept := []string{}
	start := 0
	for i, r := range value {
		if r == '.' || r == '!' || r == '?' {
			if i+1 == len(value) || value[i+1] == ' ' {
				if sentence := strings.TrimSpace(value[start : i+1]); !leakPattern.MatchString(sentence) {
					kept = append(kept, sentence)
				}
				start = i + 1
			}
		}
	}
	if tail := strings.TrimSpace(value[start:]); tail != "" && !leakPattern.MatchString(tail) {
		kept = append(kept, tail)
	}
	return strings.Join(kept, " ")
}

func clip(value string, limit int) string {
	// Preserve source URLs verbatim, including underscores and markdown links.
	urls := []string{}
	value = regexp.MustCompile(`https?://[^\s<>]+`).ReplaceAllStringFunc(value, func(u string) string {
		urls = append(urls, u)
		return fmt.Sprintf("REVOSOURCE%dTOKEN", len(urls)-1)
	})
	value = strings.TrimSpace(dropLeaks(stripEmphasis(value)))
	for i, u := range urls {
		value = strings.ReplaceAll(value, fmt.Sprintf("REVOSOURCE%dTOKEN", i), u)
	}
	if len([]rune(value)) <= limit {
		return value
	}
	return strings.TrimSpace(string([]rune(value)[:limit])) + "…"
}

// stripCharts removes any chart reference from prose so the raw marker is never
// shown to a person.
func stripCharts(text string) string {
	for {
		start := strings.Index(text, "[[chart:")
		if start < 0 {
			return strings.TrimSpace(text)
		}
		end := strings.Index(text[start:], "]]")
		if end < 0 {
			return strings.TrimSpace(text[:start])
		}
		text = text[:start] + text[start+end+2:]
	}
}

func buildChart(line string, facts snapshot) (Chart, bool) {
	name := strings.TrimSuffix(strings.TrimPrefix(line, "[[chart:"), "]]")
	// A marker may carry a caption after a pipe: [[chart:id|Title]]
	title := ""
	if parts := strings.SplitN(name, "|", 2); len(parts) == 2 {
		name, title = strings.TrimSpace(parts[0]), clip(parts[1], 80)
	}
	if !chartNames[name] {
		return Chart{}, false
	}
	switch name {
	case "spend_by_category":
		return spendChart(facts, title)
	case "wallet_rates":
		return rateChart(facts, title)
	case "recommendation_value":
		return recommendationChart(facts, title)
	}
	return Chart{}, false
}

func spendChart(facts snapshot, title string) (Chart, bool) {
	if len(facts.MonthlySpend) == 0 {
		return Chart{}, false
	}
	chart := Chart{Title: firstNonEmpty(title, "Your monthly spending"), Unit: "usd",
		Note: "What you entered in the questionnaire. Housing is excluded from reward estimates."}
	for category, cents := range facts.MonthlySpend {
		if cents <= 0 {
			continue
		}
		chart.Bars = append(chart.Bars, Bar{
			Label:   titleCase(category),
			Value:   float64(cents) / 100,
			Caption: fmt.Sprintf("$%.0f/mo", float64(cents)/100),
		})
	}
	if len(chart.Bars) == 0 {
		return Chart{}, false
	}
	sort.Slice(chart.Bars, func(i, j int) bool { return chart.Bars[i].Value > chart.Bars[j].Value })
	return capBars(chart), true
}

func rateChart(facts snapshot, title string) (Chart, bool) {
	categories := []string{"dining", "groceries", "gas", "travel", "flights", "hotels"}
	chart := Chart{Title: firstNonEmpty(title, "Best modeled earn rate in your wallet"), Unit: "percent",
		Note: "One cent per point, excluding bonuses, credits and conditional uplift. This chart shows earning rates, not the Home ongoing wallet total. Verify current issuer terms."}
	for _, category := range categories {
		best, name, valueLabel := 0.0, "", ""
		for _, card := range facts.Wallet {
			rates, _ := card["reward_rates"].(map[string]float64)
			if rate := rateFor(rates, category); rate > best {
				best, name = rate, fmt.Sprint(card["name"])
				unit := "% cash back"
				if transferable, _ := card["transferable_points"].(bool); transferable {
					unit = "points per dollar"
				}
				valueLabel = formatRate(rate, unit)
			}
		}
		if best > 0 {
			chart.Bars = append(chart.Bars, Bar{
				Label:      titleCase(category),
				Value:      best,
				ValueLabel: valueLabel,
				Caption:    name,
			})
		}
	}
	if len(chart.Bars) == 0 {
		return Chart{}, false
	}
	return chart, true
}

// recommendationChart compares the ranked options by the value each would add
// per year. Every bar is the same quantity, so the chart can be read as a
// comparison; the whole wallet's value is a different measure and is left out.
func recommendationChart(facts snapshot, title string) (Chart, bool) {
	chart := Chart{Title: firstNonEmpty(title, "What each option adds per year"), Unit: "usd",
		Note: "Modeled additional wallet value after each card's annual fee, from the RevoCred ranking."}
	for _, option := range facts.Ranking {
		if option.OngoingUSD <= 0 {
			continue
		}
		caption := "per year"
		if option.Rank == 1 {
			caption = "recommended next"
		}
		chart.Bars = append(chart.Bars, Bar{Label: option.Card, Value: option.OngoingUSD, Caption: caption})
		if len(chart.Bars) == 5 {
			break
		}
	}
	if len(chart.Bars) == 0 && facts.NextCard != "" && facts.NextCardValueCents > 0 {
		chart.Bars = append(chart.Bars, Bar{Label: facts.NextCard, Value: float64(facts.NextCardValueCents) / 100, Caption: "recommended next"})
	}
	if len(chart.Bars) == 0 {
		return Chart{}, false
	}
	return chart, true
}

func capBars(chart Chart) Chart {
	if len(chart.Bars) <= 8 {
		return chart
	}
	chart.Bars = chart.Bars[:8]
	return chart
}

func rateFor(rates map[string]float64, category string) float64 {
	if rate, ok := rates[category]; ok && rate > 0 {
		return rate
	}
	if rate, ok := rates["other"]; ok && rate > 0 {
		return rate
	}
	return 0
}

func titleCase(value string) string {
	replaced := strings.ReplaceAll(strings.ReplaceAll(value, "_", " "), "-", " ")
	if replaced == "" {
		return ""
	}
	return strings.ToUpper(replaced[:1]) + replaced[1:]
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return value
		}
	}
	return ""
}

// RenderText flattens blocks to the plain text kept alongside them.
func RenderText(blocks []Block) string {
	parts := make([]string, 0, len(blocks))
	for _, block := range blocks {
		switch block.Type {
		case "heading", "note":
			if block.Text != "" {
				parts = append(parts, block.Text)
			}
		case "paragraph":
			if block.Text != "" {
				parts = append(parts, block.Text)
			}
		case "bullets":
			for _, item := range block.Items {
				parts = append(parts, "- "+item)
			}
		case "chart":
			if block.Chart != nil {
				parts = append(parts, block.Chart.Title)
			}
		}
	}
	text := strings.Join(parts, "\n")
	if len([]rune(text)) > maxReplyChars {
		text = strings.TrimSpace(string([]rune(text)[:maxReplyChars]))
	}
	if text == "" {
		text = "I could not summarise that. Try asking about your next card, a spending category, or your wallet score."
	}
	return text
}

// fallbackBlocks keeps the no-AI path looking the same as the AI path.
func fallbackBlocks(facts snapshot) []Block {
	return []Block{{Type: "paragraph", Text: facts.Disclaimer}}
}
