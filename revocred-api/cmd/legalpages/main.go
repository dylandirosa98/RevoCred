// Command legalpages exports the public privacy, terms and support pages as
// static HTML for an optional host other than the API (for example
// revocred.com). It is offline and never publishes anything.
//
//	go run ./cmd/legalpages -out ../.local/public-pages
package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/revocred/revocred-api/internal/legal"
)

func main() {
	out := flag.String("out", "", "absent or empty output directory")
	allow := flag.Bool("allow-placeholders", false, "export even with unresolved [[OWNER FACT]] markers (review only)")
	flag.Parse()
	if *out == "" {
		fmt.Fprintln(os.Stderr, "usage: legalpages -out DIR [-allow-placeholders]")
		os.Exit(2)
	}
	if err := legal.Export(*out, *allow); err != nil {
		fmt.Fprintln(os.Stderr, "legal page export blocked:", err)
		os.Exit(1)
	}
	fmt.Println("Exported legal pages to", *out, "- nothing was published.")
}
