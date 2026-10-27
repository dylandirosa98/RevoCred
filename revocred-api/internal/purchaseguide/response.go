package purchaseguide

import "github.com/revocred/revocred-api/internal/domain"

type TravelMode struct {
	ID    string `json:"id"`
	Label string `json:"label"`
}
type Guide struct {
	Categories  []Category   `json:"categories"`
	Settings    Settings     `json:"settings"`
	TravelModes []TravelMode `json:"travel_modes"`
}

func NewGuide(wallet []domain.WalletCard, settings Settings) Guide {
	modes := []TravelMode{}
	for _, id := range []string{"general", "flights-direct", "hotels-direct", "chase-portal", "capital-one-hotels-cars", "capital-one-flights-vacation", "citi-hotels-cars-attractions", "citi-flights", "amex-flights", "amex-prepaid-hotels"} {
		modes = append(modes, TravelMode{ID: id, Label: TravelModes[id]})
	}
	return Guide{Categories: Build(wallet, settings), Settings: settings, TravelModes: modes}
}
