package chat

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"time"
)

// WebSource is a dated, explicitly unverified page read. It is reference
// material for one answer, never a catalog term and never a scoring input.
type WebSource struct {
	Title     string    `json:"title"`
	SourceURL string    `json:"source_url"`
	CheckedAt time.Time `json:"checked_at"`
	Excerpt   string    `json:"excerpt"`
	Verified  bool      `json:"verified"`
}

// WebLookup is the bounded web fallback for one question. Nil means the saved
// plan already answers, the question names no known card, or lookup failed.
type WebLookup struct {
	Query   string      `json:"query"`
	Sources []WebSource `json:"sources"`
}

type webSearchClient interface {
	Search(ctx context.Context, query string) (string, error)
	Get(ctx context.Context, pageURL string) (string, error)
}

type httpWebClient struct{ client *http.Client }

func (c httpWebClient) Search(ctx context.Context, query string) (string, error) {
	form := url.Values{"q": {query}}.Encode()
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, "https://html.duckduckgo.com/html/", strings.NewReader(form))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("User-Agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36")
	req.Header.Set("Accept", "text/html")
	searchClient := *c.client
	searchClient.CheckRedirect = func(r *http.Request, via []*http.Request) error {
		if len(via) >= 3 || r.URL.Scheme != "https" || r.URL.Host != "html.duckduckgo.com" {
			return fmt.Errorf("search redirect blocked")
		}
		return nil
	}
	resp, err := searchClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return "", fmt.Errorf("search returned %d", resp.StatusCode)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	return string(body), err
}

func (c httpWebClient) Get(ctx context.Context, pageURL string) (string, error) {
	return fetchPublicPage(ctx, pageURL)
}

var resultLinkPattern = regexp.MustCompile(`uddg=([^"&]+)`)
var resultAnchorPattern = regexp.MustCompile(`<a[^>]*class="result__a"[^>]*>`)
var anchorHrefPattern = regexp.MustCompile(`href="([^"]+)"`)

// candidateResultLinks understands both DuckDuckGo link shapes: redirect
// links carrying uddg= and plain result anchors linking out directly.
func candidateResultLinks(html string) []string {
	out := []string{}
	for _, match := range resultLinkPattern.FindAllStringSubmatch(html, -1) {
		if raw, err := url.QueryUnescape(match[1]); err == nil {
			out = append(out, raw)
		}
	}
	for _, anchor := range resultAnchorPattern.FindAllString(html, -1) {
		if match := anchorHrefPattern.FindStringSubmatch(anchor); match != nil {
			out = append(out, match[1])
		}
	}
	return out
}

var webStopwords = map[string]bool{
	"what": true, "which": true, "does": true, "do": true, "the": true, "card": true,
	"provide": true, "provides": true, "explain": true, "tell": true, "about": true,
	"your": true, "with": true, "have": true, "this": true, "that": true, "from": true,
}

// snapshotHaystack gathers what the saved plan already says about one card.
func snapshotHaystack(facts snapshot, cardName string) string {
	var b strings.Builder
	lower := strings.ToLower(cardName)
	write := func(values ...string) {
		for _, v := range values {
			b.WriteString(strings.ToLower(v))
			b.WriteString(" ")
		}
	}
	for _, entry := range facts.Wallet {
		name, _ := entry["name"].(string)
		if !strings.Contains(strings.ToLower(name), lower) && !strings.Contains(lower, strings.ToLower(name)) {
			continue
		}
		write(name)
		for _, key := range []string{"best_use", "summary", "transferable_points"} {
			if v, ok := entry[key]; ok {
				write(fmt.Sprint(v))
			}
		}
		if fee, ok := entry["annual_fee_usd"]; ok {
			write(fmt.Sprintf("annual fee %v", fee))
		}
		if rates, ok := entry["reward_rates"].(map[string]float64); ok {
			for category := range rates {
				write(category)
			}
		}
		writeList := func(key string) {
			switch items := entry[key].(type) {
			case []string:
				write(items...)
			case []any:
				for _, item := range items {
					write(fmt.Sprint(item))
				}
			}
		}
		writeList("benefits")
		if community, ok := entry["community_product_data"].(map[string]any); ok {
			if rules, ok := community["earning_rules"].([]string); ok {
				write(rules...)
			}
			if benefits, ok := community["benefits"].([]string); ok {
				write(benefits...)
			}
		}
	}
	for _, entry := range facts.Catalog {
		name, _ := entry["name"].(string)
		if !strings.Contains(strings.ToLower(name), lower) && !strings.Contains(lower, strings.ToLower(name)) {
			continue
		}
		write(name)
		if benefits, ok := entry["benefits"].([]string); ok {
			write(benefits...)
		}
	}
	return b.String()
}

