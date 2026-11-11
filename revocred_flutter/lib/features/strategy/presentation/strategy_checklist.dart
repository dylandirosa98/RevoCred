import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logic/strategy_digest.dart';
import '../../../core/models/affiliate_offer.dart';
import '../../../core/models/app_models.dart';
import '../../../core/state/app_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/apply_offer_button.dart';
import '../../../shared/widgets/content_layout.dart';
import '../../../shared/widgets/issuer_mark.dart';

/// The Strategy tab as a to-do list: the next card first, with Apply and
/// "I got this card", then the rest of the plan in order. The full poster
/// layout lives in the shareable report.
class StrategyChecklist extends ConsumerWidget {
  const StrategyChecklist({required this.data, this.onCardDetails, super.key});

  final AppData data;
  final ValueChanged<CreditCard>? onCardDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = context.product;
    final plan = data.strategyPlan!;
    final slots = strategyRoadmapSlots(data);
    final done = slots.where((slot) => slot.isCovered).length;
    final needed = slots
        .where((slot) => slot.status != StrategySlotStatus.unavailable)
        .length;
    final canMark = ref.watch(appControllerProvider).isAuthenticated;
    final next = slots
        .where((slot) => slot.status == StrategySlotStatus.next)
        .firstOrNull;
    final rest = slots.where((slot) => !identical(slot, next)).toList();

    return Column(
      key: const ValueKey('strategy-checklist'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'YOUR PLAN',
          style: TextStyle(
            color: product.muted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(plan.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 10),
        Text(
          '$done of $needed in place',
          key: const ValueKey('strategy-progress'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Semantics(
          label: '$done of $needed cards in place',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: needed == 0 ? 0 : done / needed,
              minHeight: 8,
              backgroundColor: product.subtle,
              color: product.success,
            ),
          ),
        ),
        SizedBox(height: product.sectionGap),
        if (next != null) ...[
          const SectionLabel('Next card'),
          const SizedBox(height: 10),
          AppPanel(
            key: const ValueKey('strategy-next-card'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SlotHeader(
                  data: data,
                  slot: next,
                  onCardDetails: onCardDetails,
                ),
                const SizedBox(height: 6),
                Text(
                  strategyTimingCaption(next),
                  style: TextStyle(color: product.muted, fontSize: 13),
                ),
                const ApplyOfferButton(placement: ApplyPlacement.strategy),
                if (canMark)
                  _GotItButton(data: data, slot: next, primary: true),
              ],
            ),
          ),
          SizedBox(height: product.sectionGap),
        ] else if (needed > 0 && done >= needed) ...[
          AppPanel(
            key: const ValueKey('strategy-complete'),
            child: Row(
              children: [
                Icon(Icons.verified_outlined, color: product.success),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Every card in your plan is in place. Keep using each one where it earns the most.',
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: product.sectionGap),
        ],
        const SectionLabel('Checklist'),
        const SizedBox(height: 10),
        AppPanel(
          child: Column(
            children: [
              for (final (index, slot) in rest.indexed) ...[
                if (index > 0) Divider(height: 20, color: product.border),
                _ChecklistRow(
                  data: data,
                  slot: slot,
                  canMark: canMark,
                  onCardDetails: onCardDetails,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.data,
    required this.slot,
    required this.canMark,
    this.onCardDetails,
  });

  final AppData data;
  final StrategyRoadmapSlot slot;
  final bool canMark;
  final ValueChanged<CreditCard>? onCardDetails;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    final skipped = slot.status == StrategySlotStatus.unavailable;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SlotHeader(data: data, slot: slot, onCardDetails: onCardDetails),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 34),
          child: Text(
            strategyTimingCaption(slot),
            style: TextStyle(color: product.muted, fontSize: 12),
          ),
        ),
        if (canMark && !slot.isCovered && !skipped)
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _GotItButton(data: data, slot: slot),
            ),
          ),
      ],
    );
  }
}

class _SlotHeader extends StatelessWidget {
  const _SlotHeader({
    required this.data,
    required this.slot,
    this.onCardDetails,
  });

  final AppData data;
  final StrategyRoadmapSlot slot;
  final ValueChanged<CreditCard>? onCardDetails;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    final card = strategySlotCard(data, slot);
    final (icon, color, label) = switch (slot.status) {
      StrategySlotStatus.completed || StrategySlotStatus.substituted => (
        Icons.check_circle,
        product.success,
        'Done',
      ),
      StrategySlotStatus.next => (
        Icons.radio_button_unchecked,
        product.action,
        'Next',
      ),
      StrategySlotStatus.later => (
        Icons.radio_button_unchecked,
        product.muted,
        'Later',
      ),
      StrategySlotStatus.unavailable => (
        Icons.remove_circle_outline,
        product.muted,
        'Not needed now',
      ),
    };
    final title = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: label,
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                slot.displayName,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  decoration: slot.isCovered
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  decorationColor: product.muted,
                ),
              ),
              if (slot.use.isNotEmpty)
                Text(
                  slot.use,
                  style: TextStyle(color: product.muted, fontSize: 13),
                ),
            ],
          ),
        ),
        if (card != null) ...[
          const SizedBox(width: 8),
          IssuerMark(issuer: card.issuer, size: 30),
        ],
      ],
    );
    if (card == null || onCardDetails == null) return title;
    return InkWell(
      key: ValueKey('strategy-slot-${card.id}'),
      borderRadius: BorderRadius.circular(8),
      onTap: () => onCardDetails!(card),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: title,
      ),
    );
  }
}

/// Adds the plan's card to the wallet, which marks the step done.
class _GotItButton extends ConsumerStatefulWidget {
  const _GotItButton({
    required this.data,
    required this.slot,
    this.primary = false,
  });

  final AppData data;
  final StrategyRoadmapSlot slot;
  final bool primary;

  @override
  ConsumerState<_GotItButton> createState() => _GotItButtonState();
}

class _GotItButtonState extends ConsumerState<_GotItButton> {
  var saving = false;

  @override
  Widget build(BuildContext context) {
    final card = strategySlotCard(widget.data, widget.slot);
    if (card == null || card.isActive) return const SizedBox.shrink();
    final onPressed = saving ? null : () => _markOwned(card);
    const label = Text('I got this card');
    final icon = saving
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.check);
    final key = ValueKey('strategy-got-${card.id}');
    return widget.primary
        ? OutlinedButton.icon(
            key: key,
            onPressed: onPressed,
            icon: icon,
            label: label,
          )
        : TextButton.icon(
            key: key,
            onPressed: onPressed,
            icon: icon,
            label: label,
          );
  }

  Future<void> _markOwned(CreditCard card) async {
    setState(() => saving = true);
    await ref.read(appControllerProvider.notifier).addCard(card.id);
    if (mounted) setState(() => saving = false);
  }
}
