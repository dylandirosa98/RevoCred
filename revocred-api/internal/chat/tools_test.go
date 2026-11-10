package chat

import (
	"context"
	"errors"
	"fmt"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

type recordingSearch struct {
	calls int
	err   error
}

func (c *recordingSearch) Search(context.Context, string) (string, error) {
	c.calls++
	return "", c.err
}
func (c *recordingSearch) Get(context.Context, string) (string, error) { c.calls++; return "", c.err }
func searchCall(name, query string) toolCall {
	var c toolCall
	c.ID = "t"
	c.Type = "function"
	c.Function.Name = name
	c.Function.Arguments = query
	return c
}
func TestToolPrivacy(t *testing.T) {
	facts := snapshot{Member: memberFacts{FirstName: "Alexandra"}, MonthlySpend: map[string]int64{"food": 123456}}
	for _, query := range []string{`{"query":"Alexandra Venture X"}`, `{"query":"email alex@example.com Venture X"}`, `{"query":"card 4111 1111 1111 1111"}`, `{"query":"SSN 123-45-6789"}`, `{"query":"account 4f82a627-73be-4b34-b7ae-111111111111"}`, `{"query":"Venture X $1234 spending"}`, `{"query":"https://example.com/?token=secret"}`} {
		c := &recordingSearch{}
		got := runWebTool(context.Background(), searchCall("web_search", query), c, facts)
		if c.calls != 0 || !strings.Contains(got, "error") {
			t.Errorf("query leaked %s: %s calls %d", query, got, c.calls)
		}
	}
}
func TestSearchFailureIsToolResult(t *testing.T) {
	c := &recordingSearch{err: errors.New("offline")}
	got := runWebTool(context.Background(), searchCall("web_search", `{"query":"Unfamiliar card benefits"}`), c, snapshot{})
	if c.calls != 1 || !strings.Contains(got, "unavailable") {
		t.Fatal(got, c.calls)
	}
}
func TestPublicURLValidation(t *testing.T) {
	for _, u := range []string{"http://example.com", "https://localhost/x", "https://127.0.0.1", "https://[::1]", "https://user:pass@example.com", "https://example.com:444", "https://example.com/?token=secret", "https://169.254.169.254/latest"} {
		if _, err := publicURL(u); err == nil {
			t.Errorf("accepted %s", u)
		}
	}
	if _, err := publicURL("https://www.capitalone.com/credit-cards/venture-x/"); err != nil {
		t.Fatal(err)
	}
	for _, s := range []string{"127.0.0.1", "10.0.0.1", "169.254.169.254", "::1", "fc00::1", "100.64.0.1", "0.0.0.0", "224.0.0.1"} {
		if publicIP(net.ParseIP(s)) {
			t.Errorf("accepted %s", s)
		}
	}
}
func TestTargetedWebExcerpt(t *testing.T) {
	page := "<html><nav>Navigation menu</nav><p>Welcome.</p><p>Welcome again.</p><p>Still unrelated.</p><p>More unrelated.</p><h2>Cell phone protection</h2><p>The deductible is $50 per claim and two claims are allowed each year.</p></html>"
	if got := targetedWebExcerpt(page, "cell phone protection deductible"); !strings.Contains(got, "$50") {
		t.Fatal(got)
	}
}

func TestPublicPageRedirectAndDialRestrictions(t *testing.T) {
	c := publicHTTPClient()
	defer c.CloseIdleConnections()
	for _, raw := range []string{"http://example.com/", "https://127.0.0.1/", "https://user:secret@example.com/", "https://example.com/?token=secret"} {
		req, _ := http.NewRequest(http.MethodGet, raw, nil)
		if err := c.CheckRedirect(req, nil); err == nil {
			t.Errorf("redirect accepted %s", raw)
		}
	}
	req, _ := http.NewRequest(http.MethodGet, "https://example.com/", nil)
	if c.CheckRedirect(req, make([]*http.Request, 3)) == nil {
		t.Fatal("redirect count not bounded")
	}
	transport := c.Transport.(*http.Transport)
	if transport.Proxy != nil {
		t.Fatal("public reads must not use environment proxies")
	}
	if conn, err := transport.DialContext(context.Background(), "tcp", "127.0.0.1:443"); err == nil {
		conn.Close()
		t.Fatal("dial reached loopback")
	}
}
func TestSearchSourcesKeepTitlesAndMatchingSnippets(t *testing.T) {
	page := `{"web":{"results":[{"url":"https://issuer.example/guide","title":"Issuer <strong>guide</strong>","description":"Deductible is $50."},{"url":"https://news.example/review","title":"Independent review","description":"Separate second result."},{"url":"http://insecure.example/","title":"Plain HTTP","description":"Dropped."},{"url":"https://issuer.example/guide","title":"Duplicate","description":"Dropped."}]}}`
	sources := searchSources(page)
	if len(sources) != 2 || sources[0].Title != "Issuer guide" || !strings.Contains(sources[0].Excerpt, "$50") || sources[1].Excerpt != "Separate second result." {
		t.Fatalf("mismatched source: %+v", sources)
	}
}

func TestSearchSourcesStripTrackingButRejectSemanticQueries(t *testing.T) {
	page := `{"results":[{"url":"https://issuer.example/guide?utm_source=search&msockid=tracking#benefits","title":"Issuer guide","content":"Terms"},{"url":"https://issuer.example/guide","title":"Duplicate"},{"url":"https://issuer.example/account?token=private","title":"Private"},{"url":"https://issuer.example/article?id=123","title":"Semantic query"}]}`
	got := searchSources(page)
	if len(got) != 1 || got[0].SourceURL != "https://issuer.example/guide" {
		t.Fatalf("tracking cleanup weakened query policy or lost issuer page: %+v", got)
	}
}

func TestSearchDisabledWithoutKey(t *testing.T) {
	tools := searchTools(false)
	if len(tools) != 1 || tools[0]["function"].(map[string]any)["name"] != "read_public_page" {
		t.Fatalf("web_search offered without a search key: %+v", tools)
	}
	provider, err := New(Options{APIKey: "test-key"})
	if err != nil {
		t.Fatal(err)
	}
	prompt := provider.(goProvider).systemPrompt(Snapshot(DemoBrowseContext()))
	if strings.Contains(prompt, "use web_search") || strings.Contains(prompt, "needs one search") {
		t.Fatal("prompt promises search although search is disabled")
	}
	if _, err := (httpWebClient{client: http.DefaultClient}).Search(context.Background(), "Venture X"); err == nil {
		t.Fatal("search without a key must fail closed")
	}
}

func TestBraveSearchRequest(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet || r.URL.Query().Get("q") != "Venture X lounge" || r.URL.Query().Get("count") != "5" {
			t.Errorf("unexpected search request: %s %s", r.Method, r.URL)
		}
		if r.Header.Get("X-Subscription-Token") != "brave-test" || r.Header.Get("Accept") != "application/json" {
			t.Error("missing Brave headers")
		}
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `{"web":{"results":[{"url":"https://www.capitalone.com/x","title":"X","description":"Lounge access."}]}}`)
	}))
	defer server.Close()
	client := httpWebClient{client: server.Client(), searchAPIKey: "brave-test", searchBaseURL: server.URL}
	page, err := client.Search(context.Background(), "Venture X lounge")
	if err != nil || len(searchSources(page)) != 1 {
		t.Fatalf("page=%q err=%v", page, err)
	}
}
