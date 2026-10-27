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

// IssuerLookup is a dated, source-linked page read from an issuer. It is never
// treated as a recommendation and expires quickly because card terms change.
type IssuerLookup struct {
	CardName  string    `json:"card_name"`
	SourceURL string    `json:"source_url"`
	CheckedAt time.Time `json:"checked_at"`
	Excerpt   string    `json:"excerpt"`
	Status    string    `json:"status"`
}

type issuerPageClient interface {
	Get(ctx context.Context, pageURL string) (string, error)
}

type httpIssuerClient struct{ client *http.Client }

func (c httpIssuerClient) Get(ctx context.Context, pageURL string) (string, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, pageURL, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("Accept", "text/html")
	req.Header.Set("User-Agent", userAgent)
	resp, err := c.client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return "", fmt.Errorf("issuer page returned %d", resp.StatusCode)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	return string(body), err
}

// LookupCurrentIssuerTerms reads only the saved official source URL for a card
// named in the question. It does not search the web or invent a source.
func LookupCurrentIssuerTerms(ctx context.Context, prompt string, facts snapshot, client issuerPageClient) *IssuerLookup {
	card, source := issuerSourceForPrompt(prompt, facts)
	if card == "" || source == "" || client == nil {
		return nil
	}
	page, err := client.Get(ctx, source)
	result := &IssuerLookup{CardName: card, SourceURL: source, CheckedAt: time.Now().UTC()}
	if err != nil {
		result.Status = "unavailable"
		result.Excerpt = "The official issuer page could not be read right now."
		return result
	}
	result.Status = "read"
	result.Excerpt = excerptRelevantTerms(page)
	return result
}

func issuerSourceForPrompt(prompt string, facts snapshot) (string, string) {
	normalized := strings.ToLower(prompt)
	for _, card := range facts.IssuerSources {
		if card.Name != "" && card.SourceURL != "" && strings.Contains(normalized, strings.ToLower(card.Name)) {
			return card.Name, card.SourceURL
		}
	}
	return "", ""
}

var tagPattern = regexp.MustCompile(`(?is)<(script|style|noscript|svg).*?</(script|style|noscript|svg)>|<[^>]+>`)
var spacePattern = regexp.MustCompile(`\s+`)

func excerptRelevantTerms(page string) string {
	text := tagPattern.ReplaceAllString(page, " ")
	text = strings.TrimSpace(spacePattern.ReplaceAllString(text, " "))
	parts := strings.Split(text, ".")
	kept := []string{}
	for _, part := range parts {
		line := strings.TrimSpace(part)
		lower := strings.ToLower(line)
		if len(line) < 12 || len(line) > 180 {
			continue
		}
		if strings.Contains(lower, "annual fee") || strings.Contains(lower, "earn") || strings.Contains(lower, "cash back") || strings.Contains(lower, "points") {
			kept = append(kept, line)
		}
		if len(kept) == 3 {
			break
		}
	}
	if len(kept) == 0 {
		return "The official page was read, but no clear fee or rewards sentence could be extracted."
	}
	return strings.Join(kept, ". ") + "."
}

func safeIssuerURL(raw string) bool {
	parsed, err := url.Parse(raw)
	return err == nil && parsed.Scheme == "https" && parsed.Host != ""
}
