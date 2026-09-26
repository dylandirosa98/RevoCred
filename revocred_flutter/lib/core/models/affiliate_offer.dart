const affiliateDisclosure =
    'We may earn a commission if you apply through this link. Compensation does not affect your ranking.';

enum ApplyPlacement { recommendation, strategy, report, cardDetails }

class AffiliateOffer {
  const AffiliateOffer({
    required this.id,
    required this.cardId,
    required this.endsAt,
    this.isAffiliate = true,
  });

  factory AffiliateOffer.fromJson(Map<String, dynamic> json) => AffiliateOffer(
    id: json['id'] as String,
    cardId: json['card_id'] as String,
    endsAt: DateTime.parse(json['ends_at'] as String),
    isAffiliate: json['kind'] == 'affiliate',
  );

  final String id;
  final String cardId;
  final DateTime endsAt;
  final bool isAffiliate;
}

class ApplicationLink {
  const ApplicationLink({
    required this.cardName,
    required this.uri,
    required this.endsAt,
    this.isAffiliate = true,
    this.isRecommended = true,
  });
  final String cardName;
  final Uri uri;
  final DateTime endsAt;
  final bool isAffiliate;
  final bool isRecommended;
  String get disclosure => isAffiliate
      ? affiliateDisclosure
      : 'Official issuer link. RevoCred earns no commission from this link.';
  bool get isCurrent => endsAt.isAfter(DateTime.now());
}
