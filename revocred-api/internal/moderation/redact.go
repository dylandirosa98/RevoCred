package moderation

import (
	"regexp"
	"strings"
	"unicode"
)

var (
	urlCredsPattern   = regexp.MustCompile(`(?i)\b(?:https?|postgres(?:ql)?|redis|amqp|mysql|mongodb(?:\+srv)?)://[^\s/@]+:[^\s/@]+@[^\s]+`)
	bearerPattern     = regexp.MustCompile(`(?i)\bBearer\s+[A-Za-z0-9._~+/=-]{8,}`)
	jwtPattern        = regexp.MustCompile(`\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b`)
	secretKeyPattern  = regexp.MustCompile(`\b(?:sk-[A-Za-z0-9_-]{12,}|sb_(?:secret|publishable)_[A-Za-z0-9_-]{12,}|gh[pousr]_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16})\b`)
	emailPattern      = regexp.MustCompile(`[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}`)
	ssnPattern        = regexp.MustCompile(`\b\d{3}-\d{2}-\d{4}\b`)
	longDigitsPattern = regexp.MustCompile(`\b\d(?:[\d -]{11,22}\d)\b`)
)

// RedactSensitive replaces emails, credentials, tokens, API keys, SSNs, and
// payment-card-like digit sequences before displaying report text to operators.
func RedactSensitive(text string) string {
	if text == "" {
		return ""
	}
	out := urlCredsPattern.ReplaceAllString(text, "[redacted-url]")
	out = bearerPattern.ReplaceAllString(out, "Bearer [redacted-token]")
	out = jwtPattern.ReplaceAllString(out, "[redacted-token]")
	out = secretKeyPattern.ReplaceAllString(out, "[redacted-secret]")
	out = emailPattern.ReplaceAllString(out, "[redacted-email]")
	out = ssnPattern.ReplaceAllString(out, "[redacted-id]")
	out = longDigitsPattern.ReplaceAllStringFunc(out, func(match string) string {
		digits := 0
		for _, r := range match {
			if r >= '0' && r <= '9' {
				digits++
			}
		}
		if digits >= 13 && digits <= 19 {
			return "[redacted-number]"
		}
		return match
	})
	return out
}

// Snippet redacts sensitive content, collapses whitespace onto a single line,
// and truncates cleanly to maxRunes runes.
func Snippet(text string, maxRunes int) string {
	if maxRunes <= 0 {
		maxRunes = SnippetMaxRunes
	}
	redacted := RedactSensitive(text)
	collapsed := collapseWhitespace(redacted)
	if collapsed == "" {
		return ""
	}
	runes := []rune(collapsed)
	if len(runes) <= maxRunes {
		return collapsed
	}
	if maxRunes <= 3 {
		return string(runes[:maxRunes])
	}
	return strings.TrimRightFunc(string(runes[:maxRunes-3]), unicode.IsSpace) + "..."
}

func collapseWhitespace(s string) string {
	var b strings.Builder
	b.Grow(len(s))
	inSpace := true
	for _, r := range s {
		if unicode.IsSpace(r) {
			if !inSpace {
				b.WriteByte(' ')
				inSpace = true
			}
			continue
		}
		b.WriteRune(r)
		inSpace = false
	}
	return strings.TrimRight(b.String(), " ")
}
