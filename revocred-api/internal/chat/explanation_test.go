package chat

import (
	"strings"
	"testing"
)

func TestPromptSeparatesWalletScoreFromValueAndKeepsFollowupsShort(t *testing.T) {
	prompt := systemPrompt(Snapshot(DemoBrowseContext()))
	for _, rule := range []string{"Wallet score measures reward coverage", "not derived from yearly dollar value", "one to three sentences"} {
		if !strings.Contains(prompt, rule) {
			t.Errorf("missing explanation rule: %s", rule)
		}
	}
}
