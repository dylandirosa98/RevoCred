// Package carddata supplies attributed, community-maintained product details.
// It never changes server-owned scoring terms or recommendations.
package carddata

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"sort"
	"strings"
	"sync"
	"time"
)

const SourceURL = "https://raw.githubusercontent.com/thedavidweng/opencard-db/main/exports/cards-all.json"
const ProjectURL = "https://github.com/thedavidweng/opencard-db"
const LicenseURL = "https://creativecommons.org/licenses/by/4.0/"
const RefreshInterval = 24 * time.Hour
const maxBody = 16 << 20

func validIssuerURL(value, product string) bool {
	u, err := url.Parse(value)
	if err != nil || u.Scheme != "https" || u.User != nil || u.Port() != "" {
		return false
	}
	host := strings.ToLower(u.Hostname())
	bank := ""
	switch {
	case strings.HasPrefix(product, "us-amex-"):
		bank = "americanexpress.com"
	case strings.HasPrefix(product, "us-capital-one-"):
		bank = "capitalone.com"
	case strings.HasPrefix(product, "us-chase-"):
		bank = "chase.com"
	case strings.HasPrefix(product, "us-citi-"):
		bank = "citi.com"
	default:
		return false
	}
	return host == bank || strings.HasSuffix(host, "."+bank)
}

// Bind stable public catalog IDs to exact products. Never fuzzy-match accounts,
// student/business/secured variants, or add new recommendation candidates.
// The quicksilver row is the base Quicksilver (excellent credit), re-sourced
// to the base issuer page in migration 000025, bound to us-capital-one-quicksilver.
var bindings = map[string]string{
	"20000000-0000-4000-8000-000000000007": "us-capital-one-savor-student-cash-rewards",
	"20000000-0000-4000-8000-000000000008": "us-capital-one-quicksilver",
	"20000000-0000-4000-8000-000000000009": "us-chase-freedom-rise",
	"20000000-0000-4000-8000-000000000010": "us-chase-freedom-flex",
	"20000000-0000-4000-8000-000000000011": "us-chase-freedom-unlimited",
	"20000000-0000-4000-8000-000000000012": "us-chase-sapphire-preferred",
	"20000000-0000-4000-8000-000000000013": "us-chase-sapphire-reserve",
	"20000000-0000-4000-8000-000000000014": "us-capital-one-savorone",
	"20000000-0000-4000-8000-000000000015": "us-capital-one-venture-x",
	"20000000-0000-4000-8000-000000000016": "us-amex-gold",
	"20000000-0000-4000-8000-000000000017": "us-amex-platinum",
	"20000000-0000-4000-8000-000000000018": "us-citi-double-cash",
	"20000000-0000-4000-8000-000000000019": "us-citi-strata",
	"20000000-0000-4000-8000-000000000020": "us-citi-strata-elite",
}

type Category struct {
	Label           string          `json:"label"`
	PointsPerDollar *float64        `json:"points_per_dollar"`
	Cap             json.RawMessage `json:"cap"`
}
type Rewards struct {
	Currency      string `json:"currency"`
	CurrencyLabel string `json:"currency_label"`
	RateType      string `json:"rate_type"`
	BaseRate      struct {
		PointsPerDollar *float64 `json:"points_per_dollar"`
		Description     string   `json:"description"`
	} `json:"base_rate"`
	Categories      []Category `json:"categories"`
	RedemptionNotes string     `json:"redemption_notes"`
}
type Card struct {
	ID           string `json:"id"`
	Name         string `json:"name"`
	Country      string `json:"country"`
	Status       string `json:"status"`
	OfficialURL  string `json:"official_url"`
	LastVerified string `json:"last_verified"`
	AnnualFee    struct {
		Amount   *float64 `json:"amount"`
		Currency string   `json:"currency"`
	} `json:"annual_fee"`
	Rewards  Rewards `json:"rewards"`
	Benefits []struct {
		Title       string         `json:"title"`
		Description string         `json:"description"`
		Details     map[string]any `json:"details"`
	} `json:"benefits"`
	SignupBonus json.RawMessage `json:"signup_bonus"`
	TravelPerks json.RawMessage `json:"travel_perks"`
	Sources     []string        `json:"sources"`
	Notes       string          `json:"notes"`
}

