import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/ongoing_value.dart';

class OngoingValueBreakdown extends StatelessWidget {
  const OngoingValueBreakdown({super.key, required this.value});
  final OngoingValue value;
  static String money(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';
  @override
  Widget build(BuildContext context) => ExpansionTile(
    key: const ValueKey('ongoing-value-breakdown'),
    tilePadding: EdgeInsets.zero,
    title: const Text('How this is estimated', style: TextStyle(fontSize: 13)),
    childrenPadding: const EdgeInsets.only(bottom: 12),
    expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final row in [
        ('Spending rewards', value.rewardsCents),
        ('Credits at 70% · conditional use', value.creditsCents),
        ('Anniversary rewards · after renewal', value.anniversaryCents),
        ('Annual fees', -value.feesCents),
        ('Estimated ongoing yearly value', value.totalCents),
      ])
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Expanded(child: Text(row.$1)),
              Text(money(row.$2)),
            ],
          ),
        ),
      for (final assumption in value.assumptions)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(assumption, style: Theme.of(context).textTheme.bodySmall),
        ),
      for (final b in value.benefits)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${b['card_name'] ?? ''} · ${b['title'] ?? ''}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              Text(
                '${money((b['estimated_cents'] as num?)?.round() ?? 0)} estimated · face cap ${money((b['face_cents'] as num?)?.round() ?? 0)} · ${b['frequency'] ?? 'unknown'} · ${(b['status'] ?? '').toString().replaceAll('_', ' ')}',
                style: const TextStyle(fontSize: 11),
              ),
              Text(
                '${b['conditions'] ?? ''}',
                style: const TextStyle(fontSize: 11),
              ),
              if ((b['source_url'] ?? '').toString().isNotEmpty)
                TextButton(
                  onPressed: () {
                    final uri = Uri.tryParse(b['source_url'].toString());
                    if (uri?.scheme == 'https') {
                      launchUrl(uri!, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Text(
                    'Source · reviewed ${b['reviewed_on'] ?? 'unknown'} · ${b['evidence_version'] ?? ''}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
            ],
          ),
        ),
      Text(value.modelVersion, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
