// Command carddata refreshes or inspects the public OpenCard DB cache.
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"net/http"
	"os"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/revocred/revocred-api/internal/carddata"
	"github.com/revocred/revocred-api/internal/store"
)

func main() {
	refresh := flag.Bool("refresh", false, "fetch and persist the latest public source snapshot")
	flag.Parse()
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	if os.Getenv("DATABASE_URL") == "" {
		fmt.Fprintln(os.Stderr, "DATABASE_URL is required")
		os.Exit(1)
	}
	pool, err := pgxpool.New(ctx, os.Getenv("DATABASE_URL"))
	if err != nil {
		fmt.Fprintln(os.Stderr, "database configuration invalid")
		os.Exit(1)
	}
	defer pool.Close()
	repo := store.NewPostgres(pool)
	cache := carddata.New(&http.Client{Timeout: 25 * time.Second}, repo, carddata.SourceURL)
	if *refresh {
		err = cache.Refresh(ctx)
	} else {
		err = cache.Load(ctx)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "OpenCard operation failed:", err)
		os.Exit(1)
	}
	repo.UseCardData(cache)
	cards, err := repo.ListCatalog(ctx)
	if err != nil {
		fmt.Fprintln(os.Stderr, "catalog unavailable")
		os.Exit(1)
	}
	mapped := 0
	rows := []map[string]any{}
	for _, c := range cards {
		row := map[string]any{"card": c.Name, "slug": c.Slug, "connected": c.CommunityData != nil}
		if d := c.CommunityData; d != nil {
			mapped++
			row["external_id"] = d.ID
			row["reward_rules"] = len(d.RewardRates)
			row["benefits"] = len(d.Benefits)
			row["source_last_verified"] = d.LastVerified
			row["retrieved_at"] = d.RetrievedAt
		}
		rows = append(rows, row)
	}
	json.NewEncoder(os.Stdout).Encode(map[string]any{"catalog_count": len(cards), "connected_count": mapped, "source": carddata.ProjectURL, "cards": rows})
}
