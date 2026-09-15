package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/revocred/revocred-api/internal/auth"
	"github.com/revocred/revocred-api/internal/chat"
	"github.com/revocred/revocred-api/internal/domain"
	"github.com/revocred/revocred-api/internal/store"
)

const maxRequestBodyBytes = 1 << 20

type Recommender interface {
	Recommend(input domain.RecommendationInput, cards []domain.CatalogCard) domain.RecommendationResult
}

type API struct {
	repository     store.Repository
	authenticator  auth.Authenticator
	recommender    Recommender
	chatProvider   chat.Provider
	logger         *slog.Logger
	allowedOrigins map[string]struct{}
	requestTimeout time.Duration
}

func New(
	repository store.Repository,
	authenticator auth.Authenticator,
	recommender Recommender,
	chatProvider chat.Provider,
	logger *slog.Logger,
	allowedOrigins []string,
	requestTimeout time.Duration,
) http.Handler {
	api := &API{
		repository: repository, authenticator: authenticator, recommender: recommender,
		chatProvider: chatProvider, logger: logger, requestTimeout: requestTimeout,
		allowedOrigins: make(map[string]struct{}, len(allowedOrigins)),
	}
	for _, origin := range allowedOrigins {
		api.allowedOrigins[strings.TrimRight(origin, "/")] = struct{}{}
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", api.health)
	mux.HandleFunc("OPTIONS /", api.options)
	api.protected(mux, "GET /v1/bootstrap", api.bootstrap)
	api.protected(mux, "GET /v1/cards", api.cards)
	api.protected(mux, "GET /v1/profile", api.getProfile)
	api.protected(mux, "PUT /v1/profile", api.putProfile)
	api.protected(mux, "GET /v1/wallet", api.getWallet)
	api.protected(mux, "POST /v1/wallet", api.postWallet)
	api.protected(mux, "DELETE /v1/wallet", api.deleteWallet)
	api.protected(mux, "POST /v1/recommendations", api.postRecommendations)
	api.protected(mux, "GET /v1/chat/messages", api.getMessages)
	api.protected(mux, "POST /v1/chat/messages", api.postMessage)

	return api.requestID(api.logging(api.recoverPanic(api.cors(api.deadline(mux)))))
}

func (a *API) protected(mux *http.ServeMux, pattern string, handler http.HandlerFunc) {
	mux.Handle(pattern, a.requireAuthentication(handler))
}

func (a *API) health(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{"status": "ok"})
}

func (a *API) options(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusNoContent) }

func (a *API) bootstrap(w http.ResponseWriter, r *http.Request) {
	value, err := a.repository.Bootstrap(r.Context(), authenticatedUser(r.Context()).ID)
	if err != nil {
		a.internalError(w, r, err)
		return
	}
	writeData(w, http.StatusOK, value)
}

func (a *API) cards(w http.ResponseWriter, r *http.Request) {
	cards, err := a.repository.ListCatalog(r.Context())
	if err != nil {
		a.internalError(w, r, err)
		return
	}
	writeData(w, http.StatusOK, cards)
}

func (a *API) getProfile(w http.ResponseWriter, r *http.Request) {
	profile, err := a.repository.GetProfile(r.Context(), authenticatedUser(r.Context()).ID)
	if err != nil {
		a.internalError(w, r, err)
		return
	}
	writeData(w, http.StatusOK, profile)
}

func (a *API) putProfile(w http.ResponseWriter, r *http.Request) {
	var profile domain.Profile
	if !a.decodeJSON(w, r, &profile) {
		return
	}
	if fields := validateProfile(profile); len(fields) > 0 {
		writeError(w, r, http.StatusUnprocessableEntity, "validation_error", "request validation failed", fields)
		return
	}
	profile, err := a.repository.UpsertProfile(r.Context(), authenticatedUser(r.Context()).ID, profile)
	if err != nil {
		a.internalError(w, r, err)
		return
	}
	writeData(w, http.StatusOK, profile)
}

func (a *API) getWallet(w http.ResponseWriter, r *http.Request) {
	wallet, err := a.repository.ListWallet(r.Context(), authenticatedUser(r.Context()).ID)
	if err != nil {
		a.internalError(w, r, err)
		return
	}
	writeData(w, http.StatusOK, wallet)
}

func (a *API) postWallet(w http.ResponseWriter, r *http.Request) {
	var input domain.CreateWalletCard
	if !a.decodeJSON(w, r, &input) {
		return
	}
	if fields := validateWalletCard(input); len(fields) > 0 {
		writeError(w, r, http.StatusUnprocessableEntity, "validation_error", "request validation failed", fields)
		return
	}
	item, err := a.repository.CreateWalletCard(r.Context(), authenticatedUser(r.Context()).ID, input)
	if errors.Is(err, store.ErrNotFound) {
		writeError(w, r, http.StatusNotFound, "catalog_card_not_found", "catalog card not found", nil)
		return
	}
	if errors.Is(err, store.ErrConflict) {
		writeError(w, r, http.StatusConflict, "wallet_card_exists", "card is already in the wallet", nil)
		return
	}
	if err != nil {
		a.internalError(w, r, err)
		return
	}
	writeData(w, http.StatusCreated, item)
}

