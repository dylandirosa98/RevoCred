import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../explore/presentation/explore_rewards_entry.dart';
import '../../../core/logic/wallet_score.dart';
import '../../../core/logic/card_art.dart';
import '../../../core/logic/ongoing_value.dart';
import 'ongoing_value_breakdown.dart';
import '../../../core/logic/strategy_digest.dart';
import '../../../core/models/app_models.dart';
import '../../../core/models/affiliate_offer.dart';
import '../../../shared/widgets/apply_offer_button.dart';

import '../../../core/state/app_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/category_icon.dart';
import '../../../shared/widgets/content_layout.dart';
import '../../../shared/widgets/send_revo_message.dart';
import 'purchase_recommendations_sheet.dart';

OngoingValue _ongoingValue(AppData data) =>
    data.ongoingValue ??
    estimateOngoingValue(
      data.wallet,
      data.monthlySpend,
      data.questionnaireAnswers?.travelScope ?? '',
    );

// Shared illustrations already include their card-face lettering. Keep the
// complete face visible and put Home's live labels below it.
const _walletArtAspectRatio = 2400 / 1512;

class _HomeValueBreakdown extends ConsumerWidget {
  const _HomeValueBreakdown();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appControllerProvider).data;
    return data == null
        ? const SizedBox.shrink()
        : OngoingValueBreakdown(value: _ongoingValue(data));
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appControllerProvider);
    final data = appState.data!;
    final config = ref.watch(appConfigProvider);
    final capabilities = walletCapabilities(data.wallet);
    final localWalletScore = scoreWallet(capabilities);
    final localEstimatedValue = (_ongoingValue(data).totalCents / 100).round();
    final score = displayWalletScore(
      useLocal:
          config.useMocks ||
          (!appState.isAuthenticated && !data.isPersonalPreview),
      storedScore: data.pointsValue,
      localScore: localWalletScore,
    );
    final estimatedValue =
        config.useMocks ||
            (!appState.isAuthenticated && !data.isPersonalPreview)
        ? localEstimatedValue
        : data.projectedYearlyValue;
    final nextTarget = strategyNextCardName(data) ?? 'your current wallet';
    // Both shipped themes use the Decision Flow layout.
    return _DecisionFlowHome(
      name: data.profile.firstName,
      initials: data.profile.initials,
      cards: data.wallet,
      purchaseGuide: data.purchaseGuide,
      onLoadGuide: (mode, caps) => ref
          .read(appRepositoryProvider)
          .loadPurchaseGuide(travelMode: mode, capsAvailable: caps),
      estimatedValue: estimatedValue,
      projectedValue: estimatedValue,
      score: score,
      nextTarget: nextTarget,
      onAskRevo: (prompt) =>
          sendRevoMessage(context, ref, prompt, openChat: true),
    );
  }
}

class _DecisionFlowHome extends StatefulWidget {
  const _DecisionFlowHome({
    required this.cards,
    required this.purchaseGuide,
    required this.onLoadGuide,
    this.name = '',
    this.initials = '',
    required this.estimatedValue,
    required this.projectedValue,
    required this.score,
    required this.nextTarget,
    required this.onAskRevo,
  });

  final String name;
  final String initials;
  final List<CreditCard> cards;
  final PurchaseGuide? purchaseGuide;
  final Future<PurchaseGuide> Function(String, bool) onLoadGuide;
  final int estimatedValue;
  final int projectedValue;
  final int score;
  final String nextTarget;
  final ValueChanged<String> onAskRevo;

  @override
  State<_DecisionFlowHome> createState() => _DecisionFlowHomeState();
}

class _DecisionFlowHomeState extends State<_DecisionFlowHome> {
  String category = 'Dining';
  final Map<String, PurchaseGuide> _categoryOverrides = {};
  PurchaseGuide? get _guide =>
      _categoryOverrides[_categorySlug(category)] ?? widget.purchaseGuide;
  PurchaseCategory? get _categoryGuide => _guide
      ?.category(_categorySlug(category))
      ?.forWallet(widget.cards.map((c) => c.id).toSet());
  PurchaseOption? get _pick => _categoryGuide?.displayOptions.firstOrNull;

