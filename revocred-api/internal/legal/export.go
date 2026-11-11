package legal

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// Export writes the pages as a static site (privacy/index.html, terms/...,
// support/..., and the index at index.html) for hosting outside the API, for
// example on revocred.com. It refuses to write unresolved owner placeholders
// unless allowPlaceholders is set, and requires an absent or empty directory
// so stale files cannot be mistaken for current pages.
func Export(dir string, allowPlaceholders bool) error {
	if len(placeholders) > 0 && !allowPlaceholders {
		return fmt.Errorf("unresolved placeholders: %s", strings.Join(placeholders, ", "))
	}
	if entries, err := os.ReadDir(dir); err == nil && len(entries) > 0 {
		return errors.New("output directory must be absent or empty")
	} else if err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	for _, page := range pages {
		target := filepath.Join(dir, page.Slug, "index.html")
		if page.Slug == "legal" {
			target = filepath.Join(dir, "index.html")
		}
		if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
			return err
		}
		if err := os.WriteFile(target, page.HTML, 0o644); err != nil {
			return err
		}
	}
	return nil
}
