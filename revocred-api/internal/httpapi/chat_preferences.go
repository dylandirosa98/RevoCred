package httpapi

import (
	"net/http"
	"unicode/utf8"

	"github.com/revocred/revocred-api/internal/chat"
)

func (a *API) chatConsent(w http.ResponseWriter, r *http.Request) {
	store := a.repository
	user := authenticatedUser(r.Context()).ID
	if r.Method == http.MethodDelete {
		if err := store.SetChatConsent(r.Context(), user, ""); err != nil {
			a.internalError(w, r, err)
			return
		}
		w.WriteHeader(http.StatusNoContent)
		return
	}
	disclosure, err := chat.Disclosure(a.chatProvider)
	if r.Method == http.MethodPut {
		var input struct {
			Version string `json:"version"`
		}
		if !a.decodeJSON(w, r, &input) {
			return
		}
		if err != nil || !disclosure.External {
			writeError(w, r, http.StatusServiceUnavailable, "ai_disclosure_unavailable", "External AI is unavailable. You can still use your plan and wallet.", nil)
			return
		}
		if input.Version != disclosure.Version {
			writeError(w, r, http.StatusConflict, "ai_consent_changed", "The AI service changed. Review its sharing notice and send again.", nil)
			return
		}
		if err = store.SetChatConsent(r.Context(), user, input.Version); err != nil {
			a.internalError(w, r, err)
			return
		}
	}
	version, storeErr := store.ChatConsent(r.Context(), user)
	if storeErr != nil {
		a.internalError(w, r, storeErr)
		return
	}
	granted := err == nil && disclosure.External && version == disclosure.Version
	if !granted {
		version = ""
	}
	w.Header().Set("Cache-Control", "no-store")
	writeData(w, http.StatusOK, struct {
		Granted bool   `json:"granted"`
		Version string `json:"version"`
	}{granted, version})
}

func (a *API) clearChat(w http.ResponseWriter, r *http.Request) {
	store := a.repository
	if err := store.ClearChat(r.Context(), authenticatedUser(r.Context()).ID); err != nil {
		a.internalError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
func (a *API) chatFeedback(w http.ResponseWriter, r *http.Request) {
	var input struct {
		Rating string `json:"rating"`
		Reason string `json:"reason"`
	}
	if !a.decodeJSON(w, r, &input) {
		return
	}
	if (input.Rating != "up" && input.Rating != "down") || utf8.RuneCountInString(input.Reason) > 500 {
		writeError(w, r, http.StatusUnprocessableEntity, "validation_error", "Invalid feedback.", nil)
		return
	}
	store := a.repository
	found, err := store.ChatFeedback(r.Context(), authenticatedUser(r.Context()).ID, r.PathValue("id"), input.Rating, input.Reason)
	if err != nil {
		a.internalError(w, r, err)
		return
	}
	if !found {
		writeError(w, r, http.StatusNotFound, "not_found", "Message not found.", nil)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
