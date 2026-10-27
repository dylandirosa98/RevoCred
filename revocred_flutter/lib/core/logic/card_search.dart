import '../models/app_models.dart';

List<CreditCard> searchCards(List<CreditCard> cards, String query) {
  final normalized = _normalize(query);
  final tokens = normalized
      .split(RegExp(r'\s+'))
      .where((value) => value.isNotEmpty);
  if (tokens.isEmpty) return const [];

  final scored = <({CreditCard card, int score, int coreRank})>[];
  for (final card in cards) {
    final fields = [
      card.id,
      card.issuer,
      card.brand,
      card.name,
    ].map(_normalize).toList();
    final issuer = _normalize(card.issuer);
    final name = _normalize(card.name);
    final issuerSearch = issuer == normalized;
    final coreRank = _coreCardRank(card);
    var score = 0;
    var matches = true;
    // A specific card query always wins, including partner cards such as an
    // airline card. The core-card preference only applies to an issuer query.
    if (name == normalized ||
        _normalize('${card.issuer} ${card.name}') == normalized) {
      score += 1000;
    }
    if (issuerSearch) {
      score += 500;
      score += (100 - coreRank).clamp(0, 100);
      if (_isPartnerCard(card)) score -= 150;
    }
    for (final token in tokens) {
      if (fields.any((field) => field == token)) {
        score += 30;
      } else if (fields.any(
        (field) =>
            field.startsWith(token) ||
            field
                .split(RegExp(r'[\s-]+'))
                .any((word) => word.startsWith(token)),
      )) {
        score += 14;
      } else {
        matches = false;
        break;
      }
    }
    if (matches) {
      scored.add((card: card, score: score, coreRank: coreRank));
    }
  }
  scored.sort((a, b) {
    final scoreOrder = b.score.compareTo(a.score);
    if (scoreOrder != 0) return scoreOrder;
    final coreOrder = a.coreRank.compareTo(b.coreRank);
    return coreOrder != 0 ? coreOrder : a.card.name.compareTo(b.card.name);
  });
  return scored.map((entry) => entry.card).toList();
}

String _normalize(String value) {
  var normalized = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9+]+'), ' ');
  normalized = ' ${normalized.trim()} ';
  const aliases = <String, String>{
    ' amex ': ' american express ',
    ' capone ': ' capital one ',
    ' citibank ': ' citi ',
    ' bofa ': ' bank of america ',
    ' boa ': ' bank of america ',
    ' usbank ': ' us bank ',
  };
  for (final alias in aliases.entries) {
    normalized = normalized.replaceAll(alias.key, alias.value);
  }
  return normalized.trim().replaceAll(RegExp(r'\s+'), ' ');
}

int _coreCardRank(CreditCard card) {
  final issuer = _normalize(card.issuer);
  final name = _normalize(card.name);
  final orderedNames = _coreCardsByIssuer[issuer];
  if (orderedNames != null) {
    for (var index = 0; index < orderedNames.length; index++) {
      if (name.contains(orderedNames[index])) return index;
    }
  }
  return _isPartnerCard(card) ? 500 : 100;
}

bool _isPartnerCard(CreditCard card) {
  final name = _normalize(card.name);
  return _partnerNames.any((partner) => name.contains(partner));
}

// Popular issuer-owned products are intentionally a small presentation hint,
// not a claim about approval odds or financial suitability. It only orders
// already-matching search results; the deterministic recommendation engine is
// still responsible for choosing cards for a user.
const _coreCardsByIssuer = <String, List<String>>{
  'american express': [
    'platinum',
    'gold',
    'green',
    'blue cash preferred',
    'blue cash everyday',
    'cash magnet',
  ],
  'bank of america': [
    'premium rewards elite',
    'premium rewards',
    'customized cash rewards',
    'unlimited cash rewards',
    'bankamericard',
  ],
  'capital one': ['venture x', 'venture', 'savor', 'quicksilver', 'platinum'],
  'chase': [
    'sapphire preferred',
    'sapphire reserve',
    'freedom unlimited',
    'freedom flex',
    'freedom rise',
    'slate edge',
  ],
  'citi': [
    'custom cash',
    'double cash',
    'strata premier',
    'strata elite',
    'strata',
    'simplicity',
    'diamond preferred',
  ],
  'discover': [
    'discover it cash back',
    'discover it miles',
    'discover it chrome',
  ],
  'wells fargo': ['active cash', 'autograph journey', 'autograph', 'reflect'],
};

const _partnerNames = <String>[
  'aadvantage',
  'amazon',
  'atmos',
  'best buy',
  'bjs',
  'choice privileges',
  'costco',
  'delta',
  'hilton',
  'home depot',
  'hyatt',
  'kohls',
  'macys',
  'marriott',
  'one key',
  'rei',
  'southwest',
  'spirit',
  't mobile',
  'united',
];
