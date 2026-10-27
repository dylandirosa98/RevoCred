package httpapi

import (
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/revocred/revocred-api/internal/auth"
	"github.com/revocred/revocred-api/internal/domain"
	"github.com/revocred/revocred-api/internal/purchaseguide"
)

func TestPurchaseGuideUsesAuthenticatedWalletNotGlobalCatalog(t *testing.T) {
	repository := &fakeRepository{cards: []domain.CatalogCard{{ID: "not-owned", Name: "Not owned", RewardRates: map[string]float64{"other": 99}}}, wallet: []domain.WalletCard{
		{Status: "active", Card: &domain.CatalogCard{ID: "owned", Name: "Owned 2 percent", RewardsType: "cash_back", RewardRates: map[string]float64{"other": 2}}},
	}}
	h := New(repository, &fakeAuthenticator{user: auth.User{ID: "member"}}, fakeRecommender{}, fakeChatProvider{}, slog.New(slog.NewTextHandler(io.Discard, nil)), nil, time.Second)
	req := httptest.NewRequest("GET", "/v1/purchase-guide", nil)
	req.Header.Set("Authorization", "Bearer valid-token")
	res := httptest.NewRecorder()
	h.ServeHTTP(res, req)
	if res.Code != 200 {
		t.Fatalf("status %d: %s", res.Code, res.Body)
	}
	var reply struct {
		Data struct {
			Categories []purchaseguide.Category `json:"categories"`
		} `json:"data"`
	}
	if err := json.Unmarshal(res.Body.Bytes(), &reply); err != nil {
		t.Fatal(err)
	}
	if len(reply.Data.Categories) != 16 {
		t.Fatal("category coverage incomplete")
	}
	for _, g := range reply.Data.Categories {
		for _, o := range g.Options {
			if o.CardID != "owned" {
				t.Fatal("unowned card recommended")
			}
		}
	}
	for _, path := range []string{"/v1/purchase-guide?travel_mode=not-real", "/v1/purchase-guide?caps_available=garbage"} {
		req := httptest.NewRequest("GET", path, nil)
		req.Header.Set("Authorization", "Bearer valid-token")
		res := httptest.NewRecorder()
		h.ServeHTTP(res, req)
		if res.Code != http.StatusBadRequest {
			t.Fatalf("invalid context accepted: %s => %d", path, res.Code)
		}
	}
	res = httptest.NewRecorder()
	h.ServeHTTP(res, httptest.NewRequest("GET", "/v1/purchase-guide", nil))
	if res.Code != http.StatusUnauthorized {
		t.Fatal("wallet guide exposed without auth")
	}
}
