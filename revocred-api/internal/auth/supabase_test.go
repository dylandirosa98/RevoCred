package auth

import (
	"context"
	"errors"
	"io"
	"net/http"
	"strings"
	"testing"
)

type roundTripFunc func(*http.Request) (*http.Response, error)

func (fn roundTripFunc) RoundTrip(request *http.Request) (*http.Response, error) { return fn(request) }

func TestSupabaseAuthenticatorVerifiesThroughUserEndpoint(t *testing.T) {
	client := &http.Client{Transport: roundTripFunc(func(request *http.Request) (*http.Response, error) {
		if request.URL.String() != "https://example.supabase.co/auth/v1/user" {
			t.Fatalf("unexpected URL: %s", request.URL)
		}
		if request.Header.Get("Authorization") != "Bearer access-token" || request.Header.Get("apikey") != "anon-key" {
			t.Fatalf("missing auth headers: %#v", request.Header)
		}
		return &http.Response{
			StatusCode: http.StatusOK,
			Header:     make(http.Header),
			Body:       io.NopCloser(strings.NewReader(`{"id":"11111111-1111-4111-8111-111111111111","email":"user@example.test"}`)),
		}, nil
	})}
	authenticator, err := NewSupabaseAuthenticator("https://example.supabase.co", "anon-key", client)
	if err != nil {
		t.Fatal(err)
	}

	user, err := authenticator.Authenticate(context.Background(), "access-token")
	if err != nil {
		t.Fatal(err)
	}
	if user.ID != "11111111-1111-4111-8111-111111111111" {
		t.Fatalf("unexpected user: %#v", user)
	}
}

func TestSupabaseAuthenticatorMapsRejectedToken(t *testing.T) {
	client := &http.Client{Transport: roundTripFunc(func(_ *http.Request) (*http.Response, error) {
		return &http.Response{
			StatusCode: http.StatusUnauthorized,
			Header:     make(http.Header),
			Body:       io.NopCloser(strings.NewReader(`{"message":"bad token"}`)),
		}, nil
	})}
	authenticator, err := NewSupabaseAuthenticator("https://example.supabase.co", "anon-key", client)
	if err != nil {
		t.Fatal(err)
	}

	_, err = authenticator.Authenticate(context.Background(), "expired")
	if !errors.Is(err, ErrUnauthorized) {
		t.Fatalf("expected ErrUnauthorized, got %v", err)
	}
}

func TestNewSupabaseAuthenticatorAllowsLocalHTTP(t *testing.T) {
	client := &http.Client{Transport: roundTripFunc(func(_ *http.Request) (*http.Response, error) {
		return &http.Response{StatusCode: http.StatusOK, Body: io.NopCloser(strings.NewReader(`{}`))}, nil
	})}
	if _, err := NewSupabaseAuthenticator("http://127.0.0.1:54321", "anon-key", client); err != nil {
		t.Fatalf("localhost HTTP should be allowed: %v", err)
	}
	if _, err := NewSupabaseAuthenticator("http://example.supabase.co", "anon-key", client); err == nil {
		t.Fatal("non-local HTTP should be rejected")
	}
}