// Details is supplemental display/reference evidence, never issuer-verified
// RevoCred scoring data. Keep raw reward conditions and bonus evidence separate.
type Details struct {
	ID              string          `json:"id"`
	Name            string          `json:"name"`
	Attribution     string          `json:"attribution"`
	SourceURL       string          `json:"source_url"`
	LicenseURL      string          `json:"license_url"`
	IssuerURL       string          `json:"issuer_url"`
	LastVerified    string          `json:"last_verified"`
	RetrievedAt     time.Time       `json:"retrieved_at"`
	SnapshotSHA256  string          `json:"snapshot_sha256"`
	CurrencyLabel   string          `json:"currency_label"`
	RewardRates     []string        `json:"reward_rates"`
	Benefits        []string        `json:"benefits"`
	Rewards         Rewards         `json:"rewards"`
	WelcomeOffer    json.RawMessage `json:"welcome_offer,omitempty"`
	TravelPerks     json.RawMessage `json:"travel_perks,omitempty"`
	SourceAnnualFee *float64        `json:"source_annual_fee"`
	Sources         []string        `json:"sources"`
	Notes           string          `json:"notes"`
	Warning         string          `json:"warning"`
}
type Persistence interface {
	LoadCardData(context.Context) ([]byte, time.Time, string, error)
	SaveCardData(context.Context, []byte, string, time.Time) error
}
type Cache struct {
	mu        sync.RWMutex
	refreshMu sync.Mutex
	cards     map[string]*Details
	checked   time.Time
	client    *http.Client
	store     Persistence
	url       string
}

func New(client *http.Client, store Persistence, url string) *Cache {
	if url == "" {
		url = SourceURL
	}
	if client == nil {
		client = &http.Client{Timeout: 20 * time.Second}
	}
	return &Cache{client: client, store: store, url: url, cards: map[string]*Details{}}
}
func (c *Cache) Get(catalogID string) *Details {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.cards[catalogID]
}
func (c *Cache) Load(ctx context.Context) error {
	body, at, sourceHash, err := c.store.LoadCardData(ctx)
	if err != nil {
		return err
	}
	if len(body) == 0 {
		return nil
	}
	cards, err := decode(body, at)
	if err != nil {
		return err
	}
	// PostgreSQL JSONB normalizes whitespace/key order. The saved digest is
	// provenance of the actual fetched source bytes, not the DB serialization.
	if decoded, err := hex.DecodeString(sourceHash); err != nil || len(decoded) != sha256.Size {
		return fmt.Errorf("invalid persisted source digest")
	}
	for _, d := range cards {
		d.SnapshotSHA256 = sourceHash
	}
	c.mu.Lock()
	c.cards = cards
	c.checked = at
	c.mu.Unlock()
	return nil
}
func (c *Cache) Refresh(ctx context.Context) error {
	c.refreshMu.Lock()
	defer c.refreshMu.Unlock()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.url, nil)
	if err != nil {
		return err
	}
	req.Header.Set("User-Agent", "RevoCred/1.0 (OpenCard DB catalog integration)")
	res, err := c.client.Do(req)
	if err != nil {
		return fmt.Errorf("fetch OpenCard: %w", err)
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return fmt.Errorf("OpenCard returned HTTP %d", res.StatusCode)
	}
	body, err := io.ReadAll(io.LimitReader(res.Body, maxBody+1))
	if err != nil {
		return err
	}
	if len(body) > maxBody {
		return fmt.Errorf("OpenCard response exceeds size limit")
	}
	at := time.Now().UTC()
	cards, err := decode(body, at)
	if err != nil {
		return err
	}
	hash := sha256.Sum256(body)
	if err := c.store.SaveCardData(ctx, body, hex.EncodeToString(hash[:]), at); err != nil {
		return fmt.Errorf("persist OpenCard cache: %w", err)
	}
	c.mu.Lock()
	c.cards = cards
	c.checked = at
	c.mu.Unlock()
	return nil
}

