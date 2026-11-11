// Package legal serves RevoCred's public privacy policy, terms and support
// pages. The Markdown sources are copies of docs/legal (kept identical by a
// test; refresh with `make legal-sync`) embedded into the binary and rendered
// once at startup. The pages need no auth, database or network access.
package legal

import (
	"crypto/sha256"
	"embed"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"html"
	"regexp"
	"sort"
	"strings"
)

//go:embed content/*.md
var content embed.FS

// Page is one rendered public document.
type Page struct {
	Slug   string // URL path without the leading slash
	Title  string
	Source string // file name in docs/legal
	HTML   []byte
	ETag   string
}

type pageSpec struct{ slug, nav, source, summary string }

var specs = []pageSpec{
	{"privacy", "Privacy", "privacy-policy.md", "What RevoCred collects, who receives it and your choices."},
	{"terms", "Terms", "terms-of-use.md", "The rules for using RevoCred, REVO and the REVO AI subscription."},
	{"support", "Support", "support.md", "How to get help, export or delete your data, and contact us."},
}

// SourceFiles lists the docs/legal files embedded in the binary.
func SourceFiles() []string {
	files := make([]string, len(specs))
	for i, spec := range specs {
		files[i] = spec.source
	}
	return files
}

var placeholderPattern = regexp.MustCompile(`\[\[[^\]]+\]\]`)

// style is inline so the pages load no external assets; the CSP allows exactly
// this block by hash.
const style = `:root{color-scheme:light dark;--bg:#fafcfb;--fg:#172a31;--muted:#4a5f66;--link:#086353;--line:#bdccc7}` +
	`@media (prefers-color-scheme:dark){:root{--bg:#0f1a1d;--fg:#e6efed;--muted:#a9bbb7;--link:#6fd3bd;--line:#2c3f43}}` +
	`*{box-sizing:border-box}html{-webkit-text-size-adjust:100%}` +
	`body{margin:0;background:var(--bg);color:var(--fg);font:1.0625rem/1.65 -apple-system,BlinkMacSystemFont,"Segoe UI",system-ui,sans-serif}` +
	`.wrap{max-width:46rem;margin:0 auto;padding:1.5rem 1rem 3rem}` +
	`header{display:flex;flex-wrap:wrap;align-items:baseline;justify-content:space-between;gap:.5rem 1.5rem;border-bottom:1px solid var(--line);padding-bottom:1rem}` +
	`.brand{font-weight:800;font-size:1.25rem;color:var(--fg);text-decoration:none}` +
	`nav ul{display:flex;flex-wrap:wrap;gap:.25rem 1.25rem;list-style:none;margin:0;padding:0}` +
	`a{color:var(--link);text-underline-offset:.15em}a:focus-visible{outline:3px solid var(--link);outline-offset:2px;border-radius:2px}` +
	`nav a{display:inline-block;padding:.5rem 0}nav a[aria-current=page]{font-weight:700;color:var(--fg)}` +
	`h1,h2,h3{line-height:1.25}h1{font-size:2rem;margin:1.5rem 0 .5rem}h2{font-size:1.35rem;margin-top:2rem}` +
	`li{margin:.35rem 0}.table{overflow-x:auto}table{border-collapse:collapse;width:100%;font-size:.95rem}` +
	`th,td{border:1px solid var(--line);padding:.5rem;text-align:left;vertical-align:top}` +
	`footer{margin-top:3rem;border-top:1px solid var(--line);padding-top:1rem;color:var(--muted);font-size:.9rem}` +
	`.skip{position:absolute;left:-999px}.skip:focus{left:1rem;top:1rem;background:var(--bg);padding:.5rem}`

var styleHash = func() string {
	sum := sha256.Sum256([]byte(style))
	return "'sha256-" + base64.StdEncoding.EncodeToString(sum[:]) + "'"
}()

// ContentSecurityPolicy allows nothing but the embedded stylesheet.
var ContentSecurityPolicy = "default-src 'none'; style-src " + styleHash +
	"; base-uri 'none'; form-action 'none'; frame-ancestors 'none'"

var pages, placeholders = mustBuild()

// Pages returns the rendered documents plus the /legal index.
func Pages() []Page { return pages }

// Placeholders lists the unresolved [[OWNER FACT]] markers still in the pages.
func Placeholders() []string { return placeholders }

func mustBuild() ([]Page, []string) {
	built, unresolved, err := build()
	if err != nil {
		panic(err)
	}
	return built, unresolved
}

func build() ([]Page, []string, error) {
	found := map[string]struct{}{}
	result := make([]Page, 0, len(specs)+1)
	var index strings.Builder
	index.WriteString("<h1>RevoCred policies and support</h1>\n<ul>\n")
	for _, spec := range specs {
		source, err := content.ReadFile("content/" + spec.source)
		if err != nil {
			return nil, nil, err
		}
		text := strings.ReplaceAll(string(source), "\r\n", "\n")
		title := documentTitle(text)
		if title == "" {
			return nil, nil, fmt.Errorf("%s has no # title", spec.source)
		}
		for _, marker := range placeholderPattern.FindAllString(text, -1) {
			found[marker] = struct{}{}
		}
		result = append(result, newPage(spec.slug, title, spec.source, renderMarkdown(text)))
		fmt.Fprintf(&index, "<li><a href=\"/%s\">%s</a>. %s</li>\n", spec.slug, html.EscapeString(title), html.EscapeString(spec.summary))
	}
	index.WriteString("</ul>\n<p>Contact: <a href=\"mailto:support@revocred.com\">support@revocred.com</a></p>")
	result = append(result, newPage("legal", "RevoCred policies and support", "", index.String()))
	unresolved := make([]string, 0, len(found))
	for marker := range found {
		unresolved = append(unresolved, marker)
	}
	sort.Strings(unresolved)
	return result, unresolved, nil
}

func documentTitle(source string) string {
	for _, line := range strings.Split(source, "\n") {
		if strings.HasPrefix(line, "# ") {
			return strings.TrimSpace(line[2:])
		}
	}
	return ""
}

func newPage(slug, title, source, body string) Page {
	var nav strings.Builder
	nav.WriteString(`<nav aria-label="Policies and support"><ul>`)
	for _, spec := range specs {
		current := ""
		if spec.slug == slug {
			current = ` aria-current="page"`
		}
		fmt.Fprintf(&nav, `<li><a href="/%s"%s>%s</a></li>`, spec.slug, current, spec.nav)
	}
	nav.WriteString(`</ul></nav>`)
	document := `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light dark">
<meta name="referrer" content="strict-origin-when-cross-origin">
<title>` + html.EscapeString(title) + `</title>
<style>` + style + `</style>
</head>
<body>
<a class="skip" href="#main">Skip to content</a>
<div class="wrap">
<header><a class="brand" href="/legal">RevoCred</a>` + nav.String() + `</header>
<main id="main">
` + body + `
</main>
<footer><p>Questions? Email <a href="mailto:support@revocred.com">support@revocred.com</a>.</p></footer>
</div>
</body>
</html>
`
	sum := sha256.Sum256([]byte(document))
	return Page{Slug: slug, Title: title, Source: source, HTML: []byte(document), ETag: `"` + hex.EncodeToString(sum[:8]) + `"`}
}
