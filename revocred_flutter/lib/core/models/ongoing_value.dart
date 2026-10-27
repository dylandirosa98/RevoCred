class OngoingValue {
  const OngoingValue({
    this.rewardsCents = 0,
    this.creditsCents = 0,
    this.anniversaryCents = 0,
    this.feesCents = 0,
    this.totalCents = 0,
    this.benefits = const [],
    this.assumptions = const [],
    this.modelVersion = 'ongoing-v1',
  });
  factory OngoingValue.fromJson(Map<String, dynamic> json) => OngoingValue(
    rewardsCents: (json['rewards_cents'] as num?)?.round() ?? 0,
    creditsCents: (json['credits_cents'] as num?)?.round() ?? 0,
    anniversaryCents: (json['anniversary_cents'] as num?)?.round() ?? 0,
    feesCents: (json['fees_cents'] as num?)?.round() ?? 0,
    totalCents: (json['total_cents'] as num?)?.round() ?? 0,
    modelVersion: (json['model_version'] ?? 'ongoing-v1').toString(),
    benefits: (json['benefits'] as List? ?? [])
        .map((v) => (v as Map).cast<String, dynamic>())
        .toList(),
    assumptions: (json['assumptions'] as List? ?? [])
        .map((v) => v.toString())
        .toList(),
  );
  final int rewardsCents, creditsCents, anniversaryCents, feesCents, totalCents;
  final String modelVersion;
  final List<Map<String, dynamic>> benefits;
  final List<String> assumptions;
}
