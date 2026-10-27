package store

import (
	"reflect"
	"testing"
)

func TestSearchTokens(t *testing.T) {
	cases := map[string][]string{
		"Discover":         {"discover"},
		"  amex   gold ":   {"american", "express", "gold"},
		"Cap One Venture":  {"capital", "one", "venture"},
		"U.S. Bank":        {"us", "bank"},
		"usbank cash+":     {"us", "bank", "cash+"},
		"AT&T":             {"att"},
		"Kohl's":           {"kohls"},
		"sapphire-reserve": {"sapphire", "reserve"},
		"":                 {},
	}
	for query, want := range cases {
		if got := SearchTokens(query); !reflect.DeepEqual(got, want) {
			t.Errorf("SearchTokens(%q) = %q, want %q", query, got, want)
		}
	}
}
