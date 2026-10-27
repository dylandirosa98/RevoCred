package chat

import (
	"context"
	"errors"
	"net"
	"net/http"
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
	page := `<a class="result__a" href="//duckduckgo.com/l/?uddg=https%3A%2F%2Fissuer.example%2Fguide">Issuer guide</a><a class="result__snippet">Deductible is $50.</a><a class="result__a" href="https://news.example/review">Independent review</a><a class="result__snippet">Separate second result.</a>`
	sources := searchSources(page)
	if len(sources) != 2 || sources[0].Title != "Issuer guide" || !strings.Contains(sources[0].Excerpt, "$50") || sources[1].Excerpt != "Separate second result." {
		t.Fatalf("mismatched source: %+v", sources)
	}
}
