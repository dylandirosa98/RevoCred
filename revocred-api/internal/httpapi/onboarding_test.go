package httpapi

import (
	"context"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/revocred/revocred-api/internal/auth"
	"github.com/revocred/revocred-api/internal/domain"
	"github.com/revocred/revocred-api/internal/store"
)

type onboardingRepository struct {
	fakeRepository
	previews, saves int
	err             error
	lastInput       domain.RecommendationInput
}

func (f *onboardingRepository) PreviewPlan(_ context.Context, input domain.RecommendationInput) (domain.Bootstrap, error) {
	f.previews++
	f.lastInput = input
	return domain.Bootstrap{}, f.err
}

func (f *onboardingRepository) SaveOnboarding(_ context.Context, _ string, input domain.RecommendationInput) (domain.RecommendationResult, error) {
	f.saves++
	f.lastInput = input
	return domain.RecommendationResult{}, f.err
}

const validPlan = `{"life_stage":"adult","monthly_category_spend":{"dining":30000},"fee_tolerance_cents":0,"ideal_card_count":"2-3","travel_scope":"none","rewards_goal":"cash_back","credit_tier":"good","existing_card_ids":[]}`

func onboardingHandler(repo *onboardingRepository) http.Handler {
	return New(repo, &fakeAuthenticator{user: auth.User{ID: "11111111-1111-4111-8111-111111111111"}}, fakeRecommender{}, fakeChatProvider{},
		slog.New(slog.NewTextHandler(io.Discard, nil)), nil, time.Second)
}

func TestOnboardingEndpoints(t *testing.T) {
	for _, test := range []struct {
		name, path, body, token string
		err                     error
		status, previews, saves int
	}{
		{name: "guest preview", path: "/v1/public/plan", body: validPlan, status: 200, previews: 1},
		{name: "older client without wallet size", path: "/v1/public/plan", body: strings.Replace(validPlan, `,"ideal_card_count":"2-3"`, ``, 1), status: 200, previews: 1},
		{name: "missing life stage", path: "/v1/public/plan", body: strings.Replace(validPlan, `"adult"`, `""`, 1), status: 422},
		{name: "non-UUID card", path: "/v1/public/plan", body: strings.Replace(validPlan, `[]`, `["demo-card"]`, 1), status: 422},
		{name: "unavailable card", path: "/v1/public/plan", body: validPlan, err: store.ErrNotFound, status: 422, previews: 1},
		{name: "save requires auth", path: "/v1/onboarding", body: validPlan, status: 401},
		{name: "authenticated save", path: "/v1/onboarding", body: validPlan, token: "token", status: 201, saves: 1},
	} {
		t.Run(test.name, func(t *testing.T) {
			repo := &onboardingRepository{err: test.err}
			r := httptest.NewRequest(http.MethodPost, test.path, strings.NewReader(test.body))
			if test.token != "" {
				r.Header.Set("Authorization", "Bearer "+test.token)
			}
			w := httptest.NewRecorder()
			onboardingHandler(repo).ServeHTTP(w, r)
			if w.Code != test.status || repo.previews != test.previews || repo.saves != test.saves {
				t.Fatalf("status %d previews %d saves %d: %s", w.Code, repo.previews, repo.saves, w.Body.String())
			}
			if test.previews+test.saves > 0 && test.err == nil && strings.Contains(test.body, "ideal_card_count") && repo.lastInput.IdealCardCount != "2-3" {
				t.Fatalf("ideal card count = %q, want 2-3", repo.lastInput.IdealCardCount)
			}
		})
	}
}

func TestOnboardingRejectsInvalidIdealCardCount(t *testing.T) {
	repo := &onboardingRepository{}
	body := strings.Replace(validPlan, `"2-3"`, `"all-of-them"`, 1)
	w := httptest.NewRecorder()
	onboardingHandler(repo).ServeHTTP(w, httptest.NewRequest(http.MethodPost, "/v1/public/plan", strings.NewReader(body)))
	if w.Code != http.StatusUnprocessableEntity || !strings.Contains(w.Body.String(), `"ideal_card_count"`) {
		t.Fatalf("status %d, body %s", w.Code, w.Body.String())
	}
}

func TestGuestPreviewIsRateLimited(t *testing.T) {
	repo := &onboardingRepository{}
	h := onboardingHandler(repo)
	status := 0
	for i := 0; i < 31; i++ {
		w := httptest.NewRecorder()
		h.ServeHTTP(w, httptest.NewRequest(http.MethodPost, "/v1/public/plan", strings.NewReader(validPlan)))
		status = w.Code
	}
	if status != http.StatusTooManyRequests || repo.previews != 30 {
		t.Fatalf("status %d after %d previews", status, repo.previews)
	}
}