  @override
  void didUpdateWidget(covariant _DecisionFlowHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.purchaseGuide != widget.purchaseGuide ||
        oldWidget.cards.map((c) => c.id).join('|') !=
            widget.cards.map((c) => c.id).join('|')) {
      _categoryOverrides.clear();
    }
  }

  static const primaryCategories = [
    ('Dining', '🍽️'),
    ('Groceries', '🛒'),
    ('Travel', '✈️'),
    ('Gas', '⛽'),
    ('Transit', '🚇'),
    ('Online shopping', '🛍️'),
  ];

  static const moreCategories = [
    ('Rent', '🏠'),
    ('Streaming', '📺'),
    ('Entertainment', '🎟️'),
    ('Drugstores', '💊'),
    ('Wholesale clubs', '🛒'),
    ('Utilities', '💡'),
    ('Phone & internet', '📱'),
    ('Home improvement', '🛠️'),
    ('Office supplies', '🗂️'),
    ('General purchases', '💳'),
  ];

  CreditCard? get recommendedCard {
    final id = _pick?.cardId;
    return widget.cards.where((c) => c.id == id).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    final card = recommendedCard;
    final fallback = _categoryGuide?.isFallback ?? false;
    final safeTop = MediaQuery.paddingOf(context).top;
    return SingleChildScrollView(
      key: const ValueKey('decision-flow-home'),
      padding: EdgeInsets.fromLTRB(18, 14 + safeTop, 18, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _WalletGreeting(
                name: widget.name,
                initials: widget.initials,
                onProfile: () => context.go('/profile'),
                onSearch: () => context.go('/cards?search=1'),
                onAlerts: () => _showAlerts(context),
              ),
              const SizedBox(height: 27),
              Text(
                'Make the next swipe count.',
                style: TextStyle(
                  color: product.ink,
                  fontSize: 29,
                  height: 1.05,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.1,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Tell RevoCred what you are buying.',
                style: TextStyle(color: product.muted, fontSize: 13),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  const gap = 8.0;
                  final columns = constraints.maxWidth >= 660 ? 6 : 3;
                  final width =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  final moreSelected = !primaryCategories.any(
                    (item) => item.$1 == category,
                  );
                  return Column(
                    children: [
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final item in primaryCategories)
                            SizedBox(
                              width: width,
                              child: _DecisionCategory(
                                key: ValueKey(
                                  'decision-category-${_categorySlug(item.$1)}',
                                ),
                                label: item.$1,
                                emoji: item.$2,
                                selected: category == item.$1,
                                onTap: () => _selectCategory(item.$1),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          key: const ValueKey('decision-more-categories'),
                          onPressed: _showMoreCategories,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: moreSelected
                                ? product.subtle
                                : product.surface,
                            foregroundColor: moreSelected
                                ? product.action
                                : product.ink,
                            minimumSize: const Size.fromHeight(50),
                            side: BorderSide(
                              color: moreSelected
                                  ? product.action
                                  : product.border,
                            ),
                          ),
                          icon: const Icon(Icons.grid_view_rounded, size: 17),
                          label: Text(
                            moreSelected
                                ? 'More: $category'
                                : 'More categories',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 25),
              Row(
                children: [
                  const Expanded(child: _WalletSectionHeader(label: 'Use now')),
                  Flexible(
                    child: Text(
                      fallback
                          ? _categoryGuide?.tied == true
                                ? 'Tied base-rate options for $category'
                                : 'Base-rate option for $category'
                          : _categoryGuide?.tied == true
                          ? 'Tied best for $category'
                          : 'Best known for $category',
                      key: const ValueKey('decision-category-result'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: product.action,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              if (card == null)
                AppPanel(
                  child: Text(
                    widget.cards.isEmpty
                        ? 'Add a card to get a recommendation.'
                        : 'No supported earning rule is available for this purchase. Use Compare & options to review details.',
                  ),
                )
              else ...[
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  child: _DecisionCard(
                    key: ValueKey('decision-card-${card.id}'),
                    card: card,
                  ),
                ),
                const SizedBox(height: 12),
                _DecisionReason(
                  card: card,
                  category: category,
                  option: _pick!,
                  isFallback: fallback,
                  onWhy: () => _showWhy(context, card),
                  onAsk: () => widget.onAskRevo(
                    'Why should I use ${card.name} for $category?',
                  ),
                ),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('decision-comparison-options'),
                  onPressed: _showComparison,
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('Compare & options'),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _DecisionMetric(
                      label: 'Estimated ongoing yearly value',
                      value: _signedDollars(widget.estimatedValue),
                      detail:
                          '${_signedDollars(widget.projectedValue)} cash equivalent',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DecisionMetric(
                      label: 'Wallet score',
                      value: '${widget.score}',
                      detail: 'out of 100',
                    ),
                  ),
                ],
              ),
              const _HomeValueBreakdown(),
              const SizedBox(height: 14),
              const ExploreRewardsEntry(),
              const SizedBox(height: 27),
              _WalletSectionHeader(
                label: 'Your wallet',
                action: 'Manage  +',
                onAction: () => context.go('/cards'),
              ),
              const SizedBox(height: 11),
              SizedBox(
                height: _StudioCard.heightFor(context),
                child: ListView.separated(
                  key: const ValueKey('decision-wallet-cards'),
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.cards.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 11),
                  itemBuilder: (context, index) => _StudioCard(
                    card: widget.cards[index],
                    preferred: widget.cards[index].id == card?.id,
                    onTap: () => context.go('/cards'),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              Text(
                'Educational information, not financial advice. Verify current issuer terms before applying.',
                style: TextStyle(color: product.muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              _DecisionNextMove(
                target: widget.nextTarget,
                onTap: () => context.go('/strategy'),
              ),
              const ApplyOfferButton(placement: ApplyPlacement.recommendation),
              const SizedBox(height: 14),
              _DecisionUpcoming(onOpenCards: () => context.go('/cards')),
            ],
          ),
        ),
      ),
    );
  }

  void _showWhy(BuildContext context, CreditCard card) {
    final pick = _pick;
    if (pick == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Why ${card.name}?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(
                '${pick.earnLabel}${_categoryGuide?.isFallback == true ? ' before fees' : ''} — ${pick.reason}',
              ),
              for (final condition in pick.conditions)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(condition),
                ),
              const SizedBox(height: 12),
              Text(_categoryGuide?.assumptions ?? ''),
              const SizedBox(height: 8),
              Text(
                '${pick.source}${pick.lastVerified.isEmpty ? '' : ' · source verified ${pick.lastVerified}'}',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAlerts(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Two demo wallet reminders are listed below.'),
      ),
    );
  }

  Future<void> _showMoreCategories() async {
    final selection = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.product.canvas,
      showDragHandle: true,
      builder: (context) =>
          _MoreCategorySheet(categories: moreCategories, selected: category),
    );
    if (selection != null && mounted) {
      _selectCategory(selection);
    }
  }

  void _selectCategory(String selection) {
    setState(() => category = selection);
  }

  Future<void> _showComparison() async {
    final selection = category;
    final walletKey = widget.cards.map((c) => c.id).join('|');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.product.canvas,
      showDragHandle: true,
      builder: (context) => PurchaseRecommendationsSheet(
        categoryId: _categorySlug(selection),
        categoryLabel: selection,
        wallet: widget.cards,
        initialGuide: _guide,
        load: (mode, caps) async {
          final guide = await widget.onLoadGuide(mode, caps);
          if (mounted && walletKey == widget.cards.map((c) => c.id).join('|')) {
            setState(
              () => _categoryOverrides[_categorySlug(selection)] = guide,
            );
          }
          return guide;
        },
      ),
    );
  }

  static String _categorySlug(String value) => value
      .toLowerCase()
      .replaceAll('&', 'and')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}

class _DecisionCategory extends StatelessWidget {
  const _DecisionCategory({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  static double heightFor(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return 80 + (scale - 1).clamp(0, 1) * 42;
  }

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? product.action : product.surface,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: SizedBox(
            height: heightFor(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CategoryIcon(category: label),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? product.actionInk : product.ink,
                      fontSize: 10.5,
                      height: 1.05,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreCategorySheet extends StatelessWidget {
  const _MoreCategorySheet({required this.categories, required this.selected});

  final List<(String, String)> categories;
  final String selected;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    return FractionallySizedBox(
      heightFactor: .78,
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'More categories',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Choose the purchase type and RevoCred will compare it with your wallet.',
                    style: TextStyle(color: product.muted, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 520 ? 3 : 2;
                        return GridView.builder(
                          key: const ValueKey('decision-more-category-grid'),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 9,
                                mainAxisSpacing: 9,
                                mainAxisExtent: _DecisionCategory.heightFor(
                                  context,
                                ),
                              ),
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final item = categories[index];
                            return _DecisionCategory(
                              key: ValueKey(
                                'decision-more-category-${_DecisionFlowHomeState._categorySlug(item.$1)}',
                              ),
                              label: item.$1,
                              emoji: item.$2,
                              selected: selected == item.$1,
                              onTap: () => Navigator.pop(context, item.$1),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DecisionCard extends StatelessWidget {
  const _DecisionCard({required this.card, super.key});

  final CreditCard card;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math.min(constraints.maxWidth, 420.0);
      final height = width / _walletArtAspectRatio;
      return Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          key: const ValueKey('decision-recommended-card'),
          width: width,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2D2440).withValues(alpha: .22),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Image.asset(
              cardArtAsset(card),
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              semanticLabel: '${card.name}, stylized card illustration',
            ),
          ),
        ),
      );
    },
  );
}

class _DecisionReason extends StatelessWidget {
  const _DecisionReason({
    required this.card,
    required this.category,
    required this.option,
    this.isFallback = false,
    required this.onWhy,
    required this.onAsk,
  });

  final CreditCard card;
  final String category;
  final PurchaseOption option;
  final bool isFallback;
  final VoidCallback onWhy;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    return Container(
      key: const ValueKey('decision-purchase-summary'),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: product.surface,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${option.earnLabel}${isFallback ? ' before fees' : ''} · $category',
            key: const ValueKey('decision-purchase-earn-label'),
            style: TextStyle(
              color: product.action,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            isFallback || option.conditions.isEmpty
                ? option.reason
                : '${option.reason}. ${option.conditions.first}',
            maxLines: isFallback ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: onWhy,
                child: const Text('Why this card?'),
              ),
              FilledButton.icon(
                onPressed: onAsk,
                icon: const Icon(Icons.auto_awesome, size: 15),
                label: const Text('Ask REVO'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DecisionMetric extends StatelessWidget {
  const _DecisionMetric({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: context.product.surface,
      borderRadius: BorderRadius.circular(17),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 2,
          style: TextStyle(color: context.product.muted, fontSize: 10),
        ),
        const SizedBox(height: 7),
        Text(
          value,
          style: const TextStyle(
            fontSize: 23,
            height: 1,
            fontWeight: FontWeight.w700,
            letterSpacing: -.7,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          detail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: context.product.muted, fontSize: 8),
        ),
      ],
    ),
  );
}

class _DecisionNextMove extends StatelessWidget {
  const _DecisionNextMove({required this.target, required this.onTap});

  final String target;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF17151C),
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          children: [
            Container(
              width: 39,
              height: 39,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.north_east,
                color: Colors.white,
                size: 19,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NEXT BEST MOVE',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .5),
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Review $target',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
          ],
        ),
      ),
    ),
  );
}

class _DecisionUpcoming extends ConsumerWidget {
  const _DecisionUpcoming({required this.onOpenCards});

  final VoidCallback onOpenCards;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      !ref.watch(appConfigProvider).useMocks
      ? const SizedBox.shrink()
      : Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.product.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _WalletSectionHeader(label: 'Demo reminders'),
              const SizedBox(height: 12),
              _AttentionRow(
                icon: Icons.restaurant_outlined,
                title: 'Dining credit reminder',
                detail: 'Review eligible purchases before month end',
                color: context.product.warning,
                onTap: onOpenCards,
              ),
              Divider(height: 24, color: context.product.border),
              _AttentionRow(
                icon: Icons.event_repeat_outlined,
                title: 'Annual fee review',
                detail: 'Venture X is your next wallet checkpoint',
                color: context.product.action,
                onTap: onOpenCards,
              ),
            ],
          ),
        );
}

class _StudioCard extends StatelessWidget {
  const _StudioCard({
    required this.card,
    required this.preferred,
    required this.onTap,
  });

  static const width = 184.0;

  static double heightFor(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final lineHeight = DefaultTextStyle.of(context).style.height ?? 1.45;
    // Inset artwork, padding/gaps, and up to two lines of card-name text.
    return ((width - 22) / _walletArtAspectRatio +
                38 +
                lineHeight *
                    (scaler.scale(8) + 2 * scaler.scale(13) + scaler.scale(9)))
            .ceilToDouble() +
        2; // Border plus whole-pixel text line rounding.
  }

  final CreditCard card;
  final bool preferred;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    return Semantics(
      button: true,
      label: 'Open ${card.name}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: SizedBox(
          key: ValueKey('wallet-studio-card-${card.id}'),
          width: width,
          child: Container(
            decoration: BoxDecoration(
              color: product.surface,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: product.border),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF241C36).withValues(alpha: .12),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                  child: AspectRatio(
                    aspectRatio: _walletArtAspectRatio,
                    child: Image.asset(
                      cardArtAsset(card),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            _issuerMonogram(card.issuer),
                            style: TextStyle(
                              color: product.muted,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          if (preferred)
                            Text(
                              'PREFERRED',
                              style: TextStyle(
                                color: product.action,
                                fontSize: 7,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .6,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        card.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: product.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              card.multiplier,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: product.muted,
                                fontSize: 9,
                              ),
                            ),
                          ),
                          Text(
                            'FEE ${card.annualFee}',
                            style: TextStyle(
                              color: product.muted,
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _issuerMonogram(String issuer) {
    final words = issuer
        .trim()
        .split(RegExp(r'\\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'RC';
    if (words.length == 1) {
      return words.first
          .substring(0, math.min(2, words.first.length))
          .toUpperCase();
    }
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }
}

String _signedDollars(int value) =>
    value < 0 ? '−\$${_spacedAmount(-value)}' : '\$${_spacedAmount(value)}';

String _spacedAmount(int value) {
  final digits = value.toString();
  final output = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) output.write(' ');
    output.write(digits[index]);
  }
  return output.toString();
}

class _WalletGreeting extends StatelessWidget {
  const _WalletGreeting({
    required this.onProfile,
    required this.onSearch,
    required this.onAlerts,
    this.name = '',
    this.initials = '',
  });

  final String name;
  final String initials;
  final VoidCallback onProfile;
  final VoidCallback onSearch;
  final VoidCallback onAlerts;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Semantics(
        button: true,
        label: 'Open profile',
        child: InkWell(
          onTap: onProfile,
          borderRadius: BorderRadius.circular(999),
          // 44pt tap area (Apple's minimum) around a smaller avatar.
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFF7051E5),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initials.isEmpty ? 'R' : initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          // Greet whoever is actually signed in rather than a fixed name.
          name.isEmpty ? 'Hello' : 'Hello, $name',
          style: TextStyle(
            color: context.product.ink,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      IconButton(
        tooltip: 'Search cards',
        onPressed: onSearch,
        icon: const Icon(Icons.search, size: 22),
      ),
      Consumer(
        builder: (context, ref, _) => ref.watch(appConfigProvider).useMocks
            ? IconButton(
                tooltip: 'Demo reminders',
                onPressed: onAlerts,
                icon: const Icon(Icons.notifications_none, size: 22),
              )
            : const SizedBox.shrink(),
      ),
    ],
  );
}

class _WalletSectionHeader extends StatelessWidget {
  const _WalletSectionHeader({this.label = '', this.action, this.onAction});

  final String label;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: context.product.muted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: .3,
          ),
        ),
      ),
      if (action != null)
        InkWell(
          onTap: onAction,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              action!,
              style: TextStyle(
                color: context.product.action,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
    ],
  );
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String detail;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(detail, style: TextStyle(color: context.product.muted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );
}
