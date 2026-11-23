package moderation

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"sync"
	"time"
)

const (
	// AlertEventName identifies privacy-minimized moderation report webhooks.
	AlertEventName = "revo.moderation_report"

	defaultWebhookTimeout     = 5 * time.Second
	defaultWebhookConcurrency = 8
)

var publicHostname = regexp.MustCompile(`^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z][a-z0-9-]*[a-z0-9]$`)

// Alert is the privacy-minimized webhook payload sent when a harmful or
// offensive report is submitted. It never carries raw user text, chat content,
// account identifiers, or email addresses.
type Alert struct {
	Event       string    `json:"event"`
	ReportID    string    `json:"report_id"`
	Reason      string    `json:"reason"`
	SubmittedAt time.Time `json:"submitted_at"`
}

// AlertReasonCategory classifies feedback into an alertable safety category.
// It returns "" for thumbs-up feedback and non-safety reasons so raw user text
// is never forwarded to external alert sinks.
func AlertReasonCategory(rating, reason string) string {
	if rating != "down" {
		return ""
	}
	lower := strings.ToLower(reason)
	hasHarmful := strings.Contains(lower, "harmful")
	hasOffensive := strings.Contains(lower, "offensive")
	switch {
	case hasHarmful && hasOffensive:
		return "harmful_or_offensive"
	case hasHarmful:
		return "harmful"
	case hasOffensive:
		return "offensive"
	default:
		return ""
	}
}

// ValidWebhookURL validates MODERATION_ALERT_WEBHOOK_URL. Only public HTTPS
// endpoints without embedded credentials, fragments, or non-443 ports are
// accepted.
func ValidWebhookURL(raw string) error {
	if raw == "" || len(raw) > 4096 || strings.ContainsAny(raw, "\r\n\t\\ ") {
		return errors.New("MODERATION_ALERT_WEBHOOK_URL must be a valid public HTTPS URL")
	}
	u, err := url.Parse(raw)
	if err != nil || u.Scheme != "https" || u.User != nil || u.Fragment != "" || u.Opaque != "" || (u.Port() != "" && u.Port() != "443") {
		return errors.New("MODERATION_ALERT_WEBHOOK_URL must be an HTTPS URL without credentials, fragments, or custom ports")
	}
	host := strings.ToLower(u.Hostname())
	if len(host) > 253 || !publicHostname.MatchString(host) || net.ParseIP(host) != nil ||
		strings.HasSuffix(host, ".localhost") || strings.HasSuffix(host, ".local") || strings.HasSuffix(host, ".internal") {
		return errors.New("MODERATION_ALERT_WEBHOOK_URL must use a public HTTPS hostname")
	}
	return nil
}

// WebhookNotifier delivers privacy-minimized alerts asynchronously with bounded
// concurrency, short timeouts, and non-blocking error logging.
type WebhookNotifier struct {
	endpoint string
	host     string
	client   *http.Client
	timeout  time.Duration
	logger   *slog.Logger
	sem      chan struct{}
	wg       sync.WaitGroup
}

