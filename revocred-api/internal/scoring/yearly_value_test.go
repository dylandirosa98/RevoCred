package scoring

import "testing"

func TestYearlyValueUsesBestRateAsPercent(t *testing.T) {
	got := YearlyValue(
		MonthlySpending{DiningGrocery: 100},
		BestCreditPoints{DiningGrocery: 4, RentOrHousing: 1, Traveling: 1, Other: 1},
	)
	if got != 48 {
		t.Fatalf("YearlyValue = %d, want 48", got)
	}
}

func TestYearlyValueSumsBuckets(t *testing.T) {
	got := YearlyValue(
		MonthlySpending{RentOrHousing: 200, DiningGrocery: 400, Traveling: 100, Other: 300},
		BestCreditPoints{RentOrHousing: 2, DiningGrocery: 4, Traveling: 5, Other: 1.5},
	)
	// 200*12*2/100=48, 400*12*4/100=192, 100*12*5/100=60, 300*12*1.5/100=54 → 354
	if got != 354 {
		t.Fatalf("YearlyValue = %d, want 354", got)
	}
}

func TestYearlyValueZeroSpendIsZero(t *testing.T) {
	got := YearlyValue(MonthlySpending{}, BestCreditPoints{DiningGrocery: 4})
	if got != 0 {
		t.Fatalf("YearlyValue = %d, want 0", got)
	}
}

func TestYearlyValueTreatsMissingRateAsOneX(t *testing.T) {
	got := YearlyValue(MonthlySpending{Other: 100}, BestCreditPoints{})
	if got != 12 {
		t.Fatalf("YearlyValue = %d, want 12", got)
	}
}

func TestBestRatesUsesCatchAllFloor(t *testing.T) {
	got := BestRates(Wallet{CatchAll: 2, Dining: 4, Flights: 5})
	if got.RentOrHousing != 2 || got.Other != 2 {
		t.Fatalf("catch-all buckets = %+v", got)
	}
	if got.DiningGrocery != 4 {
		t.Fatalf("DiningGrocery = %v, want 4", got.DiningGrocery)
	}
	if got.Traveling != 5 {
		t.Fatalf("Traveling = %v, want 5", got.Traveling)
	}
}

func TestBestRatesTravelTakesHotelOverCatchAll(t *testing.T) {
	got := BestRates(Wallet{CatchAll: 2, Hotels: 10})
	if got.Traveling != 10 {
		t.Fatalf("Traveling = %v, want 10", got.Traveling)
	}
}
