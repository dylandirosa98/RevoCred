/// Deterministic API results. The client preserves server order; it never ranks
/// by marketing text, generic multipliers, benefits, or application offers.
class PurchaseOption {
  const PurchaseOption({
    required this.cardId,
    required this.cardName,
    required this.rate,
    required this.earnLabel,
    required this.reason,
    this.conditions = const [],
    this.source = '',
    this.sourceUrl = '',
    this.lastVerified = '',
  });
  factory PurchaseOption.fromJson(Map<String, dynamic> j) => PurchaseOption(
    cardId: (j['card_id'] ?? '').toString(),
    cardName: (j['card_name'] ?? '').toString(),
    rate: (j['rate'] as num?)?.toDouble() ?? 0,
    earnLabel: (j['earn_label'] ?? '').toString(),
    reason: (j['reason'] ?? '').toString(),
    conditions: _strings(j['conditions']),
    source: (j['source'] ?? '').toString(),
    sourceUrl: (j['source_url'] ?? '').toString(),
    lastVerified: (j['last_verified'] ?? '').toString(),
  );
  final String cardId,
      cardName,
      earnLabel,
      reason,
      source,
      sourceUrl,
      lastVerified;
  final double rate;
  final List<String> conditions;
}

class PurchaseCategory {
  const PurchaseCategory({
    required this.id,
    required this.label,
    this.options = const [],
    this.conditional = const [],
    this.unknown = const [],
    this.unknownCardIds = const [],
    this.assumptions = '',
    this.tied = false,
  });
  factory PurchaseCategory.fromJson(Map<String, dynamic> j) => PurchaseCategory(
    id: (j['id'] ?? '').toString(),
    label: (j['label'] ?? '').toString(),
    options: _objects(j['options'], PurchaseOption.fromJson),
    conditional: _objects(j['conditional'], PurchaseOption.fromJson),
    unknown: _strings(j['unknown']),
    unknownCardIds: _strings(j['unknown_card_ids']),
    assumptions: (j['assumptions'] ?? '').toString(),
    tied: j['tied'] == true,
  );
  final String id, label, assumptions;
  final List<PurchaseOption> options, conditional;
  final List<String> unknown;
  final List<String> unknownCardIds;
  final bool tied;
  PurchaseCategory forWallet(Set<String> ids) {
    final filtered = options.where((o) => ids.contains(o.cardId)).toList();
    final currentUnknown = <String>[];
    final currentUnknownIds = <String>[];
    for (var i = 0; i < unknown.length && i < unknownCardIds.length; i++) {
      if (ids.contains(unknownCardIds[i])) {
        currentUnknown.add(unknown[i]);
        currentUnknownIds.add(unknownCardIds[i]);
      }
    }
    return PurchaseCategory(
      id: id,
      label: label,
      options: filtered,
      conditional: conditional.where((o) => ids.contains(o.cardId)).toList(),
      unknown: currentUnknown,
      unknownCardIds: currentUnknownIds,
      assumptions: assumptions,
      tied: filtered.length > 1 && filtered[0].rate == filtered[1].rate,
    );
  }
}

class TravelContext {
  const TravelContext(this.id, this.label);
  final String id, label;
}

class PurchaseGuide {
  const PurchaseGuide({
    required this.categories,
    this.travelMode = 'general',
    this.capsAvailable = true,
    this.travelModes = const [],
  });
  factory PurchaseGuide.fromJson(Map<String, dynamic> j) {
    final settings = (j['settings'] as Map?) ?? {};
    return PurchaseGuide(
      categories: _objects(j['categories'], PurchaseCategory.fromJson),
      travelMode: (settings['travel_mode'] ?? 'general').toString(),
      capsAvailable: settings['caps_available'] != false,
      travelModes: _objects(
        j['travel_modes'],
        (m) => TravelContext(
          (m['id'] ?? '').toString(),
          (m['label'] ?? '').toString(),
        ),
      ),
    );
  }
  final List<PurchaseCategory> categories;
  final List<TravelContext> travelModes;
  final String travelMode;
  final bool capsAvailable;
  PurchaseCategory? category(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }
}

List<String> _strings(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : const [];
List<T> _objects<T>(dynamic v, T Function(Map<String, dynamic>) parse) =>
    v is List
    ? v.whereType<Map>().map((e) => parse(e.cast<String, dynamic>())).toList()
    : <T>[];
