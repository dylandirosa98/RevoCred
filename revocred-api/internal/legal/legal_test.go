package legal

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// The API embeds copies because Railway builds from revocred-api/ only.
func TestEmbeddedSourcesMatchDocs(t *testing.T) {
	docs := filepath.Join("..", "..", "..", "docs", "legal")
	if _, err := os.Stat(docs); err != nil {
		t.Skip("docs/legal is not available in this checkout")
	}
	for _, name := range SourceFiles() {
		want, err := os.ReadFile(filepath.Join(docs, name))
		if err != nil {
			t.Fatal(err)
		}
		got, err := content.ReadFile("content/" + name)
		if err != nil {
			t.Fatal(err)
		}
		if !bytes.Equal(got, want) {
			t.Errorf("internal/legal/content/%s differs from docs/legal/%s; run `make legal-sync`", name, name)
		}
	}
}

func TestPagesRenderRequiredContent(t *testing.T) {
	bySlug := map[string]Page{}
	for _, page := range Pages() {
		bySlug[page.Slug] = page
	}
	required := map[string][]string{
		"privacy": {
			"same or equal protection", "OpenAI", "OpenCode", "Brave Search", "moderation",
			"Supabase", "Railway", "Resend", "RevenueCat", "18 or older", "United States",
			"Delete my account", "not financial", "<table>",
		},
		"terms": {
			"18 years old", "United States", "not</strong> financial", "Apple ID",
			"24 hours before the end of the current period", "Settings → [your name] → Subscriptions",
			"third-party beneficiaries",
		},
		"support": {"support@revocred.com", "Delete my account", "Report", "Subscriptions"},
	}
	for slug, phrases := range required {
		page, ok := bySlug[slug]
		if !ok {
			t.Fatalf("missing page %s", slug)
		}
		text := string(page.HTML)
		for _, phrase := range phrases {
			if !strings.Contains(text, phrase) {
				t.Errorf("%s page is missing %q", slug, phrase)
			}
		}
		for _, stale := range []string{"DuckDuckGo", "revocred.app", "{{", "[OWNER"} {
			if strings.Contains(text, stale) {
				t.Errorf("%s page still contains %q", slug, stale)
			}
		}
	}
	if _, ok := bySlug["legal"]; !ok {
		t.Fatal("missing /legal index")
	}
}

func TestPlaceholdersAreListed(t *testing.T) {
	readme, err := os.ReadFile(filepath.Join("..", "..", "..", "docs", "legal", "README.md"))
	if err != nil {
		t.Skip("docs/legal/README.md is not available in this checkout")
	}
	for _, marker := range Placeholders() {
		if !strings.Contains(string(readme), marker) {
			t.Errorf("placeholder %s is not listed in docs/legal/README.md", marker)
		}
	}
}

func TestRenderMarkdownEscapesAndLinks(t *testing.T) {
	got := renderMarkdown(strings.Join([]string{
		"# Title <b>",
		"",
		"A **bold** [mail](mailto:a@b.test) [rel](/terms) [bad](javascript:alert(1)) [proto](//evil.test) <script>x</script>",
		"wrapped line",
		"",
		"- item & one",
		"- [x](https://example.test/a?b=1&c=2)",
		"",
		"| A | B |",
		"| --- | --- |",
		"| 1 | <i> |",
	}, "\n"))
	for _, want := range []string{
		"<h1>Title &lt;b&gt;</h1>",
		"<strong>bold</strong>",
		`<a href="mailto:a@b.test">mail</a>`,
		`<a href="/terms">rel</a>`,
		"[bad](javascript:alert(1))",
		"[proto](//evil.test)",
		"&lt;script&gt;x&lt;/script&gt; wrapped line</p>",
		"<li>item &amp; one</li>",
		`<a href="https://example.test/a?b=1&amp;c=2">x</a>`,
		`<th scope="col">A</th>`,
		"<td>&lt;i&gt;</td>",
	} {
		if !strings.Contains(got, want) {
			t.Errorf("rendered HTML is missing %q:\n%s", want, got)
		}
	}
	if strings.Contains(got, "<script>") || strings.Contains(got, `href="javascript`) {
		t.Fatalf("unsafe markup rendered:\n%s", got)
	}
}

func TestExportWritesStaticSite(t *testing.T) {
	dir := t.TempDir()
	if len(Placeholders()) > 0 {
		if err := Export(filepath.Join(dir, "blocked"), false); err == nil {
			t.Fatal("export must refuse unresolved placeholders")
		}
	}
	out := filepath.Join(dir, "site")
	if err := Export(out, true); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"index.html", "privacy/index.html", "terms/index.html", "support/index.html"} {
		if _, err := os.Stat(filepath.Join(out, name)); err != nil {
			t.Errorf("missing %s: %v", name, err)
		}
	}
	if err := Export(out, true); err == nil {
		t.Fatal("export must refuse a non-empty directory")
	}
}
