import 'package:flutter/material.dart';

import '../../../core/logic/strategy_digest.dart';
import '../../../core/logic/strategy_report_copy.dart';
import '../../../core/models/app_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/content_layout.dart';
import '../../../shared/widgets/credit_card_view.dart';
import 'report_branding.dart';

/// The canonical, reusable presentation of a RevoCred strategy.
///
/// The strategy tab and report screen both render this widget. The PDF export
/// follows the same section order so downloading a plan feels like exporting
/// what the member was just looking at rather than receiving a different
/// document.
class StrategyRoadmapView extends StatelessWidget {
  const StrategyRoadmapView({
    super.key,
    required this.data,
    this.showStatus = true,
    this.onCardDetails,
  });

  final AppData data;
  final bool showStatus;
  final ValueChanged<CreditCard>? onCardDetails;

  @override
  Widget build(BuildContext context) {
    final digest = strategyDigest(data);
    final plan = data.strategyPlan!;
    final slots = strategyRoadmapSlots(data);
    final covered = slots.where((slot) => slot.isCovered).length;
    final product = context.product;

    return Column(
      key: const ValueKey('strategy-roadmap-view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 20,
            runSpacing: 16,
            children: [
              const SizedBox(
                width: 290,
                child: FittedBox(
                  alignment: Alignment.center,
                  fit: BoxFit.scaleDown,
                  child: ReportBrand(),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) => SizedBox(
                  width: constraints.maxWidth.clamp(0, 290),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ReportScore(score: data.pointsValue),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: product.sectionGap),
        _StrategyHero(data: data, digest: digest, showStatus: showStatus),
        SizedBox(height: product.sectionGap),
        _OverviewGrid(data: data, plan: plan),
        SizedBox(height: product.sectionGap),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 6,
          children: [
            const SectionLabel('Your strategy roadmap'),
            Text(
              '$covered OF ${slots.length} ROLES COVERED',
              style: TextStyle(
                color: product.muted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: .8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '$strategyRolesExplanation\n$strategyEligibilityExplanation',
          style: TextStyle(color: product.muted, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 12),
        if (slots.isEmpty)
          AppPanel(
            child: Text(
              'No new application is recommended right now. Keep using your current wallet and review the plan when your needs change.',
              style: TextStyle(color: product.muted, height: 1.45),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 820
                  ? slots.length.clamp(1, 4)
                  : constraints.maxWidth >= 560
                  ? 2
                  : 1;
              const gap = 12.0;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                key: const ValueKey('strategy-timeline'),
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final entry in slots.indexed)
                    SizedBox(
                      width: width,
                      child: _RoadmapCard(
                        number: entry.$1 + 1,
                        slot: entry.$2,
                        card: strategyCardFor(data, entry.$2.displayName),
                        onCardDetails: onCardDetails,
                      ),
                    ),
                ],
              );
            },
          ),
        SizedBox(height: product.sectionGap),
        _StrategyProgress(slots: slots),
        if (data.wallet.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'CURRENT WALLET (${data.wallet.length} CARDS): ${data.wallet.map((card) => card.name).join(' • ')}',
            style: TextStyle(fontSize: 11, color: product.muted),
          ),
        ],
        SizedBox(height: product.sectionGap),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 700;
            final together = _HowTheyWorkTogether(data: data);
            final result = _StrategyResult(data: data);
            if (!wide) {
              return Column(
                children: [
                  together,
                  SizedBox(height: product.sectionGap),
                  result,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: together),
                const SizedBox(width: 14),
                Expanded(flex: 2, child: result),
              ],
            );
          },
        ),
        SizedBox(height: product.sectionGap),
        const _EducationReminder(),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xff101018),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 24,
            runSpacing: 12,
            children: [
              const SizedBox(width: 205, child: ReportBrand(onDark: true)),
              Column(
                children: [
                  Text(
                    'SAME SPENDING. MORE REWARDS.',
                    style: TextStyle(
                      color: const Color(0xffa46bff),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'Plan today. Travel tomorrow.',
                    style: TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StrategyHero extends StatelessWidget {
  const _StrategyHero({
    required this.data,
    required this.digest,
    required this.showStatus,
  });

  final AppData data;
  final StrategyDigest digest;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    final plan = data.strategyPlan!;
    return Container(
      key: const ValueKey('strategy-summary'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: product.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showStatus)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [_HeroPill(label: '${plan.code} STRATEGY')],
            ),
          if (showStatus) const SizedBox(height: 18),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: digest.title
                      .replaceFirst('Credit Card Strategy', '')
                      .toUpperCase(),
                ),
                TextSpan(
                  text: 'CREDIT CARD STRATEGY',
                  style: TextStyle(color: product.action),
                ),
              ],
            ),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: product.ink,
              fontFamily: 'Anton',
              fontSize: MediaQuery.sizeOf(context).width >= 800 ? 48 : 34,
              fontWeight: FontWeight.w400,
              height: 1.04,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'A ${strategyRoadmapSlots(data).length}-role plan to maximize your rewards and reach your goals. ${data.wallet.length} cards currently in your wallet.',
            style: TextStyle(color: product.ink, fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 8),
          Container(
            key: const ValueKey('strategy-next-action'),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome, color: product.action, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YOUR NEXT MOVE',
                        style: TextStyle(
                          color: product.action,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .9,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        digest.nextMove,
                        style: TextStyle(
                          color: product.ink,
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                        ),
                      ),
                    ],
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

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: context.product.action.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: context.product.action,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: .6,
      ),
    ),
  );
}

class _OverviewGrid extends StatelessWidget {
  const _OverviewGrid({required this.data, required this.plan});
  final AppData data;
  final StrategyPlan plan;