// NewWebhookNotifier creates an async webhook notifier after validating the
// configured public HTTPS URL.
func NewWebhookNotifier(webhookURL string, logger *slog.Logger) (*WebhookNotifier, error) {
	if err := ValidWebhookURL(webhookURL); err != nil {
		return nil, err
	}
	client := &http.Client{
		Timeout: defaultWebhookTimeout,
		Transport: &http.Transport{
			DialContext: safeDialContext,
		},
		CheckRedirect: func(*http.Request, []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}
	return newWebhookNotifier(webhookURL, client, defaultWebhookTimeout, defaultWebhookConcurrency, logger)
}

func newWebhookNotifier(webhookURL string, client *http.Client, timeout time.Duration, concurrency int, logger *slog.Logger) (*WebhookNotifier, error) {
	u, err := url.Parse(webhookURL)
	if err != nil || u.Scheme != "https" || u.Hostname() == "" {
		return nil, errors.New("webhook URL must be HTTPS")
	}
	if logger == nil {
		logger = slog.New(slog.NewTextHandler(io.Discard, nil))
	}
	if timeout <= 0 {
		timeout = defaultWebhookTimeout
	}
	if concurrency <= 0 {
		concurrency = defaultWebhookConcurrency
	}
	if client == nil {
		client = &http.Client{
			Timeout: timeout,
			CheckRedirect: func(*http.Request, []*http.Request) error {
				return http.ErrUseLastResponse
			},
		}
	}
	return &WebhookNotifier{
		endpoint: webhookURL,
		host:     u.Hostname(),
		client:   client,
		timeout:  timeout,
		logger:   logger,
		sem:      make(chan struct{}, concurrency),
	}, nil
}

// NotifyReport schedules an asynchronous webhook POST without blocking the
// caller. Drops and logs a warning if in-flight alerts exceed bounded capacity.
func (w *WebhookNotifier) NotifyReport(alert Alert) {
	if w == nil {
		return
	}
	if alert.Event == "" {
		alert.Event = AlertEventName
	}
	if alert.SubmittedAt.IsZero() {
		alert.SubmittedAt = time.Now().UTC()
	} else {
		alert.SubmittedAt = alert.SubmittedAt.UTC()
	}
	select {
	case w.sem <- struct{}{}:
		w.wg.Add(1)
		go func() {
			defer w.wg.Done()
			defer func() { <-w.sem }()
			w.send(alert)
		}()
	default:
		w.logger.Warn("moderation alert webhook queue full; alert dropped",
			"report_id", alert.ReportID,
			"reason", alert.Reason,
			"host", w.host,
		)
	}
}

// Wait blocks until all scheduled in-flight alerts have completed.
func (w *WebhookNotifier) Wait() {
	if w == nil {
		return
	}
	w.wg.Wait()
}

func (w *WebhookNotifier) send(alert Alert) {
	body, err := json.Marshal(alert)
	if err != nil {
		w.logger.Warn("moderation alert marshal failed", "report_id", alert.ReportID, "reason", alert.Reason)
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), w.timeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, w.endpoint, bytes.NewReader(body))
	if err != nil {
		w.logger.Warn("moderation alert request build failed", "report_id", alert.ReportID, "reason", alert.Reason, "host", w.host)
		return
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("User-Agent", "revocred-api-moderation-alert")

	resp, err := w.client.Do(req)
	if err != nil {
		// Never log the raw error or full URL: webhook paths often embed secret tokens.
		w.logger.Warn("moderation alert webhook delivery failed",
			"report_id", alert.ReportID,
			"reason", alert.Reason,
			"host", w.host,
			"timeout", errors.Is(err, context.DeadlineExceeded),
		)
		return
	}
	defer func() {
		_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 4096))
		_ = resp.Body.Close()
	}()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		w.logger.Warn("moderation alert webhook returned non-2xx status",
			"report_id", alert.ReportID,
			"reason", alert.Reason,
			"host", w.host,
			"status", resp.StatusCode,
		)
	}
}

func safeDialContext(ctx context.Context, network, addr string) (net.Conn, error) {
	host, port, err := net.SplitHostPort(addr)
	if err != nil {
		return nil, err
	}
	ips, err := net.DefaultResolver.LookupIPAddr(ctx, host)
	if err != nil {
		return nil, err
	}
	dialer := &net.Dialer{Timeout: 3 * time.Second}
	for _, ip := range ips {
		if !isPublicIP(ip.IP) {
			return nil, errors.New("webhook destination resolved to a non-public IP address")
		}
	}
	for _, ip := range ips {
		conn, dialErr := dialer.DialContext(ctx, network, net.JoinHostPort(ip.IP.String(), port))
		if dialErr == nil {
			return conn, nil
		}
		err = dialErr
	}
	if err != nil {
		return nil, err
	}
	return nil, errors.New("no routable public IP address for webhook destination")
}

func isPublicIP(ip net.IP) bool {
	if ip == nil || ip.IsLoopback() || ip.IsPrivate() || ip.IsLinkLocalUnicast() ||
		ip.IsLinkLocalMulticast() || ip.IsMulticast() || ip.IsUnspecified() {
		return false
	}
	// Reject carrier-grade NAT (100.64.0.0/10) and IPv4-mapped non-public addresses.
	if v4 := ip.To4(); v4 != nil {
		if v4[0] == 100 && v4[1] >= 64 && v4[1] <= 127 {
			return false
		}
	}
	return true
}