func promptContentWords(prompt string) []string {
	words := strings.Fields(strings.ToLower(prompt))
	seen := map[string]bool{}
	out := []string{}
	for _, word := range words {
		word = strings.Trim(word, ".,?!;:\"'()")
		if len(word) < 4 || webStopwords[word] || seen[word] {
			continue
		}
		seen[word] = true
		out = append(out, word)
	}
	return out
}

func registrableDomain(host string) string {
	host = strings.ToLower(strings.TrimSuffix(host, "."))
	parts := strings.Split(host, ".")
	if len(parts) >= 2 {
		return strings.Join(parts[len(parts)-2:], ".")
	}
	return host
}

var benefitSentencePattern = regexp.MustCompile(`(?i)protect|insur|cover|benefit|credit|perk|lounge|warranty|phone|travel|fee|enroll|statement|reimburs|claim|damage|theft|assist|concierge`)

// excerptBenefitTerms keeps sentences likely to describe a benefit or
// protection, unlike the fee-only issuer excerpt.
func excerptBenefitTerms(page string) string {
	text := tagPattern.ReplaceAllString(page, " ")
	text = strings.TrimSpace(spacePattern.ReplaceAllString(text, " "))
	kept := []string{}
	for _, part := range strings.Split(text, ".") {
		line := strings.TrimSpace(part)
		if len(line) < 12 || len(line) > 280 {
			continue
		}
		if benefitSentencePattern.MatchString(line) {
			kept = append(kept, line)
		}
		if len(kept) == 4 {
			break
		}
	}
	if len(kept) == 0 {
		return ""
	}
	out := strings.Join(kept, ". ") + "."
	if len(out) > 1200 {
		return out[:1200]
	}
	return out
}

// LookupWebTerms is the bounded web fallback. It only runs for a known card
// whose saved plan lacks the asked detail, fetches at most three pages on the
// card's own official issuer domain, and labels everything unverified.
// Anything else returns nil with no error: snapshot-only stays the default.
func LookupWebTerms(ctx context.Context, prompt string, facts snapshot, client webSearchClient) *WebLookup {
	card, source := issuerSourceForPrompt(prompt, facts)
	if card == "" || source == "" || client == nil {
		return nil
	}
	sourceURL, err := url.Parse(source)
	if err != nil || sourceURL.Scheme != "https" || sourceURL.Host == "" {
		return nil
	}
	haystack := snapshotHaystack(facts, card)
	nameWords := map[string]bool{}
	for _, word := range strings.Fields(strings.ToLower(card)) {
		if len(word) >= 4 {
			nameWords[word] = true
		}
	}
	for _, word := range promptContentWords(prompt) {
		if nameWords[word] {
			continue
		}
		if strings.Contains(haystack, word) {
			return nil
		}
	}
	query := card + ": " + strings.TrimSpace(prompt)
	if len(query) > 200 {
		query = query[:200]
	}
	html, err := client.Search(ctx, query)
	if err != nil {
		return nil
	}
	want := registrableDomain(sourceURL.Hostname())
	seen := map[string]bool{}
	targets := []string{}
	for _, raw := range candidateResultLinks(html) {
		page, err := url.Parse(raw)
		if err != nil || page.Scheme != "https" || page.Host == "" || seen[raw] {
			continue
		}
		if registrableDomain(page.Hostname()) != want {
			continue
		}
		seen[raw] = true
		targets = append(targets, raw)
		if len(targets) == 3 {
			break
		}
	}
	if len(targets) == 0 {
		return nil
	}
	lookup := &WebLookup{Query: query}
	for _, target := range targets {
		page, err := client.Get(ctx, target)
		if err != nil {
			continue
		}
		excerpt := excerptBenefitTerms(page)
		if excerpt == "" {
			continue
		}
		lookup.Sources = append(lookup.Sources, WebSource{
			Title: card + " page read", SourceURL: target,
			CheckedAt: time.Now().UTC(), Excerpt: excerpt, Verified: false,
		})
	}
	if len(lookup.Sources) == 0 {
		return nil
	}
	return lookup
}