func (a *API) deleteWallet(w http.ResponseWriter, r *http.Request) {
	var input struct {
		WalletCardID string `json:"wallet_card_id"`
	}
	if !a.decodeJSON(w, r, &input) {
		return
	}
	if !validUUID(input.WalletCardID) {
		writeError(w, r, http.StatusUnprocessableEntity, "validation_error", "request validation failed", map[string]string{"wallet_card_id": "must be a UUID"})
		return
	}
	err := a.repository.DeleteWalletCard(r.Context(), authenticatedUser(r.Context()).ID, input.WalletCardID)
	if errors.Is(err, store.ErrNotFound) {
		writeError(w, r, http.StatusNotFound, "wallet_card_not_found", "wallet card not found", nil)
		return
	}
	if err != nil {
		a.internalError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (a *API) postRecommendations(w http.ResponseWriter, r *http.Request) {
	var input domain.RecommendationInput
	if !a.decodeJSON(w, r, &input) {
		return
	}
	if fields := validateRecommendation(input); len(fields) > 0 {
		writeError(w, r, http.StatusUnprocessableEntity, "validation_error", "request validation failed", fields)
		return
	}
	userID := authenticatedUser(r.Context()).ID
	wallet, err := a.repository.ListWallet(r.Context(), userID)
	if err != nil {
		a.internalError(w, r, err)
		return
	}
	input.ExistingCardIDs = input.ExistingCardIDs[:0]
	for _, item := range wallet {
		if item.Status == "active" {
			input.ExistingCardIDs = append(input.ExistingCardIDs, item.CatalogCardID)
		}
	}
	cards, err := a.repository.ListCatalog(r.Context())
	if err != nil {
		a.internalError(w, r, err)
		return
	}
	result := a.recommender.Recommend(input, cards)
	result, err = a.repository.SaveRecommendation(r.Context(), userID, input, result)
	if err != nil {
		a.internalError(w, r, err)
		return
	}
	writeData(w, http.StatusCreated, result)
}

func (a *API) getMessages(w http.ResponseWriter, r *http.Request) {
	limit := 100
	if raw := r.URL.Query().Get("limit"); raw != "" {
		parsed, err := strconv.Atoi(raw)
		if err != nil || parsed < 1 || parsed > 200 {
			writeError(w, r, http.StatusUnprocessableEntity, "validation_error", "request validation failed", map[string]string{"limit": "must be between 1 and 200"})
			return
		}
		limit = parsed
	}
	messages, err := a.repository.ListMessages(r.Context(), authenticatedUser(r.Context()).ID, limit)
	if err != nil {
		a.internalError(w, r, err)
		return
	}
	writeData(w, http.StatusOK, messages)
}

func (a *API) postMessage(w http.ResponseWriter, r *http.Request) {
	var input struct {
		Content string `json:"content"`
	}
	if !a.decodeJSON(w, r, &input) {
		return
	}
	input.Content = strings.TrimSpace(input.Content)
	if input.Content == "" || len(input.Content) > 4000 {
		writeError(w, r, http.StatusUnprocessableEntity, "validation_error", "request validation failed", map[string]string{"content": "must contain 1 to 4000 characters"})
		return
	}
	userID := authenticatedUser(r.Context()).ID
	bootstrap, err := a.repository.Bootstrap(r.Context(), userID)
	if err != nil {
		a.internalError(w, r, err)
		return
	}
	reply, err := a.chatProvider.Reply(r.Context(), input.Content, chat.Context{Catalog: bootstrap.Catalog, Recommendations: bootstrap.LatestRecommendations})
	if err != nil {
		a.internalError(w, r, err)
		return
	}
	messages, err := a.repository.AppendChatExchange(r.Context(), userID, input.Content, reply)
	if err != nil {
		a.internalError(w, r, err)
		return
	}
	writeData(w, http.StatusCreated, messages)
}

func (a *API) decodeJSON(w http.ResponseWriter, r *http.Request, target any) bool {
	r.Body = http.MaxBytesReader(w, r.Body, maxRequestBodyBytes)
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil {
		var maxBytesError *http.MaxBytesError
		if errors.As(err, &maxBytesError) {
			writeError(w, r, http.StatusRequestEntityTooLarge, "request_too_large", "request body exceeds 1 MiB", nil)
			return false
		}
		writeError(w, r, http.StatusBadRequest, "invalid_json", "request body must be one valid JSON object with known fields", nil)
		return false
	}
	if err := decoder.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
		writeError(w, r, http.StatusBadRequest, "invalid_json", "request body must contain one JSON object", nil)
		return false
	}
	return true
}

func (a *API) internalError(w http.ResponseWriter, r *http.Request, err error) {
	a.logger.ErrorContext(r.Context(), "request failed", "request_id", requestIDFromContext(r.Context()), "error", err)
	if errors.Is(err, context.DeadlineExceeded) {
		writeError(w, r, http.StatusGatewayTimeout, "request_timeout", "request processing timed out", nil)
		return
	}
	writeError(w, r, http.StatusInternalServerError, "internal_error", "an internal error occurred", nil)
}

func writeData(w http.ResponseWriter, status int, data any) {
	writeJSON(w, status, map[string]any{"data": data})
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}

func writeError(w http.ResponseWriter, r *http.Request, status int, code, message string, details map[string]string) {
	payload := map[string]any{
		"code":       code,
		"message":    message,
		"request_id": requestIDFromContext(r.Context()),
	}
	if len(details) > 0 {
		payload["details"] = details
	}
	writeJSON(w, status, map[string]any{"error": payload})
}
