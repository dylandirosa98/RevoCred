// Package explore serves the Explore Rewards examples: illustrative flight and
// hotel redemptions shown next to a member's estimated annual points. The data
// is client-supplied example pricing, not live fares or award availability, and
// it never influences card selection or scoring.
package explore

import (
	_ "embed"
	"encoding/json"
	"fmt"
	"sync"
)

//go:embed rewards.json
var rewardsJSON []byte

type Airport struct {
	Code string `json:"code"`
	City string `json:"city"`
}

type Destination struct {
	Name string `json:"name"`
	Code string `json:"code"`
}

type Hotel struct {
	Name    string `json:"name"`
	Place   string `json:"place"`
	Program string `json:"program"`
	Cash    int    `json:"cash"`
	Points  int    `json:"points"`
}

type Region struct {
	Name    string        `json:"name"`
	Flights []Destination `json:"flights"`
	Hotels  []Hotel       `json:"hotels"`
}

type Fare struct {
	Cash    int    `json:"cash"`
	Points  int    `json:"points"`
	Fees    int    `json:"fees"`
	Airline string `json:"airline"`
}

type Rewards struct {
	Version            string                     `json:"version"`
	Source             string                     `json:"source"`
	PointBaselineCents int                        `json:"point_baseline_cents"`
	Airports           []Airport                  `json:"airports"`
	Regions            []Region                   `json:"regions"`
	Fares              map[string]map[string]Fare `json:"fares"`
	Disclaimers        map[string]string          `json:"disclaimers"`
}

var load = sync.OnceValues(func() (Rewards, error) {
	var rewards Rewards
	if err := json.Unmarshal(rewardsJSON, &rewards); err != nil {
		return Rewards{}, fmt.Errorf("explore rewards data: %w", err)
	}
	return rewards, rewards.validate()
})

// Load returns the embedded examples, validated once.
func Load() (Rewards, error) { return load() }

func (r Rewards) validate() error {
	if r.Version == "" || r.PointBaselineCents != 1 || len(r.Airports) == 0 || len(r.Regions) == 0 {
		return fmt.Errorf("explore rewards data is incomplete")
	}
	for _, key := range []string{"flights", "hotels", "estimate"} {
		if r.Disclaimers[key] == "" {
			return fmt.Errorf("explore rewards data is missing the %s disclaimer", key)
		}
	}
	for _, airport := range r.Airports {
		fares := r.Fares[airport.Code]
		if fares == nil {
			return fmt.Errorf("no fares from %s", airport.Code)
		}
		for _, region := range r.Regions {
			for _, flight := range region.Flights {
				if flight.Code == airport.Code {
					continue // a self-route is never shown
				}
				fare, ok := fares[flight.Code]
				if !ok {
					return fmt.Errorf("no fare %s to %s", airport.Code, flight.Code)
				}
				if fare.Cash <= 0 || fare.Points <= 0 || fare.Fees < 0 || fare.Airline == "" {
					return fmt.Errorf("invalid fare %s to %s", airport.Code, flight.Code)
				}
			}
		}
	}
	for _, region := range r.Regions {
		if region.Name == "" || len(region.Flights) == 0 || len(region.Hotels) == 0 {
			return fmt.Errorf("region %q is incomplete", region.Name)
		}
		for _, hotel := range region.Hotels {
			if hotel.Name == "" || hotel.Cash <= 0 || hotel.Points <= 0 || hotel.Program == "" {
				return fmt.Errorf("invalid hotel %q", hotel.Name)
			}
		}
	}
	return nil
}
