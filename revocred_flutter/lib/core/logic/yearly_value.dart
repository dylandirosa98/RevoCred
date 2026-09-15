import 'wallet_score.dart';

class MonthlySpending {
  const MonthlySpending({
    this.rentOrHousing = 0,
    this.diningGrocery = 0,
    this.traveling = 0,
    this.other = 0,
  });

  final int rentOrHousing;
  final int diningGrocery;
  final int traveling;
  final int other;

  factory MonthlySpending.fromQuestionnaire(Map<String, int> monthlySpend) =>
      MonthlySpending(
        rentOrHousing: monthlySpend['rent'] ?? 0,
        diningGrocery: monthlySpend['food'] ?? 0,
        traveling: monthlySpend['travel'] ?? 0,
        other: monthlySpend['everyday'] ?? 0,
      );
}

class BestCreditPoints {
  const BestCreditPoints({
    required this.rentOrHousing,
    required this.diningGrocery,
    required this.traveling,
    required this.other,
  });

  final double rentOrHousing;
  final double diningGrocery;
  final double traveling;
  final double other;
}

int yearlyValue(MonthlySpending spend, BestCreditPoints rates) {
  return (_dollarValue(spend.rentOrHousing, rates.rentOrHousing) +
          _dollarValue(spend.diningGrocery, rates.diningGrocery) +
          _dollarValue(spend.traveling, rates.traveling) +
          _dollarValue(spend.other, rates.other))
      .round();
}

double _dollarValue(int monthlyDollars, double rate) =>
    monthlyDollars * 12 * _atLeastOne(rate) / 100;

double _atLeastOne(double rate) => rate < 1 ? 1 : rate;

BestCreditPoints bestRates(WalletCapabilities wallet) {
  final catchAll = _atLeastOne(wallet.catchAll);
  final diningGrocery = _max(
    _max(_atLeastOne(wallet.dining), catchAll),
    _max(_atLeastOne(wallet.groceries), catchAll),
  );
  var travel = _max(_atLeastOne(wallet.travel), catchAll);
  travel = _max(travel, _max(_atLeastOne(wallet.flights), catchAll));
  travel = _max(travel, _max(_atLeastOne(wallet.hotels), catchAll));
  return BestCreditPoints(
    rentOrHousing: catchAll,
    diningGrocery: diningGrocery,
    traveling: travel,
    other: catchAll,
  );
}

double _max(double a, double b) => a > b ? a : b;
