import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';
import 'content_layout.dart';

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
    final color = _cardColor(card.id);
    final treatment = context.product.panelTreatment;
    final foreground =
        ThemeData.estimateBrightnessForColor(color) == Brightness.light
        ? const Color(0xFF101522)
        : Colors.white;
    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(height < 70 ? 10 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, Color.lerp(color, const Color(0xFF080B14), .34)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: .2)),
        borderRadius: BorderRadius.circular(switch (treatment) {
          PanelTreatment.flat => 22,
          PanelTreatment.paper => 5,
          PanelTreatment.technical => 2,
          PanelTreatment.wallet => 14,
          PanelTreatment.outlined => 18,
        }),
        boxShadow: preferred && treatment != PanelTreatment.technical
            ? [
                BoxShadow(
                  color: const Color(0xFF05070C).withValues(
                    alpha: treatment == PanelTreatment.flat ? .34 : .14,
                  ),
                  blurRadius: treatment == PanelTreatment.paper ? 18 : 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.2,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                width: height < 70 ? 20 : 28,
                height: height < 70 ? 14 : 20,
                decoration: BoxDecoration(
                  color: foreground.withValues(alpha: .2),
                  border: Border.all(color: foreground.withValues(alpha: .35)),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Text(
                card.brand,
                style: TextStyle(
                  color: foreground.withValues(alpha: .78),
                  fontSize: height < 70 ? 8 : 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            if (preferred && height >= 90)
              Positioned(
                top: 0,
                left: 40,
                child: Row(
                  children: [
                    Icon(Icons.star, size: 10, color: foreground),
                    const SizedBox(width: 4),
                    Text(
                      'PREFERRED',
                      style: TextStyle(
                        color: foreground,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .8,
                      ),
                    ),
                  ],
                ),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                      fontSize: height < 70 ? 10 : 16,
                    ),
                  ),
                  if (height >= 90)
                    Text(
                      '••••  ${card.id.hashCode.abs().toString().padLeft(4, '0').substring(0, 4)}',
                      style: TextStyle(
                        color: foreground.withValues(alpha: .68),
                        fontSize: 10,
                        letterSpacing: 1.1,
                      ),
                    ),
                ],
              ),
            ),
          ],
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
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          StatusPill(label: selected.multiplier),
                          StatusPill(
                            label: 'FEE ${selected.annualFee}',
                            color: product.warning,
                          ),
                        ],
                      ),
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

Color _cardColor(String id) {
  if (id.contains('amex')) return const Color(0xFFC89A3D);
  if (id.contains('venture')) return const Color(0xFF1B2E57);
  if (id.contains('sapphire')) return const Color(0xFF1E4E9D);
  if (id.contains('freedom-flex')) return const Color(0xFF6A3DB6);
  if (id.contains('freedom')) return const Color(0xFF2E59CA);
  if (id.contains('savor')) return const Color(0xFFA33845);
  if (id.contains('bilt')) return const Color(0xFF302E53);
  if (id.contains('citi')) return const Color(0xFF245FAE);
  if (id.contains('discover')) return const Color(0xFFE37D2F);
  return const Color(0xFF27445E);
}
