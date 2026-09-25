import '../models/app_models.dart';

class WalletCapabilities {
  const WalletCapabilities({
    this.catchAll = 0,
    this.dining = 0,
    this.groceries = 0,
    this.gas = 0,
    this.travel = 0,
    this.flights = 0,
    this.hotels = 0,
    this.transferPartners = false,
    this.premiumBenefits = false,
    this.ecosystemDiversity = false,
    this.majorOverlap = false,
    this.multipleOverlap = false,
  });

  final double catchAll;
  final double dining;
  final double groceries;
  final double gas;
  final double travel;
  final double flights;
  final double hotels;
  final bool transferPartners;
  final bool premiumBenefits;
  final bool ecosystemDiversity;
  final bool majorOverlap;
  final bool multipleOverlap;
}

class WalletScore {
  const WalletScore({
    required this.score,
    required this.rating,
    required this.additions,
    required this.penalties,
  });

  final int score;
  final String rating;
  final int additions;
  final int penalties;
}

int displayWalletScore({
  required bool useLocal,
  required int storedScore,
  required WalletScore localScore,
}) {
  if (useLocal || storedScore < 22 || storedScore > 95) {
    return localScore.score;
  }
  return storedScore;
}

WalletScore scoreWallet(WalletCapabilities wallet) {
  final additions = _additionsFor(wallet);
  final penalties = _penaltiesFor(wallet);
  var score = 50 + additions + penalties;
  if (score > 95) score = 95;
  if (score < 22) score = 22;
  return WalletScore(
    score: score,
    rating: ratingFor(score),
    additions: additions,
    penalties: penalties,
  );
}

int _additionsFor(WalletCapabilities wallet) {
  var additions = 0;
  if (wallet.catchAll >= 2) {
    additions += 10;
  } else if (wallet.catchAll >= 1.5) {
    additions += 5;
  }
  if (wallet.dining >= 4) {
    additions += 8;
  } else if (wallet.dining >= 3) {
    additions += 4;
  }
  if (wallet.groceries >= 3) additions += 6;
  if (wallet.gas >= 3) additions += 3;
  if (wallet.travel >= 2) additions += 4;
  if (wallet.flights >= 5) additions += 4;
  if (wallet.hotels >= 5) additions += 3;
  if (wallet.transferPartners) additions += 4;
  if (wallet.premiumBenefits) additions += 2;
  if (wallet.ecosystemDiversity) additions += 1;
  if (additions > 45) additions = 45;
  return additions;
}

int _penaltiesFor(WalletCapabilities wallet) {
  var penalties = 0;
  if (!_hasRewards(wallet)) {
    penalties -= 10;
  } else if (_atLeastOne(wallet.catchAll) < 1.5) {
    penalties -= 5;
  }
  if (_bestRate(wallet.dining, wallet.catchAll) <= 1) penalties -= 4;
  if (_bestRate(wallet.groceries, wallet.catchAll) <= 1) penalties -= 3;
  if (_bestRate(wallet.gas, wallet.catchAll) <= 1) penalties -= 2;
  if (_bestRate(wallet.travel, wallet.catchAll) <= 1) penalties -= 3;
  final catchAll = _atLeastOne(wallet.catchAll);
  if (_categoryOrCatchAll(wallet.flights, wallet.catchAll) <= catchAll) {
    penalties -= 2;
  }
  if (_categoryOrCatchAll(wallet.hotels, wallet.catchAll) <= catchAll) {
    penalties -= 2;
  }
  if (wallet.multipleOverlap) {
    penalties -= 4;
  } else if (wallet.majorOverlap) {
    penalties -= 2;
  }
  if (penalties < -28) penalties = -28;
  return penalties;
}

bool _hasRewards(WalletCapabilities wallet) =>
    wallet.catchAll > 1 ||
    wallet.dining > 1 ||
    wallet.groceries > 1 ||
    wallet.gas > 1 ||
    wallet.travel > 1 ||
    wallet.flights > 1 ||
    wallet.hotels > 1;

double _atLeastOne(double rate) => rate < 1 ? 1 : rate;

double _bestRate(double category, double catchAll) =>
    _maxRate(_atLeastOne(category), _atLeastOne(catchAll));

double _categoryOrCatchAll(double category, double catchAll) =>
    category == 0 ? _atLeastOne(catchAll) : _atLeastOne(category);

double _maxRate(double a, double b) => a > b ? a : b;

String ratingFor(int score) {
  if (score >= 90) return 'Elite';
  if (score >= 80) return 'Great';
  if (score >= 65) return 'Good';
  if (score >= 50) return 'Fair';
  return 'Poor';
}

WalletCapabilities walletCapabilities(List<CreditCard> cards) {
  var catchAll = 0.0;
  var dining = 0.0;
  var groceries = 0.0;
  var gas = 0.0;
  var travel = 0.0;
  var flights = 0.0;
  var hotels = 0.0;
  var transferPartners = false;
  var premiumBenefits = false;
  final issuers = <String>{};
  for (final card in cards) {
    if (card.issuer.isNotEmpty) issuers.add(card.issuer);
    if (card.transferablePoints) transferPartners = true;
    if (card.feeTier == 'high' || _annualFeeCents(card.annualFee) >= 30000) {
      premiumBenefits = true;
    }
    for (final line in card.pointMultipliers) {
      final rate = parseMultiplier(line);
      if (rate == null) continue;
      switch (multiplierBucket(line)) {
        case 'catch_all':
          if (rate > catchAll) catchAll = rate;
        case 'dining':
          if (rate > dining) dining = rate;
        case 'groceries':
          if (rate > groceries) groceries = rate;
        case 'gas':
          if (rate > gas) gas = rate;
        case 'flights':
          if (rate > flights) flights = rate;
        case 'hotels':
          if (rate > hotels) hotels = rate;
        case 'travel':
          if (rate > travel) travel = rate;
      }
    }
  }
  return WalletCapabilities(
    catchAll: catchAll,
    dining: dining,
    groceries: groceries,
    gas: gas,
    travel: travel,
    flights: flights,
    hotels: hotels,
    transferPartners: transferPartners,
    premiumBenefits: premiumBenefits,
    ecosystemDiversity: issuers.length >= 2,
  );
}

double? parseMultiplier(String line) {
  final match = RegExp(
    r'(\d+(?:\.\d+)?)\s*[x%]',
  ).firstMatch(line.toLowerCase());
  if (match == null) return null;
  return double.tryParse(match.group(1)!);
}

String? multiplierBucket(String line) {
  final lower = line.toLowerCase();
  if (lower.contains('rotating')) return null;
  if (lower.contains('everywhere') ||
      lower.contains('catch-all') ||
      lower.contains('catch all') ||
      lower.contains('cash back')) {
    return 'catch_all';
  }
  if (lower.contains('flight')) return 'flights';
  if (lower.contains('hotel')) return 'hotels';
  if (lower.contains('dining') || lower.contains('restaurant')) return 'dining';
  if (lower.contains('groc') || lower.contains('supermarket')) {
    return 'groceries';
  }
  if (lower.contains('gas') || lower.contains('ev')) return 'gas';
  if (lower.contains('travel')) return 'travel';
  return null;
}

int _annualFeeCents(String annualFee) {
  final match = RegExp(r'(\d+)').firstMatch(annualFee.replaceAll(',', ''));
  if (match == null) return 0;
  return int.parse(match.group(1)!) * 100;
}
