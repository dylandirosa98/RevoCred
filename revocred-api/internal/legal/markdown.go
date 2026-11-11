package legal

import (
	"html"
	"regexp"
	"strings"
)

// renderMarkdown turns the small Markdown subset used by docs/legal into
// HTML: #-### headings, paragraphs, "- " bullet lists, pipe tables, **bold**
// and [text](href) links. Everything else is shown as escaped text, so the
// output never contains markup that the source did not ask for.
func renderMarkdown(source string) string {
	var out, paragraph, list []string
	var table [][]string

	flushParagraph := func() {
		if len(paragraph) > 0 {
			out = append(out, "<p>"+inline(strings.Join(paragraph, " "))+"</p>")
			paragraph = nil
		}
	}
	flushList := func() {
		if len(list) > 0 {
			out = append(out, "<ul>\n"+strings.Join(list, "\n")+"\n</ul>")
			list = nil
		}
	}
	flushTable := func() {
		if len(table) > 0 {
			out = append(out, renderTable(table))
			table = nil
		}
	}
	flush := func() { flushParagraph(); flushList(); flushTable() }

	for _, line := range strings.Split(source, "\n") {
		trimmed := strings.TrimSpace(line)
		switch {
		case trimmed == "":
			flush()
		case headingPattern.MatchString(trimmed):
			flush()
			match := headingPattern.FindStringSubmatch(trimmed)
			level := string(rune('0' + len(match[1])))
			out = append(out, "<h"+level+">"+inline(match[2])+"</h"+level+">")
		case strings.HasPrefix(trimmed, "- "):
			flushParagraph()
			flushTable()
			list = append(list, "<li>"+inline(strings.TrimSpace(trimmed[2:]))+"</li>")
		case strings.HasPrefix(trimmed, "|") && strings.HasSuffix(trimmed, "|"):
			flushParagraph()
			flushList()
			cells := strings.Split(strings.Trim(trimmed, "|"), "|")
			for i := range cells {
				cells[i] = strings.TrimSpace(cells[i])
			}
			if !isTableRule(cells) {
				table = append(table, cells)
			}
		default:
			flushList()
			flushTable()
			paragraph = append(paragraph, trimmed)
		}
	}
	flush()
	return strings.Join(out, "\n")
}

var (
	headingPattern = regexp.MustCompile(`^(#{1,3})\s+(.+)$`)
	linkPattern    = regexp.MustCompile(`\[([^\]]+)\]\(([^)\s]+)\)`)
	boldPattern    = regexp.MustCompile(`\*\*([^*]+)\*\*`)
	rulePattern    = regexp.MustCompile(`^:?-{3,}:?$`)
)

func isTableRule(cells []string) bool {
	for _, cell := range cells {
		if !rulePattern.MatchString(cell) {
			return false
		}
	}
	return true
}

func renderTable(rows [][]string) string {
	var b strings.Builder
	b.WriteString(`<div class="table"><table>`)
	for i, row := range rows {
		cell := "td"
		if i == 0 {
			cell = "th"
			b.WriteString("<thead>")
		} else if i == 1 {
			b.WriteString("<tbody>")
		}
		b.WriteString("<tr>")
		for _, value := range row {
			if cell == "th" {
				b.WriteString(`<th scope="col">` + inline(value) + "</th>")
			} else {
				b.WriteString("<td>" + inline(value) + "</td>")
			}
		}
		b.WriteString("</tr>")
		if i == 0 {
			b.WriteString("</thead>")
		}
	}
	if len(rows) > 1 {
		b.WriteString("</tbody>")
	}
	b.WriteString("</table></div>")
	return b.String()
}

// inline escapes text first and only then adds the two supported inline forms,
// so source text can never inject tags or attributes.
func inline(text string) string {
	escaped := html.EscapeString(text)
	escaped = linkPattern.ReplaceAllStringFunc(escaped, func(match string) string {
		parts := linkPattern.FindStringSubmatch(match)
		href := html.UnescapeString(parts[2])
		if !safeHref(href) {
			return match
		}
		return `<a href="` + html.EscapeString(href) + `">` + parts[1] + `</a>`
	})
	return boldPattern.ReplaceAllString(escaped, "<strong>$1</strong>")
}

func safeHref(href string) bool {
	switch {
	case strings.HasPrefix(href, "https://"), strings.HasPrefix(href, "mailto:"):
		return true
	case strings.HasPrefix(href, "/"):
		return !strings.HasPrefix(href, "//")
	}
	return false
}
