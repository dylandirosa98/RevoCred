import 'dart:convert';
import 'dart:math' as math;
import '../data/reviewed_benefits.dart';
import '../models/app_models.dart';

/// Mock-only mirror of the wallet server model. Production uses API numbers.
OngoingValue estimateOngoingValue(
  List<CreditCard> wallet,
  Map<String, int> monthlyDollars,
  String travelScope,
) {
  final cards = <String, CreditCard>{
    for (final c in wallet)
      if (c.isActive && !c.termsUnknown) c.id: c,
  }.values.toList()..sort((a, b) => a.id.compareTo(b.id));
  final rates = <String, Map<String, double>>{};
  for (final c in cards) {
    rates[c.id] = c.modeledRates.isNotEmpty
        ? c.modeledRates
        : {
            for (final label in c.pointMultipliers)
              if (RegExp(r'^(\d+(?:\.\d+)?)x (.+)$').hasMatch(label))
                RegExp(
                  r'^(\d+(?:\.\d+)?)x (.+)$',
                ).firstMatch(label)!.group(2)!: double.parse(
                  RegExp(
                    r'^(\d+(?:\.\d+)?)x (.+)$',
                  ).firstMatch(label)!.group(1)!,
                ),
          };
  }
  double rate(Map<String, double> r, String cat) {
    if (cat == 'rent' || cat == 'housing') return 0;
    if (cat == 'food') {
      return math.min(
        r['dining'] ?? r['other'] ?? 0,
        r['groceries'] ?? r['other'] ?? 0,
      );
    }
    return math.max(0, r[cat] ?? r['other'] ?? 0);
  }

  var rewards = 0, fees = 0, credits = 0, anniversary = 0;
  for (final e in monthlyDollars.entries) {
    var best = 0.0;
    for (final r in rates.values) {
      best = math.max(best, rate(r, e.key));
    }
    rewards += (e.value * 12 * best).round();
  }
  int budget(List<String> keys) =>
      math.max(0, keys.fold<int>(0, (v, k) => v + (monthlyDollars[k] ?? 0))) *
      12 *
      70;
  final budgets = {
    'travel': budget(['travel', 'flights', 'hotels']),
    'food': budget(['food', 'dining', 'groceries']),
    'everyday': budget(['everyday', 'other']),
  };
  final rules = (jsonDecode(reviewedBenefitsJson) as List)
      .cast<Map<String, dynamic>>();
  final benefits = <Map<String, dynamic>>[];
  for (final c in cards) {
    fees +=
        ((double.tryParse(c.annualFee.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0) *
                100)
            .round();
    final matches = rules.where((r) => r['card_id'] == c.id);
    for (final r in matches) {
      final b = <String, dynamic>{
        ...r,
        'card_name': c.name,
        'estimated_cents': 0,
        'status': 'excluded',
      };
      final evidence = r['evidence'];
      final ok =
          c.communityData?.id == r['product_id'] &&
          (evidence == '' || c.communityData!.benefits.contains(evidence));
      if (!ok) {
        b['status'] = 'source_missing_or_changed';
        b['conditions'] =
            '${r['conditions']} Reviewed OpenCard evidence is missing or changed; estimate disabled.';
      } else if (r['kind'] == 'anniversary') {
        b['estimated_cents'] = r['face_cents'];
        b['status'] = 'conditional_on_renewal';
        anniversary += r['face_cents'] as int;
      } else if (r['kind'] == 'credit') {
        final category = r['category'] as String;
        if (category == 'travel' &&
            (travelScope == 'none' || travelScope == 'no_travel')) {
          b['status'] = 'incompatible_profile';
        } else {
          final estimate = math.min(
            (r['face_cents'] as int) * 70 ~/ 100,
            budgets[category] ?? 0,
          );
          b['estimated_cents'] = estimate;
          b['status'] = estimate == 0
              ? 'no_relevant_budget'
              : 'conditional_70_percent';
          budgets[category] = (budgets[category] ?? 0) - estimate;
          credits += estimate;
        }
      }
      benefits.add(b);
    }
    if (matches.isEmpty) {
      benefits.add({
        'card_name': c.name,
        'title': 'No reviewed recurring benefit adapter',
        'estimated_cents': 0,
        'status': 'missing_data',
        'conditions':
            'Custom, demo or unmatched product: no cash value inferred from display benefits or AI output.',
      });
    }
  }
  return OngoingValue(
    rewardsCents: rewards,
    creditsCents: credits,
    anniversaryCents: anniversary,
    feesCents: fees,
    totalCents: rewards + credits + anniversary - fees,
    benefits: benefits,
    assumptions: const [
      'Spending rewards use best known base rates and 1 cent per point, excluding housing and conditional uplift. Annual fees are subtracted.',
      'Relevant credits use a conditional 70% usage assumption, capped by 70% of annual category spending. Budget and travel scope do not establish merchant use: eligible purchases, enrollment and each periodic cap are required. Credits are not guaranteed savings. Credited purchases may not earn rewards.',
      'Anniversary rewards assume renewal and eligibility, starting at the first anniversary. Welcome bonuses are excluded; automatic bonus eligibility is not implemented.',
      'Missing/changed evidence, non-cash perks, per-stay benefits, temporary offers and multi-year application-fee credits receive zero annual cash value.',
    ],
  );
}
