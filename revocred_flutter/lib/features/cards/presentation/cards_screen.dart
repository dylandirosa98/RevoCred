import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logic/wallet_score.dart';
import '../../../core/models/app_models.dart';
import '../../../core/state/app_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/content_layout.dart';
import '../../../shared/widgets/credit_card_view.dart';
import '../../../shared/widgets/custom_card_form.dart';

class CardsScreen extends ConsumerStatefulWidget {
  const CardsScreen({super.key});

  @override
  ConsumerState<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends ConsumerState<CardsScreen> {
  bool showPicker = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final data = state.data!;
    final product = context.product;
    final activeIds = data.wallet.map((card) => card.id).toSet();
    final available = data.catalog
        .where((card) => !activeIds.contains(card.id))
        .toList();
    return ContentLayout(
      children: [
        Row(
          children: [
            const Expanded(child: SectionLabel('Wallet')),
            StatusPill(
              label: '${data.wallet.length} ACTIVE',
              color: product.success,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Your card setup',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 7),
        Text(
          'Tap a partially visible card to make it preferred and see its best use.',
          style: TextStyle(color: product.muted),
        ),
        SizedBox(height: product.sectionGap),
        LayoutBuilder(
          builder: (context, constraints) {
            final stack = WalletCardStack(
              cards: data.wallet,
              onAskRevo: _askRevo,
              onRemove: _confirmRemove,
            );
            final coverage = _CoveragePanel(cards: data.wallet);
            return constraints.maxWidth >= 820
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: stack),
                      const SizedBox(width: 24),
                      Expanded(flex: 3, child: coverage),
                    ],
                  )
                : Column(
                    children: [stack, const SizedBox(height: 16), coverage],
                  );
          },
        ),
        SizedBox(height: product.sectionGap),
        OutlinedButton.icon(
          key: const ValueKey('add-card-button'),
          onPressed: () => setState(() => showPicker = !showPicker),
          icon: Icon(showPicker ? Icons.close : Icons.add),
          label: const Text('Add a card to wallet'),
        ),
        if (showPicker) ...[
          const SizedBox(height: 14),
          AppPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.tonalIcon(
                  key: const ValueKey('add-custom-card-button'),
                  onPressed: () async {
                    final draft = await showCustomCardSheet(context);
                    if (draft == null || !context.mounted) return;
                    final added = await ref
                        .read(appControllerProvider.notifier)
                        .addCustomCard(draft);
                    if (!context.mounted) return;
                    if (added) setState(() => showPicker = false);
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Add a card I already have'),
                ),
                const SizedBox(height: 16),
                const SectionLabel('Catalog'),
                const SizedBox(height: 8),
                if (available.isEmpty)
                  const Text(
                    'All listed catalog cards are already in this wallet.',
                  )
                else
                  for (final card in available)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      minVerticalPadding: 10,
                      leading: CreditCardArt(card: card, width: 72, height: 45),
                      title: Text(
                        card.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${card.issuer} | ${card.annualFee} | ${card.bestUse}',
                      ),
                      trailing: FilledButton(
                        onPressed: state.isLoading
                            ? null
                            : () async {
                                final added = await ref
                                    .read(appControllerProvider.notifier)
                                    .addCard(card.id);
                                if (!context.mounted) return;
                                if (added) {
                                  setState(() => showPicker = false);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ref.read(appControllerProvider).error ??
                                            'Could not add this card.',
                                      ),
                                    ),
                                  );
                                }
                              },
                        child: const Text('Add'),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmRemove(CreditCard card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove card?'),
        content: Text('Remove ${card.name} from this wallet?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final walletCardId = card.walletCardId ?? card.id;
    final removed = await ref
        .read(appControllerProvider.notifier)
        .removeCard(walletCardId);
    if (!mounted || removed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ref.read(appControllerProvider).error ??
              'Could not remove this card.',
        ),
      ),
    );
  }

  void _askRevo(String prompt) {
    context.go('/revo');
    ref.read(appControllerProvider.notifier).sendMessage(prompt);
  }
}

class _CoveragePanel extends StatelessWidget {
  const _CoveragePanel({required this.cards});
  final List<CreditCard> cards;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    final capabilities = walletCapabilities(cards);
    final food = capabilities.dining > capabilities.groceries
        ? capabilities.dining
        : capabilities.groceries;
    final travel = [
      capabilities.travel,
      capabilities.flights,
      capabilities.hotels,
    ].reduce((best, rate) => rate > best ? rate : best);
    final rates = [food, travel, capabilities.catchAll];
    final covered = rates.where((rate) => rate > 1).length;
    final coverage = ((covered / rates.length) * 100).round();
    final feeReview = cards
        .where((card) => card.annualFee != r'$0')
        .map((card) => card.name)
        .firstOrNull;
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Wallet coverage'),
          const SizedBox(height: 12),
          Text('$coverage%', style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 5),
          Text(
            'of common spend categories have a rewards multiplier above 1x',
            style: TextStyle(color: product.muted),
          ),
          const SizedBox(height: 18),
          _CoverageRow(
            label: 'Dining and groceries',
            value: _rateLabel(food),
            color: food > 1 ? product.success : product.muted,
          ),
          _CoverageRow(
            label: 'Travel',
            value: _rateLabel(travel),
            color: travel > 1 ? product.action : product.muted,
          ),
          _CoverageRow(
            label: 'Everything else',
            value: _rateLabel(capabilities.catchAll),
            color: capabilities.catchAll > 1
                ? product.secondary
                : product.muted,
          ),
          Divider(height: product.compact ? 20 : 28),
          Row(
            children: [
              Icon(Icons.info_outline, size: 17, color: product.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  feeReview == null
                      ? 'No annual-fee cards to review'
                      : 'Next fee review: $feeReview',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _rateLabel(double rate) => '${rate < 1 ? 1 : rate}x';
}

class _CoverageRow extends StatelessWidget {
  const _CoverageRow({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 9),
        Expanded(child: Text(label)),
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}
