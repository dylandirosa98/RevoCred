import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';
import 'content_layout.dart';

/// Source-labelled supplemental terms; deliberately separate from scored terms.
class CommunityCardDetails extends StatelessWidget {
  const CommunityCardDetails({required this.data, super.key});
  final CommunityCardData data;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    final checked = DateTime.tryParse(data.lastVerified);
    final stale =
        checked != null &&
        DateTime.now().toUtc().difference(checked.toUtc()).inDays > 90;
    final fetched = data.retrievedAt.split('T').first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 30),
        Text(data.attribution, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 5),
        Text(
          'Source last verified: ${data.lastVerified} · Retrieved: $fetched',
          style: TextStyle(fontSize: 11, color: product.muted),
        ),
        if (stale || checked == null)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              checked == null
                  ? 'Source verification date is unavailable. Check current issuer terms.'
                  : 'Source verification is over 90 days old. Check current issuer terms.',
              style: TextStyle(color: product.warning, fontSize: 12),
            ),
          ),
        const SizedBox(height: 12),
        Text(
          data.warning,
          style: TextStyle(color: product.muted, fontSize: 12),
        ),
        const SizedBox(height: 15),
        const SectionLabel('Earning rates from source'),
        const SizedBox(height: 6),
        Text(data.currencyLabel, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        for (final rate in data.rewardRates) _row(Icons.bolt_outlined, rate),
        if (data.redemptionNotes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              data.redemptionNotes,
              style: TextStyle(color: product.muted, fontSize: 12),
            ),
          ),
        const SizedBox(height: 14),
        const SectionLabel('Additional benefits from source'),
        const SizedBox(height: 7),
        if (data.benefits.isEmpty)
          Text(
            'This source has no additional benefit details. That does not mean the card has no benefits.',
            style: TextStyle(color: product.muted),
          ),
        for (final benefit in data.benefits) _row(Icons.info_outline, benefit),
        if (data.travelPerks.isNotEmpty) ...[
          const SizedBox(height: 14),
          const SectionLabel('Travel perks from source'),
          const SizedBox(height: 7),
          for (final perk in data.travelPerks)
            _row(Icons.flight_outlined, perk),
          Text(
            'Supplemental source facts, not additional cash value. Missing fields are unknown; verify eligibility and current issuer terms.',
            style: TextStyle(color: product.muted, fontSize: 12),
          ),
        ],
        if (data.welcomeOfferDescription.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Welcome offer snapshot'),
            subtitle: const Text(
              'Not guaranteed; excluded from value estimates',
            ),
            children: [
              Text(data.welcomeOfferDescription),
              const SizedBox(height: 10),
            ],
          ),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: () => _open(data.issuerUrl),
              child: const Text('Issuer terms'),
            ),
            TextButton(
              onPressed: () => _open(data.sourceUrl),
              child: const Text('Data source'),
            ),
            TextButton(
              onPressed: () => _open(data.licenseUrl),
              child: const Text('Data license'),
            ),
          ],
        ),
      ],
    );
  }

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

  Future<void> _open(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
