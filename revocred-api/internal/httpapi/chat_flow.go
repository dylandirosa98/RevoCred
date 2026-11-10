package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/revocred/revocred-api/internal/chat"
	"github.com/revocred/revocred-api/internal/domain"
	"github.com/revocred/revocred-api/internal/store"
)

const (
	defaultChatDailyAILimit     = 60
	defaultChatFreeDailyAILimit = 3
	chatKeepAlive               = 10 * time.Second
	chatDailyLimitMessage       = "You've reached today's REVO AI limit. Basic answers are still available."
	chatFreeLimitMessage        = "You've used today's free REVO AI answers. Basic answers are still available, and AI answers reset within 24 hours."
)

type chatInput struct {
	Content          string `json:"content"`
	AIConsentVersion string `json:"ai_consent_version"`
}

func (a *API) decodeChatInput(w http.ResponseWriter, r *http.Request) (chatInput, bool) {
	var input chatInput
	if !a.decodeJSON(w, r, &input) {
		return input, false
	}
	input.Content = strings.TrimSpace(input.Content)
	if input.Content == "" || len(input.Content) > 4000 {
		writeError(w, r, http.StatusUnprocessableEntity, "validation_error", "request validation failed", map[string]string{"content": "must contain 1 to 4000 characters"})
		return input, false
	}
	return input, true
}

// publicExplain answers guests from demo context with basic answers only.
// External AI costs money per message, so it needs a signed-in account (and
// its daily allowance); a consent version sent by an older client is ignored.
func (a *API) publicExplain(w http.ResponseWriter, r *http.Request) {
	if !a.limits.allow("explain:"+a.clientIP(r), 20, time.Now()) {
		a.tooMany(w, r)
		return
	}
	input, ok := a.decodeChatInput(w, r)
	if !ok {
		return
	}
	var provider chat.Provider = chat.NewDeterministicProvider()
	if a.chatProvider.Mode() == "deterministic" {
		provider = a.chatProvider
	}
	a.runChat(w, r, provider, input.Content, chat.DemoBrowseContext(), func(_ context.Context, reply chat.Reply, mode string) ([]domain.ChatMessage, error) {
		if a.chatProvider.Mode() != "deterministic" && a.chatFreeDailyAILimit > 0 {
			note := chat.Block{Type: "note", Text: "Create a free account to get AI answers about your own cards."}
			reply.Blocks = append(reply.Blocks, note)
			reply.Text = chat.RenderText(reply.Blocks)
		}
		return []domain.ChatMessage{
			{ID: "demo-user", Role: "user", Content: input.Content},
			{ID: "demo-assistant", Role: "assistant", Content: reply.Text, Blocks: replyBlocks(reply), Mode: mode},
		}, nil
	})
}

func (a *API) postMessage(w http.ResponseWriter, r *http.Request) {
	input, ok := a.decodeChatInput(w, r)
	if !ok {
		return
	}
	userID := authenticatedUser(r.Context()).ID
	var provider chat.Provider
	if input.AIConsentVersion != "" {
		// An explicit version must match exactly; a stale one never authorises
		// a new recipient.
		var permitted bool
		if provider, permitted = a.consentedChatProvider(w, r, input.AIConsentVersion); !permitted {
			return
		}
	} else {
		stored, err := a.repository.ChatConsent(r.Context(), userID)
		if err != nil {
			a.internalError(w, r, err)
			return
		}
		// A stored permission for an older notice silently falls back to basic
		// answers; the client asks again when it sees the new version.
		provider = a.storedConsentProvider(stored)
	}
	var reservation store.AIUse
	if provider.Mode() != "deterministic" {
		use, err := a.repository.ReserveAIUse(r.Context(), userID, a.chatFreeDailyAILimit, a.chatDailyAILimit)
		if err != nil {
			a.internalError(w, r, err)
			return
		}
		if !use.Allowed {
			message := chatDailyLimitMessage
			if !use.Subscriber {
				message = chatFreeLimitMessage
			}
			writeError(w, r, http.StatusTooManyRequests, "chat_daily_limit", message, map[string]string{
				"limit": strconv.Itoa(use.Limit), "plan": map[bool]string{true: "subscriber", false: "free"}[use.Subscriber],
			})
			return
		}
		reservation = use
	}
	bootstrap, err := a.repository.Bootstrap(r.Context(), userID)
	if err != nil {
		a.internalError(w, r, err)
		return
	}
	recent, err := a.repository.ListMessages(r.Context(), userID, 8)
	if err != nil {
		a.internalError(w, r, err)
		return
	}
	history := make([]chat.Turn, 0, len(recent))
	for _, message := range recent {
		history = append(history, chat.Turn{Role: message.Role, Content: message.Content})
	}
	grounded := chat.Context{
		SessionID:       userID,
		History:         history,
		Catalog:         bootstrap.Catalog,
		Wallet:          bootstrap.Wallet,
		Recommendations: bootstrap.LatestRecommendations,
		Profile:         bootstrap.Profile,
		Questionnaire:   bootstrap.LatestQuestionnaire,
		Metrics:         bootstrap.WalletMetrics,
		Playbook:        bootstrap.Playbook,
	}
	a.runChat(w, r, provider, input.Content, grounded, func(ctx context.Context, reply chat.Reply, mode string) ([]domain.ChatMessage, error) {
		// A provider failure falls back to a basic answer; that is not an AI
		// answer, so the reserved use is given back.
		if reservation.Allowed && mode != "ai" {
			if err := a.repository.ReleaseAIUse(ctx, userID, reservation.ID); err != nil {
				a.logger.Warn("release ai use failed", "error", err)
			}
		}
		return a.repository.AppendChatExchange(ctx, userID, input.Content, reply.Text, replyBlocks(reply), mode)
	})
}

