/// The member's REVO AI plan and today's usage, from `GET /v1/ai-plan`.
class AIPlan {
  const AIPlan({
    required this.subscriber,
    required this.used,
    required this.limit,
    this.source,
    this.expiresAt,
    this.nextResetAt,
    this.aiAvailable = true,
    this.purchasesEnabled = false,
  });

  factory AIPlan.fromJson(Object? json) {
    final data = json is Map ? json['data'] : null;
    if (data is! Map) throw const FormatException('Missing AI plan.');
    DateTime? time(Object? value) =>
        value is String ? DateTime.tryParse(value)?.toLocal() : null;
    int count(Object? value) => value is num ? value.toInt() : 0;
    return AIPlan(
      subscriber: data['plan'] == 'subscriber',
      source: data['source'] is String ? data['source'] as String : null,
      used: count(data['used']),
      limit: count(data['limit']),
      expiresAt: time(data['expires_at']),
      nextResetAt: time(data['next_reset_at']),
      aiAvailable: data['ai_available'] != false,
      purchasesEnabled: data['purchases_enabled'] == true,
    );
  }

  final bool subscriber;

  /// "revenuecat" for an App Store subscription, "manual" for an operator
  /// grant, null on the free plan.
  final String? source;
  final int used;
  final int limit;
  final DateTime? expiresAt;
  final DateTime? nextResetAt;

  /// False when the server answers with basic answers only.
  final bool aiAvailable;

  /// True when the server accepts App Store subscription events, so the app
  /// may sell the subscription.
  final bool purchasesEnabled;

  int get remaining => (limit - used).clamp(0, limit);
  bool get appStoreSubscription => subscriber && source == 'revenuecat';

  String get label => subscriber ? 'REVO AI' : 'Free';

  /// "2 of 3 AI answers used today".
  String get usage => '$used of $limit AI answers used today';
}

/// Implemented by repositories that can report the member's AI plan.
abstract interface class AIPlanSource {
  /// The current plan. [refresh] asks the server to re-read the App Store
  /// subscription first, e.g. right after a purchase or restore.
  Future<AIPlan> loadAIPlan({bool refresh = false});
}
