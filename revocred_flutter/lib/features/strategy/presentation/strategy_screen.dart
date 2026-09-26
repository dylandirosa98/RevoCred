import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logic/card_search.dart';
import '../../../core/models/app_models.dart';
import '../../../core/models/affiliate_offer.dart';
import '../../../shared/widgets/apply_offer_button.dart';
import '../../../core/state/app_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/content_layout.dart';
import '../../../shared/widgets/credit_card_view.dart';

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
    final nextStep = playbook?.steps
        .where((step) => step.status == 'next')
        .firstOrNull;
    final firstStep = nextStep == null
        ? (playbook == null ? data.roadmap.firstOrNull : null)
        : RoadmapStep(
            id: 'next',
            cardId: nextStep.name,
            stage: 'Consider next',
            note: nextStep.use,
            estimatedValue: 0,
          );
    final firstCard = firstStep == null ? null : _cardFor(data, firstStep);
    final popular = data.catalog
        .where((card) => !card.isActive)
        .take(4)
        .toList();

    return ContentLayout(
      maxWidth: 1040,
      children: [
        Row(
          children: [
            const Expanded(child: SectionLabel('Strategy')),
            StatusPill(
              label: '${data.roadmap.length} ROADMAP STEPS',
              color: product.action,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text('Your roadmap', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 7),
        Text(
          playbook == null
              ? 'A prioritized path built by the deterministic recommendation model.'
              : '${playbook.code}: ${playbook.title}. Current eligibility and wallet value determine the next step.',
          style: TextStyle(color: product.muted, fontSize: 15),
        ),
        const SizedBox(height: 16),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR RECOMMENDED STRATEGY',
                style: TextStyle(
                  color: product.action,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${data.strategyPlan?.code ?? ''} ${data.strategyPlan?.title ?? 'Build your personal plan'}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                data.recommendedCardId == null
                    ? 'No new card currently improves your modeled wallet. Keep your existing cards, or review your answers.'
                    : 'Start with ${data.profile.nextTarget}. This is the highest-ranked eligible improvement for your spending and wallet. Explore other cards below, but add one only if it supports your plan.',
              ),
              TextButton(
                onPressed: () => context.push('/questionnaire'),
                child: const Text('Review my answers'),
              ),
              for (final reason in data.nextCardReasons)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('• $reason'),
                ),
            ],
          ),
        ),
        SizedBox(height: product.sectionGap),
        _RoadmapSummary(
          key: const ValueKey('strategy-summary'),
          stepCount: data.roadmap.length,
          walletCount: data.wallet.length,
          nextStage: firstStep?.stage ?? 'Not available',
          topValue: firstStep?.estimatedValue ?? 0,
        ),
        SizedBox(height: product.sectionGap),
        if (firstStep != null) ...[
          const SectionLabel('Next best move'),
          const SizedBox(height: 10),
          _PrimaryRecommendation(
            key: const ValueKey('strategy-next-action'),
            step: firstStep,
            card: firstCard,
            onDetails: firstCard == null ? null : () => _showDetails(firstCard),
            onAskRevo: firstCard == null
                ? null
                : () {
                    context.go('/revo');
                    ref
                        .read(appControllerProvider.notifier)
                        .sendMessage(
                          'Explain why ${firstCard.name} is my next roadmap step.',
                        );
                  },
          ),
        ] else
          const AppPanel(
            child: Text(
              'No eligible improvement is currently available. Update your questionnaire or keep your current wallet.',
            ),
          ),
        const ApplyOfferButton(placement: ApplyPlacement.strategy),
        if ((playbook?.steps.where((step) => step.status != 'next').length ??
                0) >
            0) ...[
          SizedBox(height: product.sectionGap),
          const SectionLabel('Playbook sequence'),
          const SizedBox(height: 12),
          Column(
            key: const ValueKey('strategy-timeline'),
            children: [
              for (final step in playbook!.steps.where(
                (step) => step.status != 'next',
              ))
                _TimelineStep(
                  position: playbook.steps.indexOf(step) + 1,
                  last: step == playbook.steps.last,
                  step: RoadmapStep(
                    id: step.name,
                    cardId: step.name,
                    stage: switch (step.status) {
                      'have' => 'Already in wallet',
                      'unavailable' => 'Not currently recommended',
                      _ => 'Later',
                    },
                    note: step.note.isEmpty ? step.use : step.note,
                    estimatedValue: 0,
                  ),
                  card: _cardFor(
                    data,
                    RoadmapStep(
                      id: step.name,
                      cardId: step.name,
                      stage: '',
                      note: '',
                      estimatedValue: 0,
                    ),
                  ),
                  onDetails: () {
                    final card = _cardFor(
                      data,
                      RoadmapStep(
                        id: step.name,
                        cardId: step.name,
                        stage: '',
                        note: '',
                        estimatedValue: 0,
                      ),
                    );
                    if (card != null) _showDetails(card);
                  },
                ),
            ],
          ),
        ] else if (data.roadmap.length > 1) ...[
          SizedBox(height: product.sectionGap),
          const SectionLabel('Application timeline'),
          const SizedBox(height: 12),
          Column(
            key: const ValueKey('strategy-timeline'),
            children: [
              for (var index = 1; index < data.roadmap.length; index++)
                _TimelineStep(
                  position: index + 1,
                  last: index == data.roadmap.length - 1,
                  step: data.roadmap[index],
                  card: _cardFor(data, data.roadmap[index]),
                  onDetails: () {
                    final card = _cardFor(data, data.roadmap[index]);
                    if (card != null) _showDetails(card);
                  },
                ),
            ],
          ),
        ],
        SizedBox(height: product.sectionGap),
        _ModelNotice(goal: data.profile.goal),
        SizedBox(height: product.sectionGap),
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
        const SectionLabel('Nearby strategies'),
        const SizedBox(height: 10),
        if (playbook != null && playbook.alternatives.isNotEmpty)
          Column(
            children: [
              for (final alt in playbook.alternatives)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${alt.code}  ${alt.title}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          alt.reason,
                          style: TextStyle(color: product.muted),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
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
                  : 'ISSUER SNAPSHOTS',
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

  CreditCard? _cardFor(AppData data, RoadmapStep step) =>
      data.catalog
          .where((card) => card.id == step.cardId || card.name == step.cardId)
          .firstOrNull ??
      data.wallet
          .where((card) => card.id == step.cardId || card.name == step.cardId)
          .firstOrNull ??
      CreditCard(
        id: step.cardId,
        issuer: data.playbook?.ecosystem ?? '',
        brand: data.playbook?.ecosystem ?? '',
        name: step.cardId,
        annualFee: 'See issuer',
        bestUse: step.note,
        multiplier: '',
        benefits: const ['Playbook card. Verify current issuer terms.'],
      );

  Future<void> _showDetails(CreditCard card) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.product.canvas,
    builder: (context) => _CardDetailSheet(card: card),
  );
}

class _RoadmapSummary extends StatelessWidget {
  const _RoadmapSummary({
    required this.stepCount,
    required this.walletCount,
    required this.nextStage,
    required this.topValue,
    super.key,
  });

  final int stepCount;
  final int walletCount;
  final String nextStage;
  final int topValue;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    return AppPanel(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 17),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _SummaryMetric(
              label: 'NEXT WINDOW',
              value: nextStage,
              color: product.action,
            ),
          ),
          _MetricDivider(color: product.border),
          Expanded(
            child: _SummaryMetric(
              label: 'MODELED VALUE',
              value: '\$$topValue',
              color: product.success,
            ),
          ),
          _MetricDivider(color: product.border),
          Expanded(
            child: _SummaryMetric(
              label: 'WALLET / PLAN',
              value: '$walletCount / $stepCount',
              color: product.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 5),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 2,
          style: TextStyle(
            color: context.product.muted,
            fontSize: 8,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: .6,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 15,
            height: 1.05,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 48, color: color);
}

class _PrimaryRecommendation extends StatelessWidget {
  const _PrimaryRecommendation({
    required this.step,
    required this.card,
    required this.onDetails,
    required this.onAskRevo,
    super.key,
  });

  final RoadmapStep step;
  final CreditCard? card;
  final VoidCallback? onDetails;
  final VoidCallback? onAskRevo;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    final emphasized =
        product.heroTreatment == HeroTreatment.decision ||
        product.heroTreatment == HeroTreatment.walletStudio;
    final foreground = emphasized ? Colors.white : product.ink;
    final muted = emphasized
        ? Colors.white.withValues(alpha: .65)
        : product.muted;
    return Container(
      decoration: BoxDecoration(
        color: emphasized ? const Color(0xFF17151C) : product.subtle,
        border: emphasized ? null : Border.all(color: product.border),
        borderRadius: BorderRadius.circular(product.radius),
      ),
      padding: EdgeInsets.all(product.panelPadding + 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 560;
          final cardArt = card == null
              ? const SizedBox.shrink()
              : CreditCardArt(
                  card: card!,
                  width: wide ? 185 : math.min(constraints.maxWidth, 260),
                  height: wide
                      ? 116
                      : math.min(constraints.maxWidth, 260) / 1.586,
                  preferred: true,
                );
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: emphasized
                            ? Colors.white.withValues(alpha: .1)
                            : product.surface,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        step.stage.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: emphasized
                              ? product.brightAccent
                              : product.action,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .7,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Flexible(
                    flex: 2,
                    child: Text(
                      'MODEL RANK 01',
                      maxLines: 2,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: muted,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                card?.name ?? step.cardId,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: foreground,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(step.note, style: TextStyle(color: muted, height: 1.45)),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Estimated first-year demo value',
                      style: TextStyle(color: muted, fontSize: 10),
                    ),
                  ),
                  Text(
                    '\$${step.estimatedValue}',
                    style: TextStyle(
                      color: emphasized
                          ? product.brightAccent
                          : product.success,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    key: const ValueKey('strategy-next-details'),
                    onPressed: onDetails,
                    style: emphasized
                        ? OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: .28),
                            ),
                          )
                        : null,
                    child: const Text('View details'),
                  ),
                  FilledButton.icon(
                    onPressed: onAskRevo,
                    style: emphasized
                        ? FilledButton.styleFrom(
                            backgroundColor: product.action,
                            foregroundColor: product.actionInk,
                          )
                        : null,
                    icon: const Icon(Icons.auto_awesome, size: 15),
                    label: const Text('Ask REVO'),
                  ),
                ],
              ),
            ],
          );
          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [cardArt, const SizedBox(height: 18), content],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              cardArt,
              const SizedBox(width: 22),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.position,
    required this.last,
    required this.step,
    required this.card,
    required this.onDetails,
  });

  final int position;
  final bool last;
  final RoadmapStep step;
  final CreditCard? card;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 35,
            child: Column(
              children: [
                Container(
                  width: 27,
                  height: 27,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: product.subtle,
                    border: Border.all(color: product.action),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$position',
                    style: TextStyle(
                      color: product.action,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (!last)
                  Expanded(child: Container(width: 1, color: product.border)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppPanel(
                padding: const EdgeInsets.all(14),
                child: InkWell(
                  onTap: card == null ? null : onDetails,
                  borderRadius: BorderRadius.circular(product.radius),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (card != null) ...[
                        CreditCardArt(card: card!, width: 82, height: 52),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    card?.name ?? step.cardId,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Text(
                                  '\$${step.estimatedValue}',
                                  style: TextStyle(
                                    color: product.success,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              step.stage.toUpperCase(),
                              style: TextStyle(
                                color: product.action,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .6,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              step.note,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: product.muted,
                                fontSize: 11,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelNotice extends StatelessWidget {
  const _ModelNotice({required this.goal});
  final String goal;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: product.success.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(product.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_outlined, color: product.success, size: 20),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Grounded in your demo profile',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  'Goal: $goal. Terms and approval rules can change, so confirm issuer details before applying.',
                  style: TextStyle(
                    color: product.muted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
      leading: CreditCardArt(card: card, width: 72, height: 45),
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
    color: context.product.surface,
    borderRadius: BorderRadius.circular(context.product.radius),
    child: InkWell(
      onTap: onDetails,
      borderRadius: BorderRadius.circular(context.product.radius),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            CreditCardArt(card: card, width: 82, height: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.name,
                    maxLines: 1,
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
