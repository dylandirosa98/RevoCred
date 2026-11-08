package explore

import "testing"

func TestEmbeddedRewardsAreComplete(t *testing.T) {
	rewards, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if len(rewards.Airports) != 4 || len(rewards.Regions) != 6 {
		t.Fatalf("airports=%d regions=%d", len(rewards.Airports), len(rewards.Regions))
	}
	fares, hotels := 0, 0
	for _, byDestination := range rewards.Fares {
		fares += len(byDestination)
	}
	for _, region := range rewards.Regions {
		hotels += len(region.Hotels)
	}
	if fares != 112 || hotels != 15 {
		t.Fatalf("fares=%d hotels=%d", fares, hotels)
	}
	// Spot-check transcription against the client's tables.
	if got := rewards.Fares["SFO"]["CDG"]; got != (Fare{Cash: 603, Points: 21000, Fees: 5, Airline: "American"}) {
		t.Fatalf("SFO to CDG: %+v", got)
	}
	if got := rewards.Fares["JFK"]["YYZ"]; got != (Fare{Cash: 204, Points: 7000, Fees: 12, Airline: "Flying Blue"}) {
		t.Fatalf("JFK to YYZ: %+v", got)
	}
}

func TestValidateRejectsMissingFare(t *testing.T) {
	rewards, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	broken := rewards
	broken.Fares = map[string]map[string]Fare{}
	for origin, byDestination := range rewards.Fares {
		broken.Fares[origin] = map[string]Fare{}
		for code, fare := range byDestination {
			if origin != "SFO" || code != "CDG" {
				broken.Fares[origin][code] = fare
			}
		}
	}
	if broken.validate() == nil {
		t.Fatal("a missing route passed validation")
	}
}
