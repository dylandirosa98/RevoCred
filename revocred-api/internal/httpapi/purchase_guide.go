package httpapi

import (
	"github.com/revocred/revocred-api/internal/purchaseguide"
	"net/http"
)

func (a *API) purchaseGuide(w http.ResponseWriter, r *http.Request) {
	settings := purchaseguide.DefaultOptions()
	if mode := r.URL.Query().Get("travel_mode"); mode != "" {
		if _, ok := purchaseguide.TravelModes[mode]; !ok {
			writeError(w, r, http.StatusBadRequest, "invalid_context", "Unknown travel booking context.", nil)
			return
		}
		settings.TravelMode = mode
	}
	if caps := r.URL.Query().Get("caps_available"); caps != "" {
		if caps != "true" && caps != "false" {
			writeError(w, r, http.StatusBadRequest, "invalid_context", "caps_available must be true or false.", nil)
			return
		}
		settings.CapsAvailable = caps == "true"
	}
	wallet, err := a.repository.ListWallet(r.Context(), authenticatedUser(r.Context()).ID)
	if err != nil {
		a.internalError(w, r, err)
		return
	}
	// No catalog IDs, rates or account identifiers from the browser are accepted.
	writeData(w, http.StatusOK, purchaseguide.NewGuide(wallet, settings))
}
