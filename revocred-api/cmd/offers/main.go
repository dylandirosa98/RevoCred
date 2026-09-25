// offers is an operator-only publication/reporting tool. Credentials are read
// from AFFILIATE_DATABASE_URL, never from command-line arguments or the client.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"html/template"
	"io"
	"os"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/revocred/revocred-api/internal/affiliate"
	"github.com/revocred/revocred-api/internal/store"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func run() error {
	publish := flag.String("publish", "", "publish an approved offer from a JSON file (or - for stdin)")
	revoke := flag.String("revoke", "", "revoke an offer UUID")
	report := flag.Bool("report", false, "print the operator click dashboard as HTML")
	since := flag.String("since", time.Now().UTC().AddDate(0, 0, -29).Format("2006-01-02"), "report start date, inclusive UTC")
	flag.Parse()
	count := 0
	if *publish != "" {
		count++
	}
	if *revoke != "" {
		count++
	}
	if *report {
		count++
	}
	if count != 1 || flag.NArg() != 0 {
		return errors.New("choose exactly one: -publish FILE, -revoke UUID, or -report [-since YYYY-MM-DD]")
	}
	date, err := time.Parse("2006-01-02", *since)
	if err != nil {
		return errors.New("invalid -since date")
	}
	var offer affiliate.Publication
	if *publish != "" {
		input := os.Stdin
		if *publish != "-" {
			input, err = os.Open(*publish)
			if err != nil {
				return errors.New("cannot open publication file")
			}
			defer input.Close()
		}
		decoder := json.NewDecoder(io.LimitReader(input, 16384))
		decoder.DisallowUnknownFields()
		if err = decoder.Decode(&offer); err != nil {
			return errors.New("invalid publication JSON")
		}
		if err = decoder.Decode(new(any)); err != io.EOF {
			return errors.New("expected one publication object")
		}
		if err = offer.Validate(time.Now()); err != nil {
			return err
		}
	}
	url := os.Getenv("AFFILIATE_DATABASE_URL")
	if url == "" {
		return errors.New("set AFFILIATE_DATABASE_URL to an operator database connection")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	pool, err := pgxpool.New(ctx, url)
	if err != nil {
		return errors.New("invalid operator database connection")
	}
	defer pool.Close()
	repo := store.NewPostgres(pool)
	if *publish != "" {
		id, err := repo.PublishOffer(ctx, offer)
		if err != nil {
			return errors.New("publication failed: verify database access, current public snapshot, and revoke any previously approved offer")
		}
		fmt.Println(id)
		return nil
	}
	if *revoke != "" {
		if err = repo.RevokeOffer(ctx, *revoke); err != nil {
			return errors.New("revocation failed: verify operator access and offer UUID")
		}
		fmt.Println("Offer revoked.")
		return nil
	}
	rows, err := repo.OfferReport(ctx, date)
	if err != nil {
		return errors.New("report failed: verify database access and migration 10")
	}
	return template.Must(template.New("report").Parse(dashboard)).Execute(os.Stdout, struct {
		Since string
		Rows  []affiliate.ReportRow
	}{*since, rows})
}

const dashboard = `<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>RevoCred affiliate clicks</title>
<style>body{font:16px system-ui;margin:2rem;color:#182331;background:#f5f7fa}table{border-collapse:collapse;background:white;width:100%}th,td{text-align:left;padding:.8rem;border-bottom:1px solid #ddd}small{color:#555}main{overflow:auto}</style>
<h1>Affiliate click dashboard</h1><p>Since {{.Since}} (UTC). Counts are redirects, not unique people, applications, approvals or revenue. Automated traffic and repeat clicks may be included.</p>
<main><table><thead><tr><th>Card</th><th>Network</th><th>Offer</th><th>Approved</th><th>Expires</th><th>Placement</th><th>Clicks</th></tr></thead><tbody>
{{range .Rows}}<tr><td>{{.CardName}}</td><td>{{.Network}}</td><td><small>{{.OfferID}}</small></td><td>{{.Approved}}</td><td>{{.EndsAt.Format "2006-01-02"}}</td><td>{{.Placement}}</td><td>{{.Clicks}}</td></tr>{{else}}<tr><td colspan="7">No offers published.</td></tr>{{end}}
</tbody></table></main><p>Approval alone does not mean an offer is live: its window and reviewed catalog version must also be current. Import network conversion reporting only after a partner integration is configured.</p></html>`
