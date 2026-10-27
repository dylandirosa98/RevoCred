package chat

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"net/url"
	"strings"
)

// SharingDisclosure describes the configured recipient, not a client build-time
// guess. Its version changes with endpoint, model or disclosure wording.
type SharingDisclosure struct {
	External  bool   `json:"external"`
	Version   string `json:"version"`
	Recipient string `json:"recipient"`
	Model     string `json:"model"`
	DataUse   string `json:"data_use"`
}

const sharingDataUse = "To explain your plan, your message is sent to this AI service. When signed in, the request also includes your first name, life stage, credit band, spending, wallet card details, strategy, recommendation ranking and up to eight recent chat messages. Guest chat uses demo context, but your message is still shared. OpenCode Go testing also sends an account-linked session identifier. If needed, the AI may choose to search the public web through DuckDuckGo using minimal public product/topic queries, and RevoCred may read public HTTPS sources (including non-issuer sites and readable PDFs) to answer with source URLs. Your profile and chat history are shared with the AI service, not sent wholesale to search or source sites; the AI is instructed to omit personal details from tool requests and clear sensitive identifiers are blocked. Web sources can be incomplete or outdated and never change app scores, ranking or strategy. Do not include card numbers, security codes, bank passwords or other sensitive details. Basic replies use RevoCred's server without external AI. Permission applies only to this message; you choose again for the next one."

// Disclosure fails closed for providers whose actual recipient we cannot name.
func Disclosure(provider Provider) (SharingDisclosure, error) {
	if provider.Mode() == "deterministic" {
		return SharingDisclosure{}, nil
	}
	if described, ok := provider.(interface {
		SharingDisclosure() (SharingDisclosure, error)
	}); ok {
		return described.SharingDisclosure()
	}
	return SharingDisclosure{}, errors.New("AI recipient disclosure is unavailable")
}

func (p goProvider) SharingDisclosure() (SharingDisclosure, error) {
	u, err := url.Parse(p.endpoint)
	if err != nil || u.User != nil {
		return SharingDisclosure{}, errors.New("AI recipient disclosure is unavailable")
	}
	recipient := ""
	switch u.Hostname() {
	case "api.openai.com":
		recipient = "OpenAI"
	case "opencode.ai":
		// Other hosted models may have different upstream recipients and terms.
		if strings.HasPrefix(p.model, "deepseek-") {
			recipient = "OpenCode Go and DeepSeek (testing)"
		}
	}
	if recipient == "" {
		return SharingDisclosure{}, errors.New("AI recipient disclosure is unavailable")
	}
	digest := sha256.Sum256([]byte("revo-sharing-v3\n" + p.endpoint + "\n" + p.model + "\n" + recipient + "\n" + sharingDataUse))
	return SharingDisclosure{
		External: true, Version: hex.EncodeToString(digest[:]),
		Recipient: recipient, Model: p.model, DataUse: sharingDataUse,
	}, nil
}
