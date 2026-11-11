package legal

import (
	"bytes"
	"net/http"
	"strings"
	"time"
)

// aliases redirect common alternative paths to the canonical page.
var aliases = map[string]string{
	"/privacy-policy": "/privacy",
	"/privacy/":       "/privacy",
	"/terms-of-use":   "/terms",
	"/terms/":         "/terms",
	"/support/":       "/support",
	"/legal/":         "/legal",
}

// IsPublicPath reports whether path is served by Handler. These pages are
// opened as top-level navigations from anywhere, so they skip CORS origin
// checks and authentication.
func IsPublicPath(path string) bool {
	if _, ok := aliases[path]; ok {
		return true
	}
	for _, page := range pages {
		if path == "/"+page.Slug {
			return true
		}
	}
	return false
}

// Register adds GET (and implicitly HEAD) routes for every page and alias.
func Register(mux *http.ServeMux) {
	for _, page := range pages {
		mux.Handle("GET /"+page.Slug, pageHandler(page))
	}
	for from, to := range aliases {
		target, pattern := to, "GET "+from
		if strings.HasSuffix(from, "/") {
			pattern += "{$}" // exact match, not a subtree
		}
		mux.HandleFunc(pattern, func(w http.ResponseWriter, r *http.Request) {
			setSecurityHeaders(w)
			http.Redirect(w, r, target, http.StatusPermanentRedirect)
		})
	}
}

func pageHandler(page Page) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		setSecurityHeaders(w)
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		// Short shared caching: content only changes on deploy, and the ETag
		// makes revalidation cheap.
		w.Header().Set("Cache-Control", "public, max-age=300")
		w.Header().Set("ETag", page.ETag)
		http.ServeContent(w, r, "", time.Time{}, bytes.NewReader(page.HTML))
	})
}

func setSecurityHeaders(w http.ResponseWriter) {
	h := w.Header()
	h.Set("Content-Security-Policy", ContentSecurityPolicy)
	h.Set("X-Content-Type-Options", "nosniff")
	h.Set("X-Frame-Options", "DENY")
	h.Set("Referrer-Policy", "strict-origin-when-cross-origin")
	h.Set("Strict-Transport-Security", "max-age=31536000")
	h.Set("Cross-Origin-Opener-Policy", "same-origin")
	h.Set("Permissions-Policy", "camera=(), microphone=(), geolocation=()")
}
