package chat

import (
	"context"
	"strings"
	"testing"
	"time"
)

type fakeWebClient struct {
	searchHTML string
	searchErr  error
	pages      map[string]string
	fetched    []string
}

func (f *fakeWebClient) Search(ctx context.Context, query string) (string, error) {
	if f.searchErr != nil {
		return "", f.searchErr
	}
	return f.searchHTML, nil
}

func (f *fakeWebClient) Get(ctx context.Context, pageURL string) (string, error) {
	f.fetched = append(f.fetched, pageURL)
	if page, ok := f.pages[pageURL]; ok {
		return page, nil
	}
	return "", context.DeadlineExceeded
}

func ventureFacts() snapshot {
	return snapshot{
		IssuerSources: []issuerSource{{Name: "Venture X", SourceURL: "https://www.capitalone.com/credit-cards/venture-x/"}},
		Wallet: []map[string]any{{
			"name": "Venture X", "benefits": []string{"$300 Capital One Travel credit"},
			"community_product_data": map[string]any{"benefits": []string{"$300 Capital One Travel credit"}},
		}},
	}
}

func TestWebLookupSkipsWhenSnapshotAlreadyAnswers(t *testing.T) {
	facts := ventureFacts()
	client := &fakeWebClient{}
	got := LookupWebTerms(context.Background(), "What travel credit does Venture X give?", facts, client)
	if got != nil {
		t.Fatal("web search ran although the snapshot already answers")
	}
	if len(client.fetched) != 0 {
		t.Fatal("network fetch ran although the snapshot already answers")
	}
}

func TestWebLookupFetchesOnlyOfficialIssuerPages(t *testing.T) {
	facts := ventureFacts()
	client := &fakeWebClient{
		searchHTML: `<a rel="nofollow" class="result__a" href="https://www.capitalone.com/credit-cards/venture-x/benefits">official</a>` +
			`<a href="/l/?uddg=https%3A%2F%2Fblog.example%2Fventure-x-cell-hacks">blog</a>` +
			`<a rel="nofollow" class="result__a" href="https://www.chase.com/other-card">other issuer</a>`,
		pages: map[string]string{
			"https://www.capitalone.com/credit-cards/venture-x/benefits": "<html><body><p>Cell phone protection reimburses up to $800 per claim when you pay your monthly bill with the card. Enrollment is automatic.</p></body></html>",
		},
	}
	got := LookupWebTerms(context.Background(), "Explain the cell phone protection the Venture X provides", facts, client)
	if got == nil || len(got.Sources) == 0 {
		t.Fatal("official issuer page was not read")
	}
	for _, url := range client.fetched {
		if !strings.HasPrefix(url, "https://www.capitalone.com/") {
			t.Fatalf("non-issuer page fetched: %s", url)
		}
	}
	if got.Sources[0].Verified {
		t.Fatal("web excerpt must be labelled unverified")
	}
	if !strings.Contains(got.Sources[0].Excerpt, "Cell phone protection") {
		t.Fatalf("protection sentence lost: %q", got.Sources[0].Excerpt)
	}
	if got.Sources[0].CheckedAt.IsZero() || got.Sources[0].SourceURL == "" {
		t.Fatal("web source missing URL or read date")
	}
}

func TestWebLookupFailsClosed(t *testing.T) {
	facts := ventureFacts()
	if got := LookupWebTerms(context.Background(), "Explain the cell phone protection the Venture X provides", facts, &fakeWebClient{searchErr: context.DeadlineExceeded}); got != nil {
		t.Fatal("search outage must yield no web sources, not an error page")
	}
	empty := &fakeWebClient{searchHTML: "<html><body>no results</body></html>"}
	if got := LookupWebTerms(context.Background(), "Explain the cell phone protection the Venture X provides", facts, empty); got != nil {
		t.Fatal("empty results must yield no web sources")
	}
	_ = time.Now
}
