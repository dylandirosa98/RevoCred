package httpapi

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/revocred/revocred-api/internal/auth"
)

func TestDeleteRequiresRecentPasswordProofFromSameSession(t *testing.T) {
	now := time.Now().UTC()
	old := now.Add(-10 * time.Minute)
	future := now.Add(2 * time.Minute)
	for _, tc := range []struct {
		name  string
		proof *time.Time
		want  int
	}{
		{"global recent login does not authorize", nil, http.StatusForbidden},
		{"old session not refreshed by other session login", &old, http.StatusForbidden},
		{"future timestamp rejected", &future, http.StatusForbidden},
		{"recent session password proof", &now, http.StatusNoContent},
	} {
		t.Run(tc.name, func(t *testing.T) {
			h := testHandler(&fakeAuthenticator{user: auth.User{ID: "11111111-1111-4111-8111-111111111111", LastSignInAt: &now, PasswordAuthenticatedAt: tc.proof}})
			req := httptest.NewRequest(http.MethodDelete, "/v1/account", nil)
			req.Header.Set("Authorization", "Bearer test-session")
			resp := httptest.NewRecorder()
			h.ServeHTTP(resp, req)
			if resp.Code != tc.want {
				t.Fatalf("got %d: %s", resp.Code, resp.Body.String())
			}
		})
	}
}