  @override
  Widget build(BuildContext context) {
    final spending =
        data.monthlySpend.entries.where((entry) => entry.value > 0).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final items = [
      (Icons.track_changes, 'Your goal', plan.goal),
      (
        Icons.style_outlined,
        'Annual fee preference',
        strategyFeePreference(data),
      ),
      (Icons.flight_takeoff, 'Travel focus', plan.travelScope),
      (
        Icons.shopping_cart_outlined,
        'Top spending',
        spending.isEmpty
            ? data.profile.topSpendCategories
            : spending.take(3).map((entry) => _title(entry.key)).join(', '),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? 4
            : constraints.maxWidth >= 480
            ? 2
            : 1;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _OverviewTile(
                  icon: item.$1,
                  label: item.$2,
                  value: item.$3,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OverviewTile extends StatelessWidget {
  const _OverviewTile({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => _ReportPanel(
    padding: const EdgeInsets.all(15),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: context.product.action, size: 32),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 17,
                  fontFamily: 'Anton',
                  letterSpacing: .65,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                style: TextStyle(
                  color: context.product.muted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RoadmapCard extends StatelessWidget {
  const _RoadmapCard({
    required this.number,
    required this.slot,
    required this.card,
    required this.onCardDetails,
  });

  final int number;
  final StrategyRoadmapSlot slot;
  final CreditCard? card;
  final ValueChanged<CreditCard>? onCardDetails;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    final benefits = card?.benefits.take(3).toList() ?? const <String>[];
    final isNext = slot.status == StrategySlotStatus.next;
    final isCovered = slot.isCovered;
    final header = switch (slot.status) {
      StrategySlotStatus.completed => 'IN YOUR WALLET',
      StrategySlotStatus.substituted => 'COVERED BY OWNED CARD',
      StrategySlotStatus.next => 'RECOMMENDED NEXT',
      StrategySlotStatus.later => 'FUTURE OPTION',
      StrategySlotStatus.unavailable => 'NOT CURRENTLY NEEDED',
    };
    return Material(
      color: product.surface,
      borderRadius: BorderRadius.circular(product.radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: isNext
            ? const ValueKey('strategy-next-details')
            : ValueKey('strategy-roadmap-card-$number'),
        onTap: card == null || onCardDetails == null
            ? null
            : () => onCardDetails!(card!),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: product.border),
            borderRadius: BorderRadius.circular(product.radius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                color: isCovered || isNext ? product.action : product.ink,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ROLE $number: $header',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Anton',
                        fontSize: 19,
                        letterSpacing: .45,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      strategyTimingCaption(slot),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .8),
                        fontSize: 12,
                      ),
                    ),
                    if (slot.status == StrategySlotStatus.substituted)
                      Text(
                        'Replacing ${slot.targetName}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (card != null) ...[
                      LayoutBuilder(
                        builder: (context, constraints) => CreditCardArt(
                          card: card!,
                          width: constraints.maxWidth,
                          height: constraints.maxWidth / 1.586,
                          preferred: isNext,
                        ),
                      ),
                      const SizedBox(height: 13),
                    ],
                    Text(
                      card?.name ?? slot.displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontFamily: 'Anton',
                        fontSize: 21,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      slot.note.isEmpty
                          ? isCovered
                                ? 'This role is already covered by your current wallet.'
                                : 'This card fills the ${slot.targetName} role in your strategy.'
                          : slot.note,
                      style: TextStyle(color: product.muted, height: 1.4),
                    ),
                    if (_eligibilityNote(card, slot) case final note?)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          note,
                          style: TextStyle(
                            color: product.warning,
                            fontSize: 12,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (benefits.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      for (final benefit in benefits) _CheckLine(text: benefit),
                    ],
                    if (card != null && onCardDetails != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'View card details',
                        style: TextStyle(
                          color: product.action,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Eligibility caveat for roadmap steps the member must still qualify for.
/// Shown only on actionable future steps with an elevated catalog tier, so
/// starter cards never carry a warning and owned cards stay quiet.
String? _eligibilityNote(CreditCard? card, StrategyRoadmapSlot slot) {
  if (slot.isCovered ||
      (slot.status != StrategySlotStatus.next &&
          slot.status != StrategySlotStatus.later)) {
    return null;
  }
  return switch (card?.minimumCreditTier) {
    'excellent' =>
      'Requires excellent credit — unlocks once your score qualifies. The earlier steps build that history.',
    'good' =>
      'Requires good credit or better — apply once your score qualifies.',
    _ => null,
  };
}

class _CheckLine extends StatelessWidget {
  const _CheckLine({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle, color: context.product.action, size: 17),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
      ],
    ),
  );
}

class _StrategyProgress extends StatelessWidget {
  const _StrategyProgress({required this.slots});
  final List<StrategyRoadmapSlot> slots;

  @override
  Widget build(BuildContext context) => _ReportPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.route_outlined, color: context.product.action),
            const SizedBox(width: 9),
            const Expanded(child: ReportHeading('Application timeline')),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 700) {
              return Column(
                children: [
                  for (final entry in slots.indexed)
                    _ProgressRow(
                      number: entry.$1 + 1,
                      slot: entry.$2,
                      last: entry.$1 == slots.length - 1,
                    ),
                ],
              );
            }
            return Wrap(
              spacing: 12,
              runSpacing: 16,
              children: [
                for (final entry in slots.indexed)
                  SizedBox(
                    width:
                        (constraints.maxWidth -
                            (slots.length.clamp(1, 4) - 1) * 12) /
                        slots.length.clamp(1, 4),
                    child: Column(
                      children: [
                        CircleAvatar(
                          backgroundColor: context.product.action,
                          child: Text(
                            '${entry.$1 + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Anton',
                              fontSize: 24,
                            ),
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          entry.$2.timing,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.product.action,
                            fontFamily: 'Anton',
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          entry.$2.displayName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          entry.$2.timingNote,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.number,
    required this.slot,
    required this.last,
  });
  final int number;
  final StrategyRoadmapSlot slot;
  final bool last;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 34,
          child: Column(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: slot.isCovered
                    ? context.product.success
                    : context.product.action,
                child: slot.isCovered
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : Text(
                        '$number',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
              if (!last)
                Expanded(
                  child: Container(width: 2, color: context.product.border),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  switch (slot.status) {
                    StrategySlotStatus.completed => 'In your wallet',
                    StrategySlotStatus.substituted =>
                      'Covered by an owned substitute',
                    StrategySlotStatus.next => 'Recommended next',
                    StrategySlotStatus.later => 'Future option',
                    StrategySlotStatus.unavailable => 'Not currently needed',
                  },
                  style: TextStyle(
                    color: context.product.action,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  slot.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  slot.timing,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  slot.timingNote,
                  style: TextStyle(
                    color: context.product.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  slot.status == StrategySlotStatus.substituted
                      ? 'Keep this card for the ${slot.targetName} role. No replacement application is needed.'
                      : slot.note,
                  style: TextStyle(
                    color: context.product.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _HowTheyWorkTogether extends StatelessWidget {
  const _HowTheyWorkTogether({required this.data});
  final AppData data;

  @override
  Widget build(BuildContext context) {
    final slots = strategyRoadmapSlots(data);
    return _ReportPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings_suggest, color: context.product.action),
              const SizedBox(width: 9),
              const Expanded(child: ReportHeading('How they work together')),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = MediaQuery.textScalerOf(context).scale(12) > 16
                  ? 1
                  : constraints.maxWidth >= 420
                  ? 4
                  : constraints.maxWidth >= 240
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 10) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 14,
                children: [
                  for (final slot in slots)
                    SizedBox(
                      width: width,
                      child: _UsageTile(data: data, slot: slot, width: width),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _UsageTile extends StatelessWidget {
  const _UsageTile({
    required this.data,
    required this.slot,
    required this.width,
  });
  final AppData data;
  final StrategyRoadmapSlot slot;
  final double width;

  @override
  Widget build(BuildContext context) {
    final card = strategyCardFor(data, slot.displayName);
    return Column(
      children: [
        Icon(
          _useIcon(card?.bestUse ?? slot.use),
          color: context.product.action,
          size: 30,
        ),
        const SizedBox(height: 6),
        Text(
          card?.bestUse ?? slot.use,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        if (card != null)
          CreditCardArt(card: card, width: width, height: width / 1.6),
        const SizedBox(height: 8),
        Text(
          slot.displayName,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          slot.isCovered
              ? 'Ready to use'
              : slot.status == StrategySlotStatus.unavailable
              ? 'Not currently recommended'
              : 'Use after acquisition',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: context.product.muted),
        ),
      ],
    );
  }
}

class _StrategyResult extends StatelessWidget {
  const _StrategyResult({required this.data});
  final AppData data;

  @override
  Widget build(BuildContext context) {
    final targetCards = strategyTargetCards(data);
    final totalFees = targetCards.fold<int>(
      0,
      (sum, card) => sum + _money(card.annualFee),
    );
    final feesKnown =
        targetCards.length == strategyRoadmapSlots(data).length &&
        targetCards.every((card) => !card.termsUnknown);
    return _ReportPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart, color: context.product.action),
              const SizedBox(width: 9),
              const Expanded(child: ReportHeading('Your potential rewards')),
            ],
          ),
          const SizedBox(height: 16),

          const _ResultLine(
            label: 'Travel redemption uplift',
            value: 'Not modeled',
            icon: Icons.flight_takeoff,
          ),
          _ResultLine(
            label: 'Target wallet cards',
            value: '${targetCards.length}',
            icon: Icons.credit_card_outlined,
          ),
          _ResultLine(
            label: 'Target annual fees',
            value: feesKnown ? '\$$totalFees' : 'Not fully verified',
            icon: Icons.account_balance_wallet_outlined,
          ),
          _ResultLine(
            label: 'Primary goal',
            value: data.strategyPlan!.goal,
            icon: Icons.flag_outlined,
            last: true,
          ),
          const SizedBox(height: 18),
          Container(
            key: const ValueKey('strategy-net-value'),
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: context.product.action),
              color: context.product.action.withValues(alpha: .04),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      color: context.product.action,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ESTIMATED ONGOING YEARLY VALUE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .6,
                          color: context.product.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '\$${data.projectedYearlyValue}',
                        style: TextStyle(
                          fontFamily: 'Anton',
                          fontSize: 30,
                          color: context.product.action,
                        ),
                      ),
                      TextSpan(
                        text: ' / year',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.product.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            strategyValueExplanation(data),
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: context.product.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultLine extends StatelessWidget {
  const _ResultLine({
    required this.label,
    required this.value,
    required this.icon,
    this.last = false,
  });
  final String label;
  final String value;
  final IconData icon;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      border: last
          ? null
          : Border(
              bottom: BorderSide(
                color: context.product.action.withValues(alpha: .12),
              ),
            ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: context.product.action, size: 20),
        const SizedBox(width: 10),
        Expanded(
          flex: 5,
          child: Text(
            label,
            key: ValueKey('reward-label-$label'),
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: context.product.muted,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 4,
          child: Text(
            value,
            key: ValueKey('reward-value-$label'),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: value.startsWith('\$') || int.tryParse(value) != null
                  ? 20
                  : 13,
              fontFamily: value.startsWith('\$') || int.tryParse(value) != null
                  ? 'Anton'
                  : 'SpaceGrotesk',
              fontWeight: FontWeight.w700,
              height: 1.25,
              color: context.product.action,
            ),
          ),
        ),
      ],
    ),
  );
}

class _EducationReminder extends StatelessWidget {
  const _EducationReminder();

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('strategy-education-reminder'),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.product.action.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(context.product.radius),
      border: Border.all(color: context.product.action.withValues(alpha: .2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.school_outlined,
              color: context.product.action,
              size: 22,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Keep rewards in perspective',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Pay every statement balance in full, space applications, and verify current issuer terms before applying. Interest can erase the value of rewards.',
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: context.product.muted,
          ),
        ),
      ],
    ),
  );
}

String _title(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

int _money(String value) =>
    int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

IconData _useIcon(String use) {
  final text = use.toLowerCase();
  if (text.contains('travel') || text.contains('transfer')) return Icons.flight;
  if (text.contains('dining')) return Icons.restaurant;
  if (text.contains('grocer')) return Icons.shopping_cart_outlined;
  if (text.contains('rotating')) return Icons.category_outlined;
  return Icons.shopping_bag_outlined;
}

class _ReportPanel extends StatelessWidget {
  const _ReportPanel({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xff211a30)
          : const Color(0xfff6f2ff),
      borderRadius: BorderRadius.circular(10),
    ),
    child: child,
  );
}
