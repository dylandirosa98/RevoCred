package chat

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func ioBody(s string) io.ReadCloser { return io.NopCloser(strings.NewReader(s)) }

type toolTransport func(*http.Request) (*http.Response, error)

func (f toolTransport) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }

func TestModelDirectedSearchFollowup(t *testing.T) {
	for _, openAI := range []bool{false, true} {
		t.Run(fmt.Sprintf("openai=%v", openAI), func(t *testing.T) {
			calls, searches := 0, 0
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				calls++
				var body map[string]any
				_ = json.NewDecoder(r.Body).Decode(&body)
				if openAI {
					if body["max_completion_tokens"] == nil || body["max_tokens"] != nil || r.Header.Get("x-opencode-session") != "" {
						t.Error("invalid OpenAI tool request contract")
					}
				} else if body["max_tokens"] == nil {
					t.Error("missing OpenCode token budget")
				}
				if body["tools"] == nil {
					t.Error("model has no search tool")
				}
				if calls == 1 {
					encoded, _ := json.Marshal(body["messages"])
					if !strings.Contains(string(encoded), "Explain Unfamiliar Orbit card protection") || !strings.Contains(string(encoded), "And the deductible?") {
						t.Errorf("follow-up/history missing: %s", encoded)
					}
					fmt.Fprint(w, `{"choices":[{"message":{"role":"assistant","content":null,"tool_calls":[{"id":"search1","type":"function","function":{"name":"web_search","arguments":"{\"query\":\"Unfamiliar Orbit card deductible\"}"}}]}}]}`)
				} else {
					encoded, _ := json.Marshal(body["messages"])
					if !strings.Contains(string(encoded), `search1`) || !strings.Contains(string(encoded), `orbit.example`) {
						t.Errorf("missing tool exchange: %s", encoded)
					}
					fmt.Fprint(w, `{"choices":[{"message":{"content":"The Orbit card deductible is $50. Source: https://orbit.example/guide"}}]}`)
				}
			}))
			defer server.Close()
			client := &http.Client{}
			client.Transport = toolTransport(func(r *http.Request) (*http.Response, error) {
				if r.URL.Host == "html.duckduckgo.com" {
					if r.FormValue("q") != "Unfamiliar Orbit card deductible" {
						t.Errorf("external search got private/non-topic data: %s", r.FormValue("q"))
					}
					searches++
					return &http.Response{StatusCode: 200, Body: ioBody(`<a class="result__a" href="https://orbit.example/guide">Orbit guide</a><a class="result__snippet">Deductible is $50.</a>`), Header: make(http.Header)}, nil
				}
				return http.DefaultTransport.RoundTrip(r)
			})
			provider, _ := New(Options{APIKey: "test-key", BaseURL: server.URL, Client: client})
			p := provider.(goProvider)
			p.openAI = openAI
			reply, err := p.Reply(context.Background(), "And the deductible?", Context{History: []Turn{{Role: "user", Content: "Explain Unfamiliar Orbit card protection"}}})
			if err != nil || calls != 2 || searches != 1 || !strings.Contains(reply.Text, "$50") {
				t.Fatalf("calls=%d searches=%d reply=%+v err=%v", calls, searches, reply, err)
			}
		})
	}
}
