package chat

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestWalletExplanationDoesNotEagerlySearch(t *testing.T) {
	calls := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		fmt.Fprint(w, `{"choices":[{"message":{"content":"Your wallet score reflects category coverage and overlapping rewards."}}]}`)
	}))
	defer server.Close()
	client := &http.Client{Transport: toolTransport(func(r *http.Request) (*http.Response, error) {
		if r.URL.Host != strings.TrimPrefix(server.URL, "http://") {
			t.Fatalf("unexpected search for wallet question: %s", r.URL)
		}
		return http.DefaultTransport.RoundTrip(r)
	})}
	p, _ := New(Options{APIKey: "test-key", BaseURL: server.URL, Client: client})
	reply, err := p.Reply(context.Background(), "Explain my wallet score", DemoBrowseContext())
	if err != nil || calls != 1 || !strings.Contains(reply.Text, "category coverage") {
		t.Fatal(reply, err, calls)
	}
}

func TestToolLoopReportsSearchOutageToModel(t *testing.T) {
	calls := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		if calls == 1 {
			fmt.Fprint(w, `{"choices":[{"message":{"tool_calls":[{"id":"s","type":"function","function":{"name":"web_search","arguments":"{\"query\":\"Orbit card current benefits\"}"}}]}}]}`)
			return
		}
		body, _ := io.ReadAll(r.Body)
		if !strings.Contains(string(body), "Web search unavailable") {
			t.Errorf("outage not sent to model: %s", body)
		}
		fmt.Fprint(w, `{"choices":[{"message":{"content":"Search is unavailable, so I could not verify the current Orbit card terms."}}]}`)
	}))
	defer server.Close()
	client := &http.Client{Transport: toolTransport(func(r *http.Request) (*http.Response, error) {
		if r.URL.Host == "html.duckduckgo.com" {
			return &http.Response{StatusCode: 503, Body: http.NoBody, Header: make(http.Header)}, nil
		}
		return http.DefaultTransport.RoundTrip(r)
	})}
	p, _ := New(Options{APIKey: "test-key", BaseURL: server.URL, Client: client})
	reply, err := p.Reply(context.Background(), "Orbit card benefits?", Context{})
	if err != nil || calls != 2 || !strings.Contains(reply.Text, "could not verify") {
		t.Fatal(reply, err, calls)
	}
}

func TestRawProviderToolProtocolIsRepairedNotDisplayed(t *testing.T) {
	calls := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		if calls == 1 {
			fmt.Fprint(w, `{"choices":[{"message":{"content":"<｜DSML｜function_calls><｜DSML｜invoke name=web_search>Venture X</｜DSML｜invoke></｜DSML｜function_calls>"}}]}`)
			return
		}
		body, _ := io.ReadAll(r.Body)
		if !strings.Contains(string(body), "structured tool_calls") {
			t.Errorf("missing protocol repair instruction: %s", body)
		}
		fmt.Fprint(w, `{"choices":[{"message":{"content":"I could not complete the current terms lookup."}}]}`)
	}))
	defer server.Close()
	p, _ := New(Options{APIKey: "test-key", BaseURL: server.URL})
	reply, err := p.Reply(context.Background(), "Venture X protection?", Context{})
	if err != nil || calls != 2 || strings.Contains(reply.Text, "DSML") {
		t.Fatal(reply, err, calls)
	}
}

func TestToolBudgetReturnsEvidenceInsteadOfDiscardingAnswer(t *testing.T) {
	calls, searches := 0, 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		if calls <= 3 {
			fmt.Fprint(w, `{"choices":[{"message":{"tool_calls":[{"id":"a","type":"function","function":{"name":"web_search","arguments":"{\"query\":\"Orbit card benefits\"}"}},{"id":"b","type":"function","function":{"name":"web_search","arguments":"{\"query\":\"Orbit card deductible\"}"}},{"id":"c","type":"function","function":{"name":"web_search","arguments":"{\"query\":\"Orbit card coverage\"}"}}]}}]}`)
			return
		}
		body, _ := io.ReadAll(r.Body)
		if !strings.Contains(string(body), "research budget") {
			t.Errorf("no tool budget notification: %s", body)
		}
		fmt.Fprint(w, `{"choices":[{"message":{"content":"The source says $50. https://orbit.example/guide"}}]}`)
	}))
	defer server.Close()
	client := &http.Client{Transport: toolTransport(func(r *http.Request) (*http.Response, error) {
		if r.URL.Host == "html.duckduckgo.com" {
			searches++
			return &http.Response{StatusCode: 200, Body: ioBody(`<a class="result__a" href="https://orbit.example/guide">Guide</a><a class="result__snippet">Deductible $50.</a>`), Header: make(http.Header)}, nil
		}
		return http.DefaultTransport.RoundTrip(r)
	})}
	p, _ := New(Options{APIKey: "test-key", BaseURL: server.URL, Client: client})
	reply, err := p.Reply(context.Background(), "Orbit card protection", Context{})
	if err != nil || calls != 4 || searches != 6 || !strings.Contains(reply.Text, "$50") {
		t.Fatal(reply, err, calls, searches)
	}
}
