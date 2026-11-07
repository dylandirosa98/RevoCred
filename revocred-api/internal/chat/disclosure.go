package chat

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"net/url"
	"strings"
)

// SharingDisclosure describes the configured recipient, not a client build-time
// guess. Its version changes with endpoint, model or disclosure wording.
type SharingDisclosure struct {
	DataUsePoints  []string `json:"data_use_points"`
	SearchProvider string   `json:"search_provider"`
	External       bool     `json:"external"`
	Version        string   `json:"version"`
	Recipient      string   `json:"recipient"`
	Model          string   `json:"model"`
	DataUse        string   `json:"data_use"`
}

const sharingDataUse = "Your message and saved plan context, including first name, life stage, credit band, spending, wallet, strategy, ranking and up to eight recent messages, are shared with the AI service. Guest messages use demo context. OpenCode Go testing also sends an account-linked session identifier. RevoCred may read public HTTPS pages and readable PDFs; private identifiers are blocked in tool requests. Public sources may be outdated and never change scores or ranking. Do not share card numbers, security codes or passwords. Basic answers use the server without external AI. Permission is saved for your account until you turn it off in Profile. You will be asked again if the AI service or this notice changes."

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
	points := []string{
		"Your message and saved plan context are shared with the AI service.",
		"Context includes first name, life stage, credit band, spending, wallet, strategy, ranking and up to eight recent messages; guests use demo context.",
		"OpenCode Go testing also sends an account-linked session identifier.",
		"Public HTTPS pages and readable PDFs may be read; private identifiers are blocked in tool requests and sources never change scores or ranking.",
		"Do not share card numbers, security codes or passwords. Basic answers use the server without external AI.",
		"Permission is saved for your account until you turn it off in Profile; you will be asked again if the AI service or notice changes.",
	}
	dataUse := sharingDataUse
	searchProvider := ""
	if p.searchAPIKey != "" {
		searchProvider = "Brave Search"
		point := "Brave Search receives minimal public product or topic queries, not your profile or chat history; sources may be incomplete or outdated."
		points = append(points, point)
		dataUse += " " + point
	}
	result := SharingDisclosure{External: true, Recipient: recipient, Model: p.model, DataUse: dataUse, DataUsePoints: points, SearchProvider: searchProvider}
	encoded, _ := json.Marshal(result)
	digest := sha256.Sum256(append([]byte("revo-sharing-v4\n"+p.endpoint+"\n"), encoded...))
	result.Version = hex.EncodeToString(digest[:])
	return result, nil
}