// Run refreshes outside request handling; failed fetches retain the DB-backed
// last-known-good snapshot and retry in an hour. Requests never depend on GitHub.
func (c *Cache) Run(ctx context.Context, report func(error)) {
	for {
		c.mu.RLock()
		due := c.checked.IsZero() || time.Since(c.checked) >= RefreshInterval
		c.mu.RUnlock()
		delay := RefreshInterval
		if due {
			call, cancel := context.WithTimeout(ctx, 30*time.Second)
			err := c.Refresh(call)
			cancel()
			if err != nil {
				if report != nil {
					report(err)
				}
				delay = time.Hour
			}
		} else {
			c.mu.RLock()
			delay = time.Until(c.checked.Add(RefreshInterval))
			c.mu.RUnlock()
		}
		timer := time.NewTimer(delay)
		select {
		case <-ctx.Done():
			timer.Stop()
			return
		case <-timer.C:
		}
	}
}
func decode(body []byte, at time.Time) (map[string]*Details, error) {
	var records []Card
	if err := json.Unmarshal(body, &records); err != nil {
		return nil, fmt.Errorf("invalid OpenCard JSON: %w", err)
	}
	indexed := map[string]Card{}
	for _, r := range records {
		if _, ok := indexed[r.ID]; ok {
			return nil, fmt.Errorf("duplicate OpenCard id %s", r.ID)
		}
		indexed[r.ID] = r
	}
	hash := sha256.Sum256(body)
	result := map[string]*Details{}
	for local, external := range bindings {
		r, ok := indexed[external]
		if !ok || r.Country != "us" || r.Status != "active" || r.AnnualFee.Currency != "USD" || r.AnnualFee.Amount == nil || *r.AnnualFee.Amount < 0 || r.Name == "" {
			return nil, fmt.Errorf("OpenCard product missing or invalid: %s", external)
		}
		if date, err := time.Parse("2006-01-02", r.LastVerified); err != nil || date.After(at.Add(24*time.Hour)) {
			return nil, fmt.Errorf("invalid verification date for %s", external)
		}
		if !validIssuerURL(r.OfficialURL, external) {
			return nil, fmt.Errorf("invalid issuer URL for %s", external)
		}
		if r.Rewards.BaseRate.PointsPerDollar == nil || *r.Rewards.BaseRate.PointsPerDollar < 0 || *r.Rewards.BaseRate.PointsPerDollar > 100 {
			return nil, fmt.Errorf("missing or invalid base reward rate for %s", external)
		}
		switch r.Rewards.RateType {
		case "points_multiplier", "miles_multiplier", "cashback_percent":
		default:
			return nil, fmt.Errorf("unsupported reward units for %s", external)
		}
		d := &Details{ID: r.ID, Name: r.Name, Attribution: "OpenCard DB · CC BY 4.0 · adapted for display", SourceURL: ProjectURL, LicenseURL: LicenseURL, IssuerURL: r.OfficialURL, LastVerified: r.LastVerified, RetrievedAt: at, SnapshotSHA256: hex.EncodeToString(hash[:]), CurrencyLabel: r.Rewards.CurrencyLabel, Rewards: r.Rewards, WelcomeOffer: r.SignupBonus, TravelPerks: r.TravelPerks, SourceAnnualFee: r.AnnualFee.Amount, Sources: r.Sources, Notes: r.Notes, RewardRates: []string{}, Benefits: []string{}, Warning: "Community-maintained snapshot; may be incomplete or outdated. Verify current issuer terms. Conditional credits, welcome offers and portal rates are not included in RevoCred estimates."}
		unit := "x"
		if r.Rewards.RateType == "cashback_percent" {
			unit = "%"
		}
		if r.Rewards.BaseRate.PointsPerDollar != nil {
			d.RewardRates = append(d.RewardRates, fmt.Sprintf("%g%s — %s", *r.Rewards.BaseRate.PointsPerDollar, unit, r.Rewards.BaseRate.Description))
		}
		for _, rate := range r.Rewards.Categories {
			if rate.PointsPerDollar == nil {
				continue
			}
			if *rate.PointsPerDollar < 0 || *rate.PointsPerDollar > 100 {
				return nil, fmt.Errorf("invalid reward rate for %s", external)
			}
			text := fmt.Sprintf("%g%s — %s", *rate.PointsPerDollar, unit, rate.Label)
			if len(rate.Cap) > 0 && string(rate.Cap) != "null" {
				text += " · cap: " + string(rate.Cap)
			}
			d.RewardRates = append(d.RewardRates, text)
		}
		for _, benefit := range r.Benefits {
			text := strings.TrimSpace(benefit.Title)
			if benefit.Description != "" {
				text += " — " + benefit.Description
			}
			keys := make([]string, 0, len(benefit.Details))
			for k := range benefit.Details {
				keys = append(keys, k)
			}
			sort.Strings(keys)
			for _, k := range keys {
				text += fmt.Sprintf(" · %s: %v", strings.ReplaceAll(k, "_", " "), benefit.Details[k])
			}
			if text != "" {
				d.Benefits = append(d.Benefits, text)
			}
		}
		result[local] = d
	}
	return result, nil
}
