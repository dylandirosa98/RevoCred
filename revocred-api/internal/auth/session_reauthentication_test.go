package auth

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"testing"
	"time"
)

func TestSensitiveAuthenticationUsesVerifiedSessionsPasswordTimestamp(t *testing.T) {
	const id = "11111111-1111-4111-8111-111111111111"
	now := time.Now().UTC().Truncate(time.Second)
	for _, tc := range []struct {
		name, method string
		age          time.Duration
		missing      bool
	}{
		{"fresh password", "password", time.Minute, false},
		{"old session despite another recent login", "password", time.Hour, false},
		{"refresh does not reauthenticate", "token_refresh", time.Minute, false},
		{"recovery is not password reauthentication", "recovery", time.Minute, false},
		{"missing amr", "", 0, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			claims := map[string]any{"sub": id, "iat": now.Unix()}
			if !tc.missing {
				claims["amr"] = []map[string]any{{"method": tc.method, "timestamp": now.Add(-tc.age).Unix()}}
			}
			raw, _ := json.Marshal(claims)
			token := "header." + base64.RawURLEncoding.EncodeToString(raw) + ".signature"
			client := &http.Client{Transport: roundTripFunc(func(*http.Request) (*http.Response, error) {
				body := fmt.Sprintf(`{"id":%q,"last_sign_in_at":%q}`, id, now.Format(time.RFC3339))
				return &http.Response{StatusCode: 200, Body: io.NopCloser(strings.NewReader(body))}, nil
			})}
			a, err := NewSupabaseAuthenticator("https://example.supabase.co", "public-key", client)
			if err != nil {
				t.Fatal(err)
			}
			got, err := a.Authenticate(context.Background(), token)
			if err != nil {
				t.Fatal(err)
			}
			if tc.method == "password" {
				want := now.Add(-tc.age)
				if got.PasswordAuthenticatedAt == nil || !got.PasswordAuthenticatedAt.Equal(want) {
					t.Fatalf("password authentication time must be session-bound, want %v, got %+v", want, got)
				}
			} else if got.PasswordAuthenticatedAt != nil {
				t.Fatal("non-password authentication must not authorize destructive action")
			}
		})
	}
}
