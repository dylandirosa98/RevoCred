package httpapi

import (
	"net/http"

	"github.com/revocred/revocred-api/internal/explore"
)

// exploreRewards serves the illustrative Explore Rewards examples. They are the
// same for every member; the app personalizes them with the member's own
// server-computed annual points.
func (a *API) exploreRewards(w http.ResponseWriter, r *http.Request) {
	rewards, err := explore.Load()
	if err != nil {
		writeError(w, r, http.StatusServiceUnavailable, "explore_rewards_unavailable", "Reward examples are unavailable right now.", nil)
		return
	}
	writeData(w, http.StatusOK, rewards)
}
