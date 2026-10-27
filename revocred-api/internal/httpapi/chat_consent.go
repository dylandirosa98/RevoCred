package httpapi

import (
	"net/http"

	"github.com/revocred/revocred-api/internal/chat"
)

func (a *API) chatDisclosure(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Cache-Control", "no-store")
	disclosure, err := chat.Disclosure(a.chatProvider)
	if err != nil {
		writeError(w, r, http.StatusServiceUnavailable, "ai_disclosure_unavailable", "External AI is unavailable. You can still use your plan and wallet.", nil)
		return
	}
	writeData(w, http.StatusOK, disclosure)
}

// Missing permission always uses a local deterministic reply, including for old
// clients. A stale/nonmatching permission must never authorize a new recipient.
func (a *API) consentedChatProvider(w http.ResponseWriter, r *http.Request, consentVersion string) (chat.Provider, bool) {
	if consentVersion == "" {
		if a.chatProvider.Mode() == "deterministic" {
			return a.chatProvider, true
		}
		return chat.NewDeterministicProvider(), true
	}
	disclosure, err := chat.Disclosure(a.chatProvider)
	if err != nil || !disclosure.External || consentVersion != disclosure.Version {
		writeError(w, r, http.StatusConflict, "ai_consent_changed", "The AI service changed. Review its sharing notice and send again.", nil)
		return nil, false
	}
	return a.chatProvider, true
}
