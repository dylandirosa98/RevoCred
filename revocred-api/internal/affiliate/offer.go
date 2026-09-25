// Package affiliate holds commercial metadata only. The recommendation engine
// must never depend on this package or receive its data.
package affiliate

import (
	"errors"
	"net"
	"net/url"
	"regexp"
	"strings"
	"time"
)

const Disclosure = "We may earn a commission if you apply through this link. Compensation does not affect your ranking."

type Offer struct {
	ID      string    `json:"id"`
	CardID  string    `json:"card_id"`
	Network string    `json:"network"`
	EndsAt  time.Time `json:"ends_at"`
}

type Publication struct {
	CardID           string    `json:"card_id"`
	CatalogVersionID string    `json:"catalog_version_id"`
	Network          string    `json:"network"`
	DestinationURL   string    `json:"destination_url"`
	ReviewedBy       string    `json:"reviewed_by"`
	Approved         bool      `json:"approved"`
	StartsAt         time.Time `json:"starts_at"`
	EndsAt           time.Time `json:"ends_at"`
}

var uuid = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)
var publicHostname = regexp.MustCompile(`^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z][a-z0-9-]*[a-z0-9]$`)

func (p Publication) Validate(now time.Time) error {
	if !uuid.MatchString(p.CardID) || !uuid.MatchString(p.CatalogVersionID) {
		return errors.New("card_id and catalog_version_id must be UUIDs")
	}
	if strings.TrimSpace(p.Network) == "" || len(p.Network) > 100 || strings.TrimSpace(p.ReviewedBy) == "" || len(p.ReviewedBy) > 200 {
		return errors.New("network and reviewed_by are required and must fit their length limits")
	}
	if !p.Approved || p.StartsAt.IsZero() || !p.EndsAt.After(p.StartsAt) || !p.EndsAt.After(now) {
		return errors.New("explicit approval and a valid, unexpired offer window are required")
	}
	if !ValidDestination(p.DestinationURL) {
		return errors.New("destination_url must be a public HTTPS URL without credentials or a fragment")
	}
	return nil
}

// Destinations are operator-provisioned, never supplied by redirect callers.
// Reject local/IP endpoints and ambiguous URLs before storing and before use.
func ValidDestination(raw string) bool {
	if len(raw) > 4096 || strings.ContainsAny(raw, "\r\n\t\\ ") {
		return false
	}
	u, err := url.Parse(raw)
	if err != nil || u.Scheme != "https" || u.User != nil || u.Fragment != "" || u.Opaque != "" || (u.Port() != "" && u.Port() != "443") {
		return false
	}
	host := strings.ToLower(u.Hostname())
	return len(host) <= 253 && publicHostname.MatchString(host) && net.ParseIP(host) == nil &&
		!strings.HasSuffix(host, ".localhost") && !strings.HasSuffix(host, ".local") && !strings.HasSuffix(host, ".internal")
}

func ValidPlacement(value string) bool {
	return value == "recommendation" || value == "strategy" || value == "report"
}

type ReportRow struct {
	OfferID   string    `json:"offer_id"`
	CardName  string    `json:"card_name"`
	Network   string    `json:"network"`
	Approved  bool      `json:"approved"`
	EndsAt    time.Time `json:"ends_at"`
	Placement string    `json:"placement"`
	Clicks    int64     `json:"clicks"`
}
