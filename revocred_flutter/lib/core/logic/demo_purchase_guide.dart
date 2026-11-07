// Offline demo only. Production comparisons are calculated by the Go API.
// Structured fixture rates replace the old marketing-text ranking in mock mode.
import '../models/app_models.dart';

PurchaseGuide demoPurchaseGuide(
  List<CreditCard> wallet, {
  String travelMode = 'general',
  bool capsAvailable = true,
}) {
  const labels = {
    'dining': 'Dining',
    'groceries': 'Groceries',
    'travel': 'Travel',
    'gas': 'Gas',
    'transit': 'Transit',
    'online-shopping': 'Online shopping',
    'rent': 'Rent',
    'streaming': 'Streaming',
    'entertainment': 'Entertainment',
    'drugstores': 'Drugstores',
    'wholesale-clubs': 'Wholesale clubs',
    'utilities': 'Utilities',
    'phone-and-internet': 'Phone & internet',
    'home-improvement': 'Home improvement',
    'office-supplies': 'Office supplies',
    'general-purchases': 'General purchases',
  };
  const rates = <String, Map<String, double>>{
    'amex-gold': {
      'other': 1,
      'dining': 4,
      'groceries': 4,
      'flights-direct': 3,
      'amex-flights': 3,
    },
    'venture-x': {
      'other': 2,
      'capital-one-hotels-cars': 10,
      'capital-one-flights-vacation': 5,
    },
    'freedom-unlimited': {
      'other': 1.5,
      'dining': 3,
      'drugstores': 3,
      'chase-portal': 5,
    },
    'freedom-flex': {
      'other': 1,
      'dining': 3,
      'drugstores': 3,
      'chase-portal': 5,
    },
    'savor': {
      'other': 1,
      'dining': 3,
      'groceries': 3,
      'streaming': 3,
      'entertainment': 3,
    },
    'bilt': {'other': 1, 'dining': 3, 'travel': 2},
    'sapphire-preferred': {
      'other': 1,
      'dining': 3,
      'travel': 2,
      'streaming': 3,
      'chase-portal': 5,
    },
    'citi-strata': {
      'other': 1,
      'dining': 2,
      'groceries': 3,
      'gas': 3,
      'transit': 3,
      'citi-hotels-cars-attractions': 5,
    },
    'freedom-rise': {'other': 1.5},
    'discover-it': {'other': 1},
  };
  final categories = <PurchaseCategory>[];
  int byRate(PurchaseOption a, PurchaseOption b) {
    final rate = b.rate.compareTo(a.rate);
    if (rate != 0) return rate;
    final name = a.cardName.compareTo(b.cardName);
    return name != 0 ? name : a.cardId.compareTo(b.cardId);
  }

  for (final entry in labels.entries) {
    final options = <PurchaseOption>[];
    final fallback = <PurchaseOption>[];
    final unknown = <String>[];
    final unknownIds = <String>[];
    for (final card in wallet) {
      final known = rates[card.id];
      if (card.termsUnknown || known == null) {
        unknown.add('${card.name}: no supported demo rule');
        unknownIds.add(card.id);
        continue;
      }
      if (entry.key == 'rent') {
        final base = known['other']!;
        fallback.add(
          PurchaseOption(
            cardId: card.id,
            cardName: card.name,
            rate: base,
            earnLabel:
                '${base == base.roundToDouble() ? base.toInt() : base}x demo rate',
            reason:
                'Rent must qualify as a purchase. Check payment fees first.',
            conditions: const [
              'Unverified demo base rate before fees. Confirm acceptance and reward eligibility; fees can outweigh rewards.',
            ],
            source: 'Unverified offline demo data',
          ),
        );
        continue;
      }
      var rate = known[entry.key] ?? known['other']!;
      if (entry.key == 'travel' && travelMode != 'general') {
        rate = known[travelMode] ?? known['other']!;
      }
      if (!capsAvailable &&
          card.id == 'amex-gold' &&
          (entry.key == 'dining' || entry.key == 'groceries')) {
        rate = 1;
      }
      options.add(
        PurchaseOption(
          cardId: card.id,
          cardName: card.name,
          rate: rate,
          earnLabel:
              '${rate == rate.roundToDouble() ? rate.toInt() : rate}x demo rate',
          reason: 'Applicable demo fixture rate for ${entry.value}',
          source: 'Unverified offline demo data',
        ),
      );
    }
    options.sort(byRate);
    fallback.sort(byRate);
    final displayed = options.isEmpty ? fallback : options;
    categories.add(
      PurchaseCategory(
        id: entry.key,
        label: entry.value,
        options: options,
        fallbackOptions: fallback,
        unknown: unknown,
        unknownCardIds: unknownIds,
        tied: displayed.length > 1 && displayed[0].rate == displayed[1].rate,
        assumptions:
            'Offline demonstration only. Points assumed worth 1 cent each. Not current verified card terms.',
      ),
    );
  }
  return PurchaseGuide(
    categories: categories,
    travelMode: travelMode,
    capsAvailable: capsAvailable,
    travelModes: const [
      TravelContext('general', 'General travel'),
      TravelContext('flights-direct', 'Flights booked direct'),
      TravelContext('hotels-direct', 'Hotels booked direct'),
      TravelContext('chase-portal', 'Chase Travel'),
      TravelContext(
        'capital-one-hotels-cars',
        'Capital One Travel: hotels and cars',
      ),
      TravelContext(
        'capital-one-flights-vacation',
        'Capital One Travel: flights and vacation rentals',
      ),
    ],
  );
}
