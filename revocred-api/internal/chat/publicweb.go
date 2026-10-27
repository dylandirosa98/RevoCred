package chat

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"os/exec"
	"regexp"
	"sort"
	"strings"
	"time"
)

// Only public HTTPS, standard port, without credentials, query strings or
// fragments. Query strings are deliberately excluded to prevent identifier
// leakage via a model-generated URL. Search uses its own fixed endpoint.
func publicURL(raw string) (*url.URL, error) {
	u, err := url.Parse(raw)
	if err != nil || len(raw) > 2048 || u.Scheme != "https" || u.User != nil || u.Host == "" || (u.Port() != "" && u.Port() != "443") || u.RawQuery != "" || u.Fragment != "" {
		return nil, errors.New("only public HTTPS URLs without credentials or query parameters are allowed")
	}
	host := strings.TrimSuffix(strings.ToLower(u.Hostname()), ".")
	if !strings.Contains(host, ".") || host == "localhost" || strings.HasSuffix(host, ".localhost") || strings.HasSuffix(host, ".local") || strings.HasSuffix(host, ".internal") {
		return nil, errors.New("private hostname")
	}
	if ip := net.ParseIP(host); ip != nil && !publicIP(ip) {
		return nil, errors.New("private IP")
	}
	return u, nil
}
func publicIP(ip net.IP) bool {
	if ip == nil || !ip.IsGlobalUnicast() || ip.IsPrivate() || ip.IsLoopback() || ip.IsLinkLocalUnicast() || ip.IsUnspecified() {
		return false
	}
	for _, cidr := range []string{"0.0.0.0/8", "100.64.0.0/10", "192.0.0.0/24", "192.0.2.0/24", "198.18.0.0/15", "198.51.100.0/24", "203.0.113.0/24", "240.0.0.0/4", "2001:db8::/32", "2001::/32", "2002::/16", "64:ff9b::/96"} {
		_, block, _ := net.ParseCIDR(cidr)
		if block.Contains(ip) {
			return false
		}
	}
	return true
}
func publicHTTPClient() *http.Client {
	transport := &http.Transport{TLSHandshakeTimeout: 4 * time.Second, ResponseHeaderTimeout: 6 * time.Second, MaxIdleConns: 4, IdleConnTimeout: 20 * time.Second}
	transport.DialContext = func(ctx context.Context, network, address string) (net.Conn, error) {
		host, port, err := net.SplitHostPort(address)
		if err != nil || port != "443" {
			return nil, errors.New("invalid public address")
		}
		ips, err := net.DefaultResolver.LookupIPAddr(ctx, host)
		if err != nil || len(ips) == 0 {
			return nil, errors.New("DNS lookup failed")
		}
		for _, entry := range ips {
			if !publicIP(entry.IP) {
				return nil, errors.New("DNS resolved to a non-public address")
			}
		}
		// Dial a validated literal IP, not the hostname (DNS rebinding protection).
		return (&net.Dialer{Timeout: 4 * time.Second}).DialContext(ctx, network, net.JoinHostPort(ips[0].IP.String(), port))
	}
	return &http.Client{Timeout: 8 * time.Second, Transport: transport, CheckRedirect: func(req *http.Request, via []*http.Request) error {
		if len(via) >= 3 {
			return errors.New("redirect limit")
		}
		_, err := publicURL(req.URL.String())
		return err
	}}
}
func fetchPublicPage(ctx context.Context, raw string) (string, error) {
	u, err := publicURL(raw)
	if err != nil {
		return "", err
	}
	client := publicHTTPClient()
	defer client.CloseIdleConnections()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u.String(), nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("User-Agent", "RevoCred/1.0 public research")
	req.Header.Set("Accept", "text/html,application/pdf,text/plain")
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return "", fmt.Errorf("page returned %d", resp.StatusCode)
	}
	data, err := io.ReadAll(io.LimitReader(resp.Body, (2<<20)+1))
	if err != nil {
		return "", err
	}
	if len(data) > 2<<20 {
		return "", errors.New("page too large")
	}
	contentType := strings.ToLower(resp.Header.Get("Content-Type"))
	if strings.Contains(contentType, "application/pdf") || bytes.HasPrefix(data, []byte("%PDF-")) {
		// Optional runtime support: no shell, no URL handed to an external program.
		cmd := exec.CommandContext(ctx, "pdftotext", "-layout", "-", "-")
		cmd.Stdin = bytes.NewReader(data)
		out := &limitedTextBuffer{}
		cmd.Stdout = out
		if err := cmd.Run(); err != nil {
			return "", errors.New("PDF text extraction unavailable")
		}
		return out.String(), nil
	}
	if !strings.Contains(contentType, "text/html") && !strings.Contains(contentType, "text/plain") && !strings.Contains(contentType, "application/xhtml+xml") {
		return "", errors.New("unsupported page type")
	}
	return string(data), nil
}

type limitedTextBuffer struct{ bytes.Buffer }

func (b *limitedTextBuffer) Write(p []byte) (int, error) {
	if b.Len()+len(p) > 2<<20 {
		return 0, errors.New("extracted text too large")
	}
	return b.Buffer.Write(p)
}

// Pick relevant windows across the document, rather than the first few
// marketing sentences. This handles HTML and text extracted from PDF guides.
func targetedWebExcerpt(page, topic string) string {
	text := plainWebText(page)
	if len(text) <= 9000 {
		return text
	}
	words := promptContentWords(topic)
	type window struct{ start, end, score int }
	candidates := []window{}
	for start := 0; start < len(text); start += 650 {
		end := start + 1300
		if end > len(text) {
			end = len(text)
		}
		lower := strings.ToLower(text[start:end])
		score := 0
		for _, word := range words {
			score += strings.Count(lower, word)
		}
		candidates = append(candidates, window{start, end, score})
	}
	sort.SliceStable(candidates, func(i, j int) bool { return candidates[i].score > candidates[j].score })
	chosen := []window{}
	used := map[int]bool{}
	for _, w := range candidates {
		if len(chosen) >= 5 {
			break
		}
		if used[w.start/650] || used[w.start/650-1] || used[w.start/650+1] {
			continue
		}
		chosen = append(chosen, w)
		used[w.start/650] = true
	}
	sort.Slice(chosen, func(i, j int) bool { return chosen[i].start < chosen[j].start })
	parts := []string{}
	for _, w := range chosen {
		parts = append(parts, text[w.start:w.end])
	}
	return strings.Join(parts, "\n[…]\n")
}

var sensitiveToolPattern = regexp.MustCompile(`(?i)@|https?://|\b[0-9a-f]{8}-[0-9a-f]{4}-|\b\d{3}-\d{2}-\d{4}\b|(?:\d[ -]?){7,}|\$\s*\d|\b(?:password|passcode|cvv|cvc|social security|ssn|access.token|api.key|account.number)\b`)

func privateToolQuery(query string, facts snapshot) bool {
	if sensitiveToolPattern.MatchString(query) {
		return true
	}
	if name := strings.ToLower(strings.TrimSpace(facts.Member.FirstName)); len(name) >= 2 {
		for _, word := range strings.Fields(strings.ToLower(query)) {
			if strings.Trim(word, ".,:;!?\"'") == name {
				return true
			}
		}
	}
	return false
}
