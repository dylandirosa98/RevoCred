package httpapi

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"net/http"
	"runtime/debug"
	"strings"
	"time"

	"github.com/revocred/revocred-api/internal/auth"
)

type contextKey string

const (
	requestIDKey contextKey = "request_id"
	userKey      contextKey = "authenticated_user"
)

func (a *API) requireAuthentication(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		header := strings.TrimSpace(r.Header.Get("Authorization"))
		parts := strings.Fields(header)
		if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
			writeError(w, r, http.StatusUnauthorized, "unauthorized", "a valid bearer token is required", nil)
			return
		}
		user, err := a.authenticator.Authenticate(r.Context(), parts[1])
		if errors.Is(err, auth.ErrUnauthorized) {
			writeError(w, r, http.StatusUnauthorized, "unauthorized", "bearer token is invalid or expired", nil)
			return
		}
		if err != nil {
			a.logger.ErrorContext(r.Context(), "authentication provider failed", "request_id", requestIDFromContext(r.Context()), "error", err)
			writeError(w, r, http.StatusServiceUnavailable, "authentication_unavailable", "authentication service is unavailable", nil)
			return
		}
		ctx := context.WithValue(r.Context(), userKey, user)
		key, limit := "read:"+user.ID, 120
		if r.Method != http.MethodGet {
			key, limit = "write:"+user.ID, 30
		}
		if !a.limits.allow(key, limit, time.Now()) {
			a.tooMany(w, r)
			return
		}
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func authenticatedUser(ctx context.Context) auth.User {
	user, _ := ctx.Value(userKey).(auth.User)
	return user
}

func (a *API) cors(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := strings.TrimRight(r.Header.Get("Origin"), "/")
		if origin != "" {
			if _, allowed := a.allowedOrigins[origin]; !allowed {
				writeError(w, r, http.StatusForbidden, "origin_not_allowed", "request origin is not allowed", nil)
				return
			}
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Access-Control-Allow-Credentials", "true")
			w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type, X-Request-ID")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
			w.Header().Add("Vary", "Origin")
		}
		next.ServeHTTP(w, r)
	})
}

// chatRequestTimeout must stay below the server's WriteTimeout.
const chatRequestTimeout = 45 * time.Second

func (a *API) deadline(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		timeout := a.requestTimeout
		if r.Method == http.MethodPost && (r.URL.Path == "/v1/chat/messages" || r.URL.Path == "/v1/public/explain") {
			// A model reply can take longer than an ordinary request. The chat
			// provider stops the model early enough to still answer and save.
			timeout = chatRequestTimeout
		}
		ctx, cancel := context.WithTimeout(r.Context(), timeout)
		defer cancel()
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func (a *API) requestID(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requestID := strings.TrimSpace(r.Header.Get("X-Request-ID"))
		if requestID == "" || len(requestID) > 128 {
			requestID = newRequestID()
		}
		w.Header().Set("X-Request-ID", requestID)
		ctx := context.WithValue(r.Context(), requestIDKey, requestID)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func newRequestID() string {
	buffer := make([]byte, 16)
	if _, err := rand.Read(buffer); err != nil {
		return time.Now().UTC().Format("20060102T150405.000000000")
	}
	return hex.EncodeToString(buffer)
}

func requestIDFromContext(ctx context.Context) string {
	requestID, _ := ctx.Value(requestIDKey).(string)
	return requestID
}

type responseRecorder struct {
	http.ResponseWriter
	status int
}

func (w *responseRecorder) WriteHeader(status int) {
	if w.status != 0 {
		return
	}
	w.status = status
	w.ResponseWriter.WriteHeader(status)
}

func (w *responseRecorder) Write(body []byte) (int, error) {
	if w.status == 0 {
		w.WriteHeader(http.StatusOK)
	}
	return w.ResponseWriter.Write(body)
}

func (a *API) logging(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		started := time.Now()
		recorder := &responseRecorder{ResponseWriter: w}
		next.ServeHTTP(recorder, r)
		status := recorder.status
		if status == 0 {
			status = http.StatusOK
		}
		a.stats.requests.Add(1)
		if status >= 500 {
			a.stats.failures.Add(1)
		}
		a.logger.InfoContext(r.Context(), "http request",
			"request_id", requestIDFromContext(r.Context()), "method", r.Method,
			"path", r.URL.Path, "status", status, "duration_ms", time.Since(started).Milliseconds(),
		)
	})
}

func (a *API) recoverPanic(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if recovered := recover(); recovered != nil {
				a.logger.ErrorContext(r.Context(), "panic recovered", "request_id", requestIDFromContext(r.Context()), "panic", recovered, "stack", string(debug.Stack()))
				writeError(w, r, http.StatusInternalServerError, "internal_error", "an internal error occurred", nil)
			}
		}()
		next.ServeHTTP(w, r)
	})
}
