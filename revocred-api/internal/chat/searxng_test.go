package chat

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestKeylessResearchUsesSearxngAndReturnsSources(t *testing.T) {
	searches, calls := 0, 0
	search := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		searches++
		if r.URL.Query().Get("q") != "Orbit card deductible" || r.URL.Query().Get("format") != "json" || r.URL.Query().Get("safesearch") != "1" {
			t.Errorf("unexpected keyless query: %s", r.URL)
		}
		if r.Header.Get("Authorization") != "" || r.Header.Get("X-Subscription-Token") != "" || r.Header.Get("X-Opencode-Session") != "" {
			t.Error("AI/search credentials or account identifier reached keyless search")
		}
		fmt.Fprint(w, `{"results":[{"title":"Issuer guide","url":"https://issuer.example/guide","content":"The deductible is $50."},{"title":"Private","url":"https://127.0.0.1/secret","content":"Do not read"}],"unresponsive_engines":[["one engine","CAPTCHA"]]}`)
	}))
	defer search.Close()
	model := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		var body struct {
			Messages []map[string]any `json:"messages"`
			Tools    []map[string]any `json:"tools"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		if calls == 1 {
			if len(body.Tools) != 2 {
				t.Error("keyless model is missing search")
			}
			fmt.Fprint(w, `{"choices":[{"message":{"tool_calls":[{"id":"lookup","type":"function","function":{"name":"web_search","arguments":"{\"query\":\"Orbit card deductible\"}"}}]}}]}`)
			return
		}
		last := fmt.Sprint(body.Messages[len(body.Messages)-1]["content"])
		if !strings.Contains(last, "$50") || !strings.Contains(last, "checked_at") || strings.Contains(last, "127.0.0.1") {
			t.Errorf("source grounding/filtering failed: %s", last)
		}
		fmt.Fprint(w, `{"choices":[{"message":{"content":"The deductible is $50. Source: https://issuer.example/guide"}}]}`)
	}))
	defer model.Close()
	provider, err := New(Options{APIKey: "model-test", BaseURL: model.URL, SearchProvider: "searxng", SearchBaseURL: search.URL + "/search"})
	if err != nil {
		t.Fatal(err)
	}
	reply, err := provider.Reply(context.Background(), "What is the Orbit card deductible?", Context{})
	if err != nil || searches != 1 || calls != 2 || reply.Basic || !strings.Contains(reply.Text, "https://issuer.example/guide") {
		t.Fatalf("searches=%d calls=%d reply=%+v err=%v", searches, calls, reply, err)
	}
}

func TestSearxngConsentChangesWithSearchRecipient(t *testing.T) {
	options := Options{APIKey: "test", BaseURL: defaultGoBaseURL, Model: defaultGoModel}
	without, _ := New(options)
	options.SearchProvider, options.SearchBaseURL = "searxng", "http://search:8080/search"
	with, err := New(options)
	if err != nil {
		t.Fatal(err)
	}
	a, _ := Disclosure(without)
	b, err := Disclosure(with)
	if err != nil || a.Version == b.Version || !strings.Contains(b.SearchProvider, "SearXNG") || !strings.Contains(b.DataUse, "upstream search engines") {
		t.Fatal("keyless search must disclose its recipients and require renewed consent", b, err)
	}
	options.SearchBaseURL = "http://other.railway.internal:8080/search"
	other, _ := New(options)
	c, _ := Disclosure(other)
	if b.Version == c.Version {
		t.Fatal("changed search endpoint reused consent")
	}
}

func TestSearxngRejectsUnsafeServiceConfiguration(t *testing.T) {
	for _, endpoint := range []string{"", "http://public.example/search", "https://user:secret@example.com/search", "https://example.com/search?token=secret", "file:///etc/passwd"} {
		if _, err := New(Options{APIKey: "test", SearchProvider: "searxng", SearchBaseURL: endpoint}); err == nil {
			t.Errorf("accepted invalid endpoint %q", endpoint)
		}
	}
}
