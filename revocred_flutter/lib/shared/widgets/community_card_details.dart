import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/logic/card_detail_text.dart';
import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';
import 'content_layout.dart';

/// Card terms for display only; never changes the inputs used for scoring.
class CommunityCardDetails extends StatelessWidget {
  const CommunityCardDetails({
    required this.data,
    this.catalogBenefits = const [],
    this.fallbackRewardRates = const [],
    super.key,
  });

  final CommunityCardData data;
  final List<String> catalogBenefits;
  final List<String> fallbackRewardRates;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    final checked = DateTime.tryParse(data.lastVerified);
    final stale =
        checked != null &&
        DateTime.now().toUtc().difference(checked.toUtc()).inDays > 90;
    final rewards = _distinct(
      data.rewardRates.isNotEmpty ? data.rewardRates : fallbackRewardRates,
    );
    final benefits = _distinct([...data.benefits, ...catalogBenefits]);
    final benefitKeys = benefits.map(_detailKey).toSet();
    final travelPerks = _distinct(
      cardTravelPerkText(data.travelPerks),
    ).where((perk) => !benefitKeys.contains(_detailKey(perk))).toList();
    final issuerUri = Uri.tryParse(data.issuerUrl);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        const SectionLabel('Rewards'),
        if (data.currencyLabel.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            cardDetailText(data.currencyLabel),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
        const SizedBox(height: 8),
        if (rewards.isEmpty)
          Text(
            'Reward details are not available yet. Check current issuer terms.',
            style: TextStyle(color: product.muted),
          ),
        for (final rate in rewards) _row(Icons.bolt_outlined, rate),
        if (data.redemptionNotes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              cardDetailText(data.redemptionNotes),
              style: TextStyle(color: product.muted, fontSize: 12),
            ),
          ),
        const SizedBox(height: 14),
        const SectionLabel('Credits & benefits'),
        const SizedBox(height: 8),
        if (benefits.isEmpty && travelPerks.isEmpty)
          Text(
            'Benefit details are not available yet. This does not mean the card has no benefits.',
            style: TextStyle(color: product.muted),
          ),
        for (final benefit in benefits) _row(Icons.info_outline, benefit),
        for (final perk in travelPerks) _row(Icons.flight_outlined, perk),
        if (travelPerks.isNotEmpty)
          Text(
            'Perks are not extra cash value. Missing details are unknown; check eligibility and current issuer terms.',
            style: TextStyle(color: product.muted, fontSize: 12),
          ),
        if (data.welcomeOfferDescription.isNotEmpty)
          Material(
            color: Colors.transparent,
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('First-year offer'),
              subtitle: const Text(
                'Not guaranteed; excluded from value estimates',
              ),
              children: [
                Text(cardDetailText(data.welcomeOfferDescription)),
                const SizedBox(height: 10),
              ],
            ),
          ),
        const SizedBox(height: 12),
        if (checked != null)
          Text(
            'Details last verified ${MaterialLocalizations.of(context).formatShortDate(checked)}',
            style: TextStyle(fontSize: 12, color: product.muted),
          ),
        if (stale || checked == null)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              checked == null
                  ? 'The verification date is unknown. Check current issuer terms.'
                  : 'These details are over 90 days old. Check current issuer terms.',
              style: TextStyle(color: product.warning, fontSize: 12),
            ),
          ),
        if (issuerUri != null &&
            issuerUri.scheme == 'https' &&
            issuerUri.host.isNotEmpty)
          TextButton(
            onPressed: () =>
                launchUrl(issuerUri, mode: LaunchMode.externalApplication),
            child: const Text('Issuer terms'),
          ),
      ],
    );
  }

  // Only remove exact display duplicates. Similar benefits may carry different
  // enrollment rules or limits, so their conditions must remain visible.
  List<String> _distinct(Iterable<String> values) {
    final seen = <String>{};
    return [
      for (final value in values.map(cardDetailText))
        if (value.trim().isNotEmpty && seen.add(_detailKey(value))) value,
    ];
  }

  String _detailKey(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  Widget _row(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
