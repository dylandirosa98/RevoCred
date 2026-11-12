import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../shared/widgets/community_card_details.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logic/card_search.dart';
import '../../../core/logic/strategy_digest.dart';
import '../../../core/models/app_models.dart';
import '../../../core/models/affiliate_offer.dart';
import '../../../shared/widgets/apply_offer_button.dart';
import '../../../core/state/app_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/content_layout.dart';
import '../../../shared/widgets/credit_card_view.dart';
import '../../../shared/widgets/issuer_mark.dart';
import 'strategy_checklist.dart';

class StrategyScreen extends ConsumerStatefulWidget {
  const StrategyScreen({super.key});

  @override
  ConsumerState<StrategyScreen> createState() => _StrategyScreenState();
}

class _StrategyScreenState extends ConsumerState<StrategyScreen> {
  final searchController = TextEditingController();
  String query = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appControllerProvider).data!;
    final product = context.product;
    final results = searchCards(data.catalog, query).take(8).toList();
    final playbook = data.playbook;
    final popular = strategyComparisonCards(data);

    return ContentLayout(
      maxWidth: 1040,
      children: [
        if (data.strategyPlan != null) ...[
          StrategyChecklist(data: data, onCardDetails: _showDetails),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            key: const ValueKey('strategy-open-share-report'),
            onPressed: () => context.push('/strategy-report'),
            icon: const Icon(Icons.ios_share_outlined),
            label: const Text('See the full plan & share it'),
          ),
        ] else
          AppPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Build your personalized strategy',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 7),
                const Text(
                  'Complete the questionnaire to create your application roadmap.',
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.push('/questionnaire'),
                  child: const Text('Build my strategy'),
                ),
              ],
            ),
          ),
        if (playbook != null && playbook.unused.isNotEmpty) ...[
          SizedBox(height: product.sectionGap),
          const SectionLabel('Cards to de-emphasize'),
          const SizedBox(height: 10),
          AppPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final card in playbook.unused)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('${card.name}: ${card.note}'),
                  ),
              ],
            ),
          ),
        ],
        SizedBox(height: product.sectionGap),
        const SectionLabel('Explore the catalog'),
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('card-search-field'),
          controller: searchController,
          onChanged: (value) => setState(() => query = value),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Search cards, issuers, rewards, or fees',
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    key: const ValueKey('strategy-clear-search'),
                    tooltip: 'Clear search',
                    onPressed: () {
                      searchController.clear();
                      setState(() => query = '');
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        if (query.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          _SearchResults(results: results, onDetails: _showDetails),
        ],
        SizedBox(height: product.sectionGap),
        Row(
          children: [
            const Expanded(child: SectionLabel('Cards worth comparing')),
            Text(
              ref.watch(appConfigProvider).useMocks
                  ? 'DEMO CATALOG'
                  : 'ISSUER TERMS',
              style: TextStyle(
                color: product.muted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: .8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 12.0;
            final columns = constraints.maxWidth >= 700 ? 2 : 1;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final card in popular)
                  SizedBox(
                    width: width,
                    child: _PopularCard(
                      card: card,
                      onDetails: () => _showDetails(card),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _showDetails(CreditCard card) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.product.canvas,
    builder: (context) => _CardDetailSheet(card: card),
  );
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.results, required this.onDetails});

  final List<CreditCard> results;
  final ValueChanged<CreditCard> onDetails;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return AppPanel(
        child: Row(
          children: [
            Icon(Icons.search_off, color: context.product.muted),
            const SizedBox(width: 11),
            const Expanded(child: Text('No cards match this search yet.')),
          ],
        ),
      );
    }
    return AppPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: SectionLabel('${results.length} matching cards'),
          ),
          for (var index = 0; index < results.length; index++) ...[
            if (index > 0) Divider(height: 1, color: context.product.border),
            _SearchResult(
              card: results[index],
              onTap: () => onDetails(results[index]),
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchResult extends StatelessWidget {
  const _SearchResult({required this.card, required this.onTap});

  final CreditCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: ListTile(
      key: ValueKey('search-result-${card.id}'),
      contentPadding: const EdgeInsets.symmetric(vertical: 5),
      onTap: onTap,
      leading: IssuerMark(issuer: card.issuer, size: 44),
      title: Text(
        card.name,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        '${card.issuer} | ${card.multiplier} | Fee ${card.annualFee}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.arrow_forward, size: 17),
    ),
  );
}

class _PopularCard extends StatelessWidget {
  const _PopularCard({required this.card, required this.onDetails});

  final CreditCard card;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) => Material(
    key: ValueKey('strategy-comparison-${card.id}'),
    color: context.product.surface,
    borderRadius: BorderRadius.circular(context.product.radius),
    child: InkWell(
      onTap: onDetails,
      borderRadius: BorderRadius.circular(context.product.radius),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            IssuerMark(issuer: card.issuer, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${card.multiplier} | Fee ${card.annualFee}',
                    style: TextStyle(
                      color: context.product.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward, size: 17, color: context.product.action),
          ],
        ),
      ),
    ),
  );
}

class _CardDetailSheet extends ConsumerWidget {
  const _CardDetailSheet({required this.card});

  final CreditCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = context.product;
    final data = ref.watch(appControllerProvider).data!;
    final owned = data.wallet.any((item) => item.id == card.id);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          product.pagePadding,
          4,
          product.pagePadding,
          product.pagePadding + MediaQuery.paddingOf(context).bottom,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Card details',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close card details',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = math.min(constraints.maxWidth, 320.0);
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: CreditCardArt(
                        card: card,
                        width: width,
                        height: width / 1.586,
                        preferred: true,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  card.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${card.issuer} | Annual fee ${card.annualFee}',
                  style: TextStyle(color: product.muted),
                ),
                if (owned)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      card.termsUnknown
                          ? 'Already in your wallet. You did not add terms for this card, so RevoCred leaves it out of your score and your score may be less accurate than it could be.'
                          : 'Already in your wallet — use this card in your strategy rather than applying again.',
                    ),
                  ),
                ApplyOfferButton(
                  placement: ApplyPlacement.cardDetails,
                  cardId: card.id,
                ),
                const SizedBox(height: 18),
                AppPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionLabel('Best use'),
                      const SizedBox(height: 7),
                      Text(
                        card.bestUse,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 13),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          StatusPill(label: card.multiplier),
                          StatusPill(
                            label: 'FEE ${card.annualFee}',
                            color: product.warning,
                          ),
                          if (card.transferablePoints)
                            StatusPill(
                              label: 'TRANSFERABLE',
                              color: product.success,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const SectionLabel('Reward rates'),
                const SizedBox(height: 8),
                for (final item in card.pointMultipliers)
                  _DetailRow(icon: Icons.bolt_outlined, text: item),
                const SizedBox(height: 14),
                const SectionLabel('Benefits'),
                const SizedBox(height: 8),
                for (final item in card.benefits)
                  _DetailRow(icon: Icons.check_circle_outline, text: item),
                if (card.communityData != null)
                  CommunityCardDetails(data: card.communityData!),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: product.warning.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(product.radius),
                  ),
                  child: Text(
                    card.sourceDisclaimer.isEmpty
                        ? 'Confirm current rewards, fees, eligibility, and terms with the issuer. Educational use only.'
                        : card.sourceDisclaimer,
                    style: TextStyle(
                      color: product.muted,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: context.product.action),
        const SizedBox(width: 9),
        Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
      ],
    ),
  );
}
