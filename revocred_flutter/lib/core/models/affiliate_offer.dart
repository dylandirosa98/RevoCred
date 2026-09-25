const affiliateDisclosure =
    'We may earn a commission if you apply through this link. Compensation does not affect your ranking.';

enum ApplyPlacement { recommendation, strategy, report }

class AffiliateOffer {
  const AffiliateOffer({
    required this.id,
    required this.cardId,
    required this.endsAt,
  });

  factory AffiliateOffer.fromJson(Map<String, dynamic> json) => AffiliateOffer(
    id: json['id'] as String,
    cardId: json['card_id'] as String,
    endsAt: DateTime.parse(json['ends_at'] as String),
  );

  final String id;
  final String cardId;
  final DateTime endsAt;
}

class ApplicationLink {
  const ApplicationLink({
    required this.cardName,
    required this.uri,
    required this.endsAt,
  });
  final String cardName;
  final Uri uri;
  final DateTime endsAt;
  bool get isCurrent => endsAt.isAfter(DateTime.now());
}