type saveChatFunc func(context.Context, chat.Reply, string) ([]domain.ChatMessage, error)

// chatMode reports whether a reply came from external AI. A provider that fell
// back to its deterministic summary marks the reply Basic.
func chatMode(provider chat.Provider, reply chat.Reply) string {
	if provider.Mode() == "deterministic" || reply.Basic {
		return "basic"
	}
	return "ai"
}

// runChat answers as JSON, or as server-sent events when the client asks for
// them, so it can show progress while the model and web tools work.
func (a *API) runChat(w http.ResponseWriter, r *http.Request, provider chat.Provider, prompt string, grounded chat.Context, save saveChatFunc) {
	if !strings.Contains(r.Header.Get("Accept"), "text/event-stream") {
		reply, err := provider.Reply(r.Context(), prompt, grounded)
		if err != nil {
			a.internalError(w, r, err)
			return
		}
		messages, err := save(r.Context(), reply, chatMode(provider, reply))
		if err != nil {
			a.internalError(w, r, err)
			return
		}
		writeData(w, http.StatusCreated, messages)
		return
	}

	stream := newChatStream(w)
	defer stream.close()
	stream.send("status", map[string]string{"stage": "thinking", "label": "Thinking…"})
	ctx := chat.WithProgress(r.Context(), func(stage, label string) {
		stream.send("status", map[string]string{"stage": stage, "label": label})
	})
	reply, err := provider.Reply(ctx, prompt, grounded)
	if errors.Is(r.Context().Err(), context.Canceled) {
		// The member stopped the request; nothing is saved.
		return
	}
	if err != nil {
		a.streamError(stream, r, err)
		return
	}
	messages, err := save(r.Context(), reply, chatMode(provider, reply))
	if err != nil {
		a.streamError(stream, r, err)
		return
	}
	stream.send("done", map[string]any{"data": messages})
}

func (a *API) streamError(stream *chatStream, r *http.Request, err error) {
	a.logger.ErrorContext(r.Context(), "chat stream failed", "request_id", requestIDFromContext(r.Context()), "error", err)
	code, message := "internal_error", "an internal error occurred"
	if errors.Is(err, context.DeadlineExceeded) {
		code, message = "request_timeout", "request processing timed out"
	}
	stream.send("error", map[string]any{"error": map[string]string{
		"code": code, "message": message, "request_id": requestIDFromContext(r.Context()),
	}})
}

// chatStream serialises event writes from the handler, the provider's
// progress callback and the keep-alive ticker.
type chatStream struct {
	mu         sync.Mutex
	w          http.ResponseWriter
	controller *http.ResponseController
	closed     bool
	stop       chan struct{}
	wait       sync.WaitGroup
}

func newChatStream(w http.ResponseWriter) *chatStream {
	header := w.Header()
	header.Set("Content-Type", "text/event-stream; charset=utf-8")
	header.Set("Cache-Control", "no-store")
	header.Set("X-Content-Type-Options", "nosniff")
	header.Set("X-Accel-Buffering", "no")
	w.WriteHeader(http.StatusOK)
	stream := &chatStream{w: w, controller: http.NewResponseController(w), stop: make(chan struct{})}
	stream.wait.Add(1)
	go func() {
		defer stream.wait.Done()
		ticker := time.NewTicker(chatKeepAlive)
		defer ticker.Stop()
		for {
			select {
			case <-stream.stop:
				return
			case <-ticker.C:
				stream.write(": keep-alive\n\n")
			}
		}
	}()
	return stream
}

func (s *chatStream) send(event string, data any) {
	encoded, err := json.Marshal(data)
	if err != nil {
		return
	}
	s.write(fmt.Sprintf("event: %s\ndata: %s\n\n", event, encoded))
}

func (s *chatStream) write(chunk string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.closed {
		return
	}
	if _, err := s.w.Write([]byte(chunk)); err != nil {
		return
	}
	_ = s.controller.Flush()
}

// close stops the keep-alive and blocks later writes; the handler must not
// write after it returns.
func (s *chatStream) close() {
	close(s.stop)
	s.wait.Wait()
	s.mu.Lock()
	s.closed = true
	s.mu.Unlock()
}
