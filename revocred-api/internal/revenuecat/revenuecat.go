// Package revenuecat interprets RevenueCat webhook events and reads current
// subscriber state from the RevenueCat REST API. It decides nothing about
// recommendations; it only maps store events to REVO AI access.
package revenuecat

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"slices"
	"strings"
	"time"
)

// DefaultEntitlementID is the RevenueCat entitlement that unlocks REVO AI.
const DefaultEntitlementID = "revo_ai"

// DefaultBaseURL is RevenueCat's public REST API.
const DefaultBaseURL = "https://api.revenuecat.com"

var uuidPattern = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)

// ValidUserID reports whether id is a Supabase user id (a UUID). RevenueCat
// anonymous ids ($RCAnonymousID:...) never qualify.
func ValidUserID(id string) bool { return uuidPattern.MatchString(id) }

// Webhook is the RevenueCat webhook envelope.
type Webhook struct {
	APIVersion string `json:"api_version"`
	Event      Event  `json:"event"`
}

// Event holds the RevenueCat event fields REVO uses; others are ignored.
type Event struct {
	ID               string   `json:"id"`
	Type             string   `json:"type"`
	AppUserID        string   `json:"app_user_id"`
	EventTimestampMS int64    `json:"event_timestamp_ms"`
	ExpirationAtMS   *int64   `json:"expiration_at_ms"`
	ProductID        string   `json:"product_id"`
	NewProductID     string   `json:"new_product_id"`
	EntitlementIDs   []string `json:"entitlement_ids"`
	EntitlementID    string   `json:"entitlement_id"`
	Environment      string   `json:"environment"`
	Store            string   `json:"store"`
	TransferredFrom  []string `json:"transferred_from"`
	TransferredTo    []string `json:"transferred_to"`
	CancelReason     string   `json:"cancel_reason"`
}

// Sandbox reports whether the event came from a sandbox or TestFlight purchase.
func (e Event) Sandbox() bool { return strings.EqualFold(e.Environment, "SANDBOX") }

// EventAt is when RevenueCat produced the event.
func (e Event) EventAt() time.Time { return time.UnixMilli(e.EventTimestampMS).UTC() }

// HasEntitlement reports whether the event's product unlocks entitlement.
// RevenueCat leaves entitlement_ids empty for products mapped to none.
func (e Event) HasEntitlement(entitlement string) bool {
	return slices.Contains(e.EntitlementIDs, entitlement) || e.EntitlementID == entitlement
}

// Action is how an event changes one account's access.
type Action struct {
	UserID    string
	ExpiresAt time.Time
	ProductID string
}

// ErrIgnored marks an event that intentionally changes nothing.
var ErrIgnored = errors.New("event ignored")

