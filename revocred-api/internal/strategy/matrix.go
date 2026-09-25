package strategy

type Definition struct {
	Code                 Code
	UserType             string
	Goal                 string
	AnnualFeeLevel       string
	TravelScope          string
	Ecosystem            string
	RecommendedDebitCard string
	Cards                []string
}

var definitions = map[Code]Definition{
	S01: {Code: S01, UserType: "Low / no credit", Goal: "Cash back", AnnualFeeLevel: "Low", Ecosystem: "Capital One", RecommendedDebitCard: "Capital One 360 Checking", Cards: []string{"Savor for Students", "Quicksilver"}},
	S02: {Code: S02, UserType: "Low / no credit", Goal: "Travel", AnnualFeeLevel: "Low", TravelScope: "Both", Ecosystem: "Chase", RecommendedDebitCard: "Chase Student Checking", Cards: []string{"Freedom Rise", "Freedom Flex", "Sapphire Preferred"}},
	S03: {Code: S03, UserType: "650–720 credit score", Goal: "Cash back", AnnualFeeLevel: "Low", Ecosystem: "Capital One", Cards: []string{"SavorOne", "Quicksilver"}},
	S04: {Code: S04, UserType: "650–720 credit score", Goal: "Travel", AnnualFeeLevel: "Low", TravelScope: "Both", Ecosystem: "Chase", Cards: []string{"Freedom Unlimited", "Freedom Flex", "Sapphire Preferred"}},
	S05: {Code: S05, UserType: "720+ credit score", Goal: "Travel", AnnualFeeLevel: "High", TravelScope: "International", Ecosystem: "Amex", Cards: []string{"Venture X", "Gold", "Platinum"}},
	S06: {Code: S06, UserType: "720+ credit score", Goal: "Travel", AnnualFeeLevel: "Low", TravelScope: "International", Ecosystem: "Capital One", Cards: []string{"SavorOne", "Venture X", "Amex Gold"}},
	S07: {Code: S07, UserType: "720+ credit score", Goal: "Cash back", AnnualFeeLevel: "High", Ecosystem: "Chase", Cards: []string{"Freedom Unlimited", "Freedom Flex"}},
	S08: {Code: S08, UserType: "720+ credit score", Goal: "Travel", AnnualFeeLevel: "High", TravelScope: "Domestic", Ecosystem: "Citi", Cards: []string{"Double Cash", "Strata", "Strata Elite"}},
	S09: {Code: S09, UserType: "750+ credit score", Goal: "Travel", AnnualFeeLevel: "High", TravelScope: "Both", Ecosystem: "Chase", Cards: []string{"Freedom Unlimited", "Freedom Flex", "Sapphire Reserve"}},
}

func DefinitionFor(code Code) (Definition, bool) {
	definition, ok := definitions[code]
	return definition, ok
}
