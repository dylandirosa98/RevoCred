package httpapi

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/revocred/revocred-api/internal/chat"
)

func TestExploreRewardsIsPublic(t *testing.T) {
	response := httptest.NewRecorder()
	consentHandler(chat.NewDeterministicProvider()).ServeHTTP(response,
		httptest.NewRequest(http.MethodGet, "/v1/public/explore-rewards", nil))
	if response.Code != http.StatusOK {
		t.Fatalf("status %d: %s", response.Code, response.Body.String())
	}
	var body struct {
		Data struct {
			Version  string                                `json:"version"`
			Airports []map[string]string                   `json:"airports"`
			Fares    map[string]map[string]json.RawMessage `json:"fares"`
		} `json:"data"`
	}
	if err := json.Unmarshal(response.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	if body.Data.Version == "" || len(body.Data.Airports) != 4 || len(body.Data.Fares["SFO"]) != 28 {
		t.Fatalf("unexpected payload: %+v", body.Data)
	}
}
