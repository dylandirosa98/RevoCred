package auth

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

var ErrUnauthorized = errors.New("unauthorized")

type User struct {
	// Set only from this bearer session's AMR after Supabase verifies the token.
	// A user's global last_sign_in_at may describe a different session.
	PasswordAuthenticatedAt *time.Time `json:"-"`
	LastSignInAt            *time.Time `json:"last_sign_in_at,omitempty"`
	ID                      string     `json:"id"`
	Email                   string     `json:"email,omitempty"`
}

type Authenticator interface {
	Authenticate(ctx context.Context, bearerToken string) (User, error)
}

type SupabaseAuthenticator struct {
	userEndpoint string
	anonKey      string
	client       *http.Client
}

func NewSupabaseAuthenticator(baseURL, anonKey string, client *http.Client) (*SupabaseAuthenticator, error) {
	parsed, err := url.Parse(strings.TrimRight(baseURL, "/"))
	if err != nil || !validSupabaseURL(parsed) {
		return nil, errors.New("SUPABASE_URL must be HTTPS, or HTTP on localhost")
	}
	if strings.TrimSpace(anonKey) == "" {
		return nil, errors.New("SUPABASE_ANON_KEY is required")
	}
	if client == nil {
		return nil, errors.New("HTTP client is required")
	}
	return &SupabaseAuthenticator{
		userEndpoint: parsed.String() + "/auth/v1/user",
		anonKey:      anonKey,
		client:       client,
	}, nil
}

func (a *SupabaseAuthenticator) Authenticate(ctx context.Context, bearerToken string) (User, error) {
	if strings.TrimSpace(bearerToken) == "" {
		return User{}, ErrUnauthorized
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, a.userEndpoint, nil)
	if err != nil {
		return User{}, fmt.Errorf("create auth request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+bearerToken)
	req.Header.Set("apikey", a.anonKey)
	req.Header.Set("Accept", "application/json")

	resp, err := a.client.Do(req)
	if err != nil {
		return User{}, fmt.Errorf("verify token: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusUnauthorized || resp.StatusCode == http.StatusForbidden {
		_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 4096))
		return User{}, ErrUnauthorized
	}
	if resp.StatusCode != http.StatusOK {
		_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 4096))
		return User{}, fmt.Errorf("supabase auth returned status %d", resp.StatusCode)
	}

	var user User
	decoder := json.NewDecoder(io.LimitReader(resp.Body, 64<<10))
	if err := decoder.Decode(&user); err != nil {
		return User{}, fmt.Errorf("decode auth response: %w", err)
	}
	if !isUUID(user.ID) {
		return User{}, ErrUnauthorized
	}
	user.PasswordAuthenticatedAt = verifiedPasswordTime(bearerToken, user.ID)
	return user, nil
}

// Call only after the exact bearer token has passed Supabase /user validation.
// iat changes on token refresh and last_sign_in_at can change in other sessions;
// neither establishes recent password proof for this session.
func verifiedPasswordTime(token, userID string) *time.Time {
	if len(token) > 64<<10 {
		return nil
	}
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return nil
	}
	raw, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return nil
	}
	var claims struct {
		Subject string `json:"sub"`
		AMR     []struct {
			Method    string `json:"method"`
			Timestamp int64  `json:"timestamp"`
		} `json:"amr"`
	}
	if json.Unmarshal(raw, &claims) != nil || claims.Subject != userID {
		return nil
	}
	var latest int64
	for _, proof := range claims.AMR {
		if proof.Method == "password" && proof.Timestamp > latest {
			latest = proof.Timestamp
		}
	}
	if latest == 0 {
		return nil
	}
	when := time.Unix(latest, 0).UTC()
	return &when
}

func isUUID(value string) bool {
	if len(value) != 36 {
		return false
	}
	for i, character := range value {
		if i == 8 || i == 13 || i == 18 || i == 23 {
			if character != '-' {
				return false
			}
			continue
		}
		if !((character >= '0' && character <= '9') || (character >= 'a' && character <= 'f') || (character >= 'A' && character <= 'F')) {
			return false
		}
	}
	return true
}

func validSupabaseURL(parsed *url.URL) bool {
	if parsed == nil || parsed.Host == "" {
		return false
	}
	if parsed.Scheme == "https" {
		return true
	}
	host := parsed.Hostname()
	return parsed.Scheme == "http" && (host == "127.0.0.1" || host == "localhost")
}
