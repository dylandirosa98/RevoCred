import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/app_models.dart';
import '../../core/logic/card_art.dart';
import '../../core/theme/app_theme.dart';
import 'content_layout.dart';
import 'community_card_details.dart';

class CreditCardArt extends StatelessWidget {
  const CreditCardArt({
    required this.card,
    super.key,
    this.width = 150,
    this.height = 94,
    this.preferred = false,
  });

  final CreditCard card;
  final double width;
  final double height;
  final bool preferred;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: '${card.name}, stylized card illustration',
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(width * .04),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: preferred ? .24 : .12),
              blurRadius: preferred ? 12 : 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Image.asset(
          cardArtAsset(card),
          width: width,
          height: height,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}

class WalletCardStack extends StatefulWidget {
  const WalletCardStack({
    required this.cards,
    super.key,
    this.onAskRevo,
    this.onRemove,
    this.showDetails = true,
  });

  final List<CreditCard> cards;
  final ValueChanged<String>? onAskRevo;
  final ValueChanged<CreditCard>? onRemove;
  final bool showDetails;

  @override
  State<WalletCardStack> createState() => _WalletCardStackState();
}

class _WalletCardStackState extends State<WalletCardStack> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) return const Text('No cards in this wallet yet.');
    if (selectedIndex >= widget.cards.length) selectedIndex = 0;
    final selected = widget.cards[selectedIndex];
    final ordered = [
      selected,
      ...widget.cards.where((card) => card.id != selected.id),
    ];
    final product = context.product;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = math.min(constraints.maxWidth, 480.0);
        final cardHeight = cardWidth / 1.62;
        final stackOffset = constraints.maxWidth < 600
            ? math.max(product.cardStackOffset, 48.0)
            : product.cardStackOffset;
        final horizontalStep = switch (product.panelTreatment) {
          PanelTreatment.paper => 8.0,
          PanelTreatment.outlined => 3.0,
          PanelTreatment.flat => 1.5,
          PanelTreatment.technical => 0.0,
          PanelTreatment.wallet => 2.0,
        };
        final widthStep = switch (product.panelTreatment) {
          PanelTreatment.paper => 10.0,
          PanelTreatment.outlined => 6.0,
          PanelTreatment.flat => 3.0,
          PanelTreatment.technical => 0.0,
          PanelTreatment.wallet => 4.0,
        };
        final stackHeight = cardHeight + stackOffset * (ordered.length - 1);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: cardWidth,
                height: stackHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var index = ordered.length - 1; index >= 0; index--)
                      AnimatedPositioned(
                        key: ValueKey('wallet-position-${ordered[index].id}'),
                        duration: Duration(
                          milliseconds: product.compact ? 170 : 220,
                        ),
                        curve: Curves.easeOutCubic,
                        top: stackOffset * index,
                        left: index * horizontalStep,
                        child: Semantics(
                          button: true,
                          selected: index == 0,
                          label:
                              '${ordered[index].name}. ${index == 0 ? 'Preferred card, selected' : 'Tap to select'}',
                          child: GestureDetector(
                            key: ValueKey('wallet-card-${ordered[index].id}'),
                            onTap: () => setState(
                              () => selectedIndex = widget.cards.indexWhere(
                                (card) => card.id == ordered[index].id,
                              ),
                            ),
                            child: CreditCardArt(
                              card: ordered[index],
                              width: cardWidth - index * widthStep,
                              height: cardHeight,
                              preferred: index == 0,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (widget.showDetails) ...[
              SizedBox(height: product.compact ? 14 : 20),
              AnimatedSwitcher(
                duration: Duration(milliseconds: product.compact ? 150 : 200),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: AppPanel(
                  key: ValueKey('wallet-details-${selected.id}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              selected.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          StatusPill(
                            label: 'PREFERRED',
                            icon: Icons.check_circle_outline,
                            color: product.success,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        selected.bestUse,
                        style: TextStyle(color: product.muted),
                      ),
                      const SizedBox(height: 18),
                      const SectionLabel('Reward multipliers'),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            (selected.pointMultipliers.isEmpty
                                    ? [selected.multiplier]
                                    : selected.pointMultipliers)
                                .map((rate) => StatusPill(label: rate))
                                .toList(),
                      ),
                      const SizedBox(height: 18),
                      _WalletDetailRow(
                        icon: Icons.payments_outlined,
                        label: 'Annual fee',
                        value: selected.annualFee,
                        valueColor: selected.annualFee == r'$0'
                            ? product.success
                            : product.warning,
                      ),
                      const SizedBox(height: 16),
                      const SectionLabel('Credits & benefits'),
                      const SizedBox(height: 9),
                      if (selected.benefits.isEmpty)
                        Text(
                          'No benefit details are available for this card yet.',
                          style: TextStyle(color: product.muted),
                        )
                      else
                        for (final benefit in selected.benefits)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 17,
                                  color: product.success,
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(benefit)),
                              ],
                            ),
                          ),
                      if (selected.communityData != null)
                        CommunityCardDetails(data: selected.communityData!),
                      if (widget.onAskRevo != null) ...[
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: () => widget.onAskRevo!(
                            'How should I maximize ${selected.name}?',
                          ),
                          icon: const Icon(Icons.auto_awesome, size: 17),
                          label: const Text('Ask REVO about this card'),
                        ),
                      ],
                      if (widget.onRemove != null) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          key: ValueKey('remove-card-${selected.id}'),
                          onPressed: () => widget.onRemove!(selected),
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            size: 17,
                          ),
                          label: const Text('Remove from wallet'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _WalletDetailRow extends StatelessWidget {
  const _WalletDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: context.product.muted),
      const SizedBox(width: 8),
      Expanded(child: Text(label)),
      Text(
        value,
        style: TextStyle(fontWeight: FontWeight.w800, color: valueColor),
      ),
    ],
  );
}