// Plan maps an event to the access changes it implies. TRANSFER returns
// revocations for the previous owners; the new owners are returned in
// refresh, to be read from the REST API because the event has no expiry.
func Plan(e Event, entitlement string) (actions []Action, refresh []string, err error) {
	if e.ID == "" || e.EventTimestampMS <= 0 {
		return nil, nil, fmt.Errorf("event id and timestamp are required")
	}
	at := e.EventAt()
	switch e.Type {
	case "INITIAL_PURCHASE", "RENEWAL", "UNCANCELLATION", "PRODUCT_CHANGE", "CANCELLATION", "SUBSCRIPTION_EXTENDED", "TEMPORARY_ENTITLEMENT_GRANT":
		// CANCELLATION preserves the reported expiry; EXPIRATION revokes access.
		if !e.HasEntitlement(entitlement) {
			return nil, nil, ErrIgnored
		}
		if !ValidUserID(e.AppUserID) || e.ExpirationAtMS == nil {
			return nil, nil, ErrIgnored
		}
		product := e.ProductID
		if e.Type == "PRODUCT_CHANGE" && e.NewProductID != "" {
			product = e.NewProductID
		}
		expires := time.UnixMilli(*e.ExpirationAtMS).UTC()
		return []Action{{UserID: strings.ToLower(e.AppUserID), ExpiresAt: expires, ProductID: product}}, nil, nil
	case "EXPIRATION":
		if !e.HasEntitlement(entitlement) || !ValidUserID(e.AppUserID) {
			return nil, nil, ErrIgnored
		}
		// Access ends no later than the event, whatever expiry it reports.
		ends := at
		if e.ExpirationAtMS != nil && time.UnixMilli(*e.ExpirationAtMS).Before(at) {
			ends = time.UnixMilli(*e.ExpirationAtMS).UTC()
		}
		return []Action{{UserID: strings.ToLower(e.AppUserID), ExpiresAt: ends, ProductID: e.ProductID}}, nil, nil
	case "TRANSFER":
		for _, id := range e.TransferredFrom {
			if ValidUserID(id) {
				actions = append(actions, Action{UserID: strings.ToLower(id), ExpiresAt: at})
			}
		}
		for _, id := range e.TransferredTo {
			if ValidUserID(id) {
				refresh = append(refresh, strings.ToLower(id))
			}
		}
		if len(actions) == 0 && len(refresh) == 0 {
			return nil, nil, ErrIgnored
		}
		return actions, refresh, nil
	default:
		// TEST, BILLING_ISSUE, SUBSCRIPTION_PAUSED, NON_RENEWING_PURCHASE and
		// future types change nothing; a later event or refresh will.
		return nil, nil, ErrIgnored
	}
}

// Subscriber is the current state of one entitlement for one app user.
type Subscriber struct {
	Active    bool
	ExpiresAt time.Time
	ProductID string
	Sandbox   bool
}

// Client reads subscriber state with a RevenueCat secret API key.
type Client struct {
	APIKey  string
	BaseURL string
	HTTP    *http.Client
}

// Entitlement returns the entitlement's current state for appUserID. An
// entitlement without an expiry (lifetime) is reported inactive because REVO
// sells only a monthly subscription.
func (c *Client) Entitlement(ctx context.Context, appUserID, entitlement string) (Subscriber, error) {
	if c == nil || c.APIKey == "" {
		return Subscriber{}, errors.New("RevenueCat API is not configured")
	}
	base := strings.TrimRight(c.BaseURL, "/")
	if base == "" {
		base = DefaultBaseURL
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, base+"/v1/subscribers/"+url.PathEscape(appUserID), nil)
	if err != nil {
		return Subscriber{}, err
	}
	request.Header.Set("Authorization", "Bearer "+c.APIKey)
	request.Header.Set("Accept", "application/json")
	client := c.HTTP
	if client == nil {
		client = &http.Client{Timeout: 10 * time.Second}
	}
	response, err := client.Do(request)
	if err != nil {
		return Subscriber{}, err
	}
	defer func() { _ = response.Body.Close() }()
	if response.StatusCode != http.StatusOK {
		return Subscriber{}, fmt.Errorf("RevenueCat API returned %d", response.StatusCode)
	}
	var body struct {
		Subscriber struct {
			Entitlements map[string]struct {
				ExpiresDate       *time.Time `json:"expires_date"`
				ProductIdentifier string     `json:"product_identifier"`
			} `json:"entitlements"`
			Subscriptions map[string]struct {
				IsSandbox bool `json:"is_sandbox"`
			} `json:"subscriptions"`
		} `json:"subscriber"`
	}
	if err = json.NewDecoder(io.LimitReader(response.Body, 1<<20)).Decode(&body); err != nil {
		return Subscriber{}, fmt.Errorf("RevenueCat API response: %w", err)
	}
	value, ok := body.Subscriber.Entitlements[entitlement]
	if !ok || value.ExpiresDate == nil {
		return Subscriber{}, nil
	}
	return Subscriber{
		Active:    value.ExpiresDate.After(time.Now()),
		ExpiresAt: value.ExpiresDate.UTC(),
		ProductID: value.ProductIdentifier,
		Sandbox:   body.Subscriber.Subscriptions[value.ProductIdentifier].IsSandbox,
	}, nil
}
