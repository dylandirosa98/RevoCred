package httpapi

import (
	"errors"
	"net"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/revocred/revocred-api/internal/domain"
	"github.com/revocred/revocred-api/internal/store"
)

func (a *API) onboardingInput(w http.ResponseWriter, r *http.Request) (domain.RecommendationInput, bool) {
	var input domain.RecommendationInput
	if !a.decodeJSON(w, r, &input) {
		return input, false
	}
	fields := validateRecommendation(input)
	if input.LifeStage == "" {
		fields["life_stage"] = "choose an adult life stage"
	}
	for _, id := range input.ExistingCardIDs {
		if !validUUID(id) {
			fields["existing_card_ids"] = "select catalog card IDs"
		}
	}
	if len(fields) > 0 {
		writeError(w, r, 422, "validation_error", "Check your questionnaire answers.", fields)
		return input, false
	}
	return input, true
}
func (a *API) previewPlan(w http.ResponseWriter, r *http.Request) {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		host = r.RemoteAddr
	}
	if !a.limits.allow("plan:"+host, 30, time.Now()) {
		a.tooMany(w, r)
		return
	}
	input, ok := a.onboardingInput(w, r)
	if !ok {
		return
	}
	value, err := a.repository.PreviewPlan(r.Context(), input)
	if a.onboardingError(w, r, err) {
		return
	}
	writeData(w, http.StatusOK, value)
}
func (a *API) saveOnboarding(w http.ResponseWriter, r *http.Request) {
	input, ok := a.onboardingInput(w, r)
	if !ok {
		return
	}
	value, err := a.repository.SaveOnboarding(r.Context(), authenticatedUser(r.Context()).ID, input)
	if a.onboardingError(w, r, err) {
		return
	}
	writeData(w, http.StatusCreated, value)
}
func (a *API) onboardingError(w http.ResponseWriter, r *http.Request, err error) bool {
	if errors.Is(err, store.ErrNotFound) {
		writeError(w, r, 422, "card_unavailable", "A selected card is no longer available. Review your wallet selection.", nil)
		return true
	}
	if err != nil {
		a.internalError(w, r, err)
		return true
	}
	return false
}

// cardIndex serves the search-only card list used during onboarding. It is
// rate limited per IP because it is unauthenticated, and it never exposes
// anything a user cannot see in the public catalog.
func (a *API) cardIndex(w http.ResponseWriter, r *http.Request) {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		host = r.RemoteAddr
	}
	if !a.limits.allow("index:"+host, 60, time.Now()) {
		a.tooMany(w, r)
		return
	}
	query := strings.TrimSpace(r.URL.Query().Get("q"))
	if len(query) > 100 {
		writeError(w, r, http.StatusUnprocessableEntity, "validation_error", "search text is too long", nil)
		return
	}
	if len(r.URL.Query()) > 1 {
		writeError(w, r, http.StatusUnprocessableEntity, "validation_error", "unexpected query parameters", nil)
		return
	}
	limit := 20
	if raw := r.URL.Query().Get("limit"); raw != "" {
		parsed, convErr := strconv.Atoi(raw)
		if convErr != nil || parsed < 1 || parsed > 50 {
			writeError(w, r, http.StatusUnprocessableEntity, "validation_error", "limit must be between 1 and 50", nil)
			return
		}
		limit = parsed
	}
	cards, err := a.repository.SearchReferenceCards(r.Context(), query, limit)
	if a.onboardingError(w, r, err) {
		return
	}
	writeData(w, http.StatusOK, cards)
}
