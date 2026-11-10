package chat

import (
	"strings"
	"testing"
)

func TestSharingDisclosureMatchesActualRecipientAndModel(t *testing.T) {
	for _, tc := range []struct{ base, model, recipient string }{
		{"https://api.openai.com/v1", "production-model", "OpenAI"},
		{defaultGoBaseURL, defaultGoModel, "OpenCode Go and DeepSeek (testing)"},
	} {
		provider, err := New(Options{APIKey: "test-only-key", BaseURL: tc.base, Model: tc.model})
		if err != nil {
			t.Fatal(err)
		}
		first, err := Disclosure(provider)
		if err != nil || !first.External || first.Recipient != tc.recipient || first.Model != tc.model || len(first.Version) != 64 {
			t.Fatalf("disclosure = %+v, error = %v", first, err)
		}
		if strings.Contains(first.DataUse, "zero retention") || strings.Contains(first.DataUse, "test-only-key") {
			t.Fatal("disclosure exposed key or promised unsupported retention")
		}
		other, _ := New(Options{APIKey: "another-key", BaseURL: tc.base, Model: tc.model + "-changed"})
		second, err := Disclosure(other)
		if err != nil || first.Version == second.Version {
			t.Fatal("changed model reused disclosure version")
		}
		rotated, _ := New(Options{APIKey: "rotated-key", BaseURL: tc.base, Model: tc.model})
		third, _ := Disclosure(rotated)
		if first.Version != third.Version {
			t.Fatal("credential rotation changed public disclosure")
		}
	}
}

func TestUnidentifiedRecipientCannotBeDisclosedAsOpenAI(t *testing.T) {
	for _, base := range []string{"https://api.openai.com.evil.test/v1", "https://other.example.test/v1"} {
		provider, err := New(Options{APIKey: "test-only-key", BaseURL: base, Model: "test"})
		if err != nil {
			t.Fatal(err)
		}
		if _, err := Disclosure(provider); err == nil {
			t.Fatal("unknown recipient did not fail closed")
		}
	}
	disclosure, err := Disclosure(NewDeterministicProvider())
	if err != nil || disclosure.External {
		t.Fatal("deterministic replies incorrectly require AI sharing")
	}
}

func TestOnlyOpenCodeDisclosesTheSessionIdentifier(t *testing.T) {
	openAI, _ := New(Options{APIKey: "test-only-key", BaseURL: "https://api.openai.com/v1", Model: "production-model"})
	openCode, _ := New(Options{APIKey: "test-only-key", BaseURL: defaultGoBaseURL, Model: defaultGoModel})
	a, _ := Disclosure(openAI)
	o, _ := Disclosure(openCode)
	if strings.Contains(a.DataUse, "OpenCode") || strings.Contains(strings.Join(a.DataUsePoints, " "), "OpenCode") {
		t.Fatalf("OpenAI notice mentions OpenCode: %q", a.DataUse)
	}
	if !strings.Contains(a.DataUse, "checks messages and answers for harmful content") {
		t.Fatal("OpenAI notice omits the moderation check")
	}
	if !strings.Contains(o.DataUse, "session identifier") || strings.Contains(o.DataUse, "harmful content") {
		t.Fatalf("OpenCode notice wrong: %q", o.DataUse)
	}
}
