package httpapi

import (
	"errors"
	"net/http"
	"strings"

	"github.com/revocred/revocred-api/internal/affiliate"
	"github.com/revocred/revocred-api/internal/store"
)

func (a *API) offers(w http.ResponseWriter, r *http.Request) {
	offers, err := a.repository.ListOffers(r.Context())
	if err != nil {
		a.internalError(w, r, err)
		return
	}
	writeData(w, http.StatusOK, offers)
}

func (a *API) applyOffer(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("Referrer-Policy", "no-referrer")
	// GET is a browser navigation. HEAD/prefetch must not count as an application click.
	if r.Method != http.MethodGet {
		w.Header().Set("Allow", "GET")
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}
	if isPrefetch(r.Header.Get("Purpose")) || isPrefetch(r.Header.Get("Sec-Purpose")) {
		w.WriteHeader(http.StatusNoContent)
		return
	}
	placement := r.URL.Query().Get("placement")
	if !validUUID(r.PathValue("id")) || !affiliate.ValidPlacement(placement) || len(r.URL.Query()) != 1 || len(r.URL.Query()["placement"]) != 1 {
		writeError(w, r, http.StatusBadRequest, "invalid_offer_link", "Invalid application link.", nil)
		return
	}
	destination, err := a.repository.RecordOfferClick(r.Context(), r.PathValue("id"), placement)
	if errors.Is(err, store.ErrNotFound) {
		writeError(w, r, http.StatusNotFound, "offer_unavailable", "This offer is no longer available. Return to RevoCred to refresh your options.", nil)
		return
	}
	if err != nil {
		a.internalError(w, r, err)
		return
	}
	if !affiliate.ValidDestination(destination) {
		writeError(w, r, http.StatusNotFound, "offer_unavailable", "This offer is unavailable.", nil)
		return
	}
	w.Header().Set("Location", destination)
	w.WriteHeader(http.StatusFound)
}

func isPrefetch(value string) bool {
	for _, token := range strings.FieldsFunc(strings.ToLower(value), func(r rune) bool { return r == ';' || r == ',' || r == ' ' }) {
		if token == "prefetch" {
			return true
		}
	}
	return false
}
