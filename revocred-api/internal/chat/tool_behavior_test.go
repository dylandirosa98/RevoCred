package chat

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestTransientModelConnectionFailureRetriesOnce(t *testing.T) {
	for _, failures := range []int{1, 2} {
		t.Run(fmt.Sprintf("failures=%d", failures), func(t *testing.T) {
			calls := 0
			client := &http.Client{Transport: toolTransport(func(r *http.Request) (*http.Response, error) {
				calls++
				body, _ := io.ReadAll(r.Body)
				if !strings.Contains(string(body), "What is APR?") || r.Header.Get("Authorization") != "Bearer model-test" {
					t.Error("retry lost the question or authorization")
				}
				if calls <= failures {
					return nil, errors.New("transient TLS connection failure")
				}
				return braveResponse(`{"choices":[{"message":{"content":"APR is the annualized interest rate on borrowing."}}]}`), nil
			})}
			provider, err := New(Options{APIKey: "model-test", BaseURL: "https://model.example/v1", Client: client})
			if err != nil {
				t.Fatal(err)
			}
			reply, err := provider.Reply(context.Background(), "What is APR?", Context{})
			if err != nil || calls != 2 {
				t.Fatalf("calls=%d error=%v", calls, err)
			}
			if failures == 1 && (reply.Basic || !strings.Contains(reply.Text, "APR")) {
				t.Fatal("recovered completion was discarded", reply)
			}
			if failures == 2 && (!reply.Basic || !strings.Contains(reply.Text, "unavailable")) {
				t.Fatal("repeated failure must fall back", reply)
			}
		})
	}
}

func TestEmptyResearchAnswerGetsOneFinalAnswerAttempt(t *testing.T) {
	calls := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		body, _ := io.ReadAll(r.Body)
		if calls == 1 {
			fmt.Fprint(w, `{"choices":[{"message":{"tool_calls":[{"id":"s","type":"function","function":{"name":"web_search","arguments":"{\"query\":\"Orbit card benefits\"}"}}]}}]}`)
		} else if calls == 2 {
			fmt.Fprint(w, `{"choices":[{"finish_reason":"stop","message":{"content":""}}]}`)
		} else {
			if !strings.Contains(string(body), `"tool_choice":"none"`) || !strings.Contains(string(body), "https://issuer.example/guide") {
				t.Error("final answer attempt lost research or allowed more tools")
			}
			fmt.Fprint(w, `{"choices":[{"message":{"content":"The source describes coverage. https://issuer.example/guide"}}]}`)
		}
	}))
	defer server.Close()
	client := &http.Client{Transport: toolTransport(func(r *http.Request) (*http.Response, error) {
		if r.URL.Host == "api.search.brave.com" {
			return braveResponse(`{"web":{"results":[{"url":"https://issuer.example/guide","title":"Guide","description":"Coverage terms."}]}}`), nil
		}
		return http.DefaultTransport.RoundTrip(r)
	})}
	p, _ := New(Options{APIKey: "test", SearchAPIKey: "test-search", BaseURL: server.URL, Client: client})
	reply, err := p.Reply(context.Background(), "Orbit card benefits?", Context{})
	if err != nil || reply.Basic || calls != 3 || !strings.Contains(reply.Text, "issuer.example") {
		t.Fatalf("calls=%d reply=%+v error=%v", calls, reply, err)
	}
}

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
	p, _ := New(Options{APIKey: "test-key", SearchAPIKey: "brave-test", BaseURL: server.URL, Client: client})
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
		if r.URL.Host == "api.search.brave.com" {
			return &http.Response{StatusCode: 503, Body: http.NoBody, Header: make(http.Header)}, nil
		}
		return http.DefaultTransport.RoundTrip(r)
	})}
	p, _ := New(Options{APIKey: "test-key", SearchAPIKey: "brave-test", BaseURL: server.URL, Client: client})
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
		if r.URL.Host == "api.search.brave.com" {
			searches++
			return braveResponse(`{"web":{"results":[{"url":"https://orbit.example/guide","title":"Guide","description":"Deductible $50."}]}}`), nil
		}
		return http.DefaultTransport.RoundTrip(r)
	})}
	p, _ := New(Options{APIKey: "test-key", SearchAPIKey: "brave-test", BaseURL: server.URL, Client: client})
	reply, err := p.Reply(context.Background(), "Orbit card protection", Context{})
	if err != nil || calls != 4 || searches != 6 || !strings.Contains(reply.Text, "$50") {
		t.Fatal(reply, err, calls, searches)
	}
}
