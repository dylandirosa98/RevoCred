import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logic/wallet_score.dart';
import '../../../core/logic/yearly_value.dart';
import '../../../core/models/app_models.dart';
import '../../../core/models/affiliate_offer.dart';
import '../../../shared/widgets/apply_offer_button.dart';
import '../../../core/state/app_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_logo.dart';
import '../../../shared/widgets/content_layout.dart';
import '../../../shared/widgets/credit_card_view.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appControllerProvider);
    final data = appState.data!;
    final product = context.product;
    final config = ref.watch(appConfigProvider);
    final capabilities = walletCapabilities(data.wallet);
    final localWalletScore = scoreWallet(capabilities);
    final localEstimatedValue = yearlyValue(
      MonthlySpending.fromQuestionnaire(data.monthlySpend),
      bestRates(capabilities),
    );
    final score = displayWalletScore(
      useLocal: config.useMocks || !appState.isAuthenticated,
      storedScore: data.pointsValue,
      localScore: localWalletScore,
    );
    final estimatedValue = config.useMocks || !appState.isAuthenticated
        ? localEstimatedValue
        : data.projectedYearlyValue;
    if (product.heroTreatment == HeroTreatment.wallet) {
      return _WalletFlowHome(
        cards: data.wallet,
        estimatedValue: estimatedValue,
        projectedValue: estimatedValue,
        nextTarget: data.profile.nextTarget,
      );
    }
    if (product.heroTreatment == HeroTreatment.walletStudio) {
      return _WalletStudioHome(
        cards: data.wallet,
        estimatedValue: estimatedValue,
        projectedValue: estimatedValue,
        score: score,
        nextTarget: data.profile.nextTarget,
      );
    }
    if (product.heroTreatment == HeroTreatment.decision) {
      return _DecisionFlowHome(
        cards: data.wallet,
        estimatedValue: estimatedValue,
        projectedValue: estimatedValue,
        score: score,
        nextTarget: data.profile.nextTarget,
        onAskRevo: (prompt) {
          context.go('/revo');
          ref.read(appControllerProvider.notifier).sendMessage(prompt);
        },
      );
    }
    return ContentLayout(
      children: [
        const Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [AppLogo(), _DemoBadge()],
        ),
        SizedBox(height: product.sectionGap),
        Text(
          'Your strategy is ready.',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 8),
        Text(
          'A clear next move for every dollar in your wallet.',
          style: TextStyle(color: product.muted, fontSize: 16),
        ),
        SizedBox(height: product.sectionGap),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final hero = _ValueHero(
              estimatedValue: estimatedValue,
              projectedValue: estimatedValue,
              score: score,
              activeCards: data.wallet.length,
            );
            final action = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NextAction(cardName: data.profile.nextTarget),
                const ApplyOfferButton(
                  placement: ApplyPlacement.recommendation,
                ),
              ],
            );
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: hero),
                      const SizedBox(width: 16),
                      Expanded(flex: 3, child: action),
                    ],
                  )
                : Column(children: [hero, const SizedBox(height: 14), action]);
          },
        ),
        SizedBox(height: product.sectionGap),
        Row(
          children: [
            const Expanded(child: SectionLabel('Card to use now')),
            TextButton(
              onPressed: () => context.go('/cards'),
              child: const Text('Open wallet'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        WalletCardStack(
          cards: data.wallet,
          onAskRevo: (prompt) {
            context.go('/revo');
            ref.read(appControllerProvider.notifier).sendMessage(prompt);
          },
        ),
        SizedBox(height: product.sectionGap),
        const SectionLabel('Attention queue'),
        const SizedBox(height: 10),
        AppPanel(
          child: Column(
            children: [
              _AttentionRow(
                icon: Icons.calendar_today_outlined,
                title: 'Use monthly dining credit',
                detail: 'Review eligible purchases before month end',
                color: product.warning,
                onTap: () => context.go('/cards'),
              ),
              Divider(height: product.compact ? 20 : 28),
              _AttentionRow(
                icon: Icons.payments_outlined,
                title: 'Annual fee review',
                detail: 'Venture X renewal is the next wallet checkpoint',
                color: product.action,
                onTap: () => context.go('/cards'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DecisionFlowHome extends StatefulWidget {
  const _DecisionFlowHome({
    required this.cards,
    required this.estimatedValue,
    required this.projectedValue,
    required this.score,
    required this.nextTarget,
    required this.onAskRevo,
  });

  final List<CreditCard> cards;
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
    if (widget.cards.isEmpty) return null;
    final terms = switch (category) {
      'Dining' => const ['dining', 'restaurant'],
      'Groceries' => const ['grocery', 'groceries', 'supermarket'],
      'Travel' => const ['travel', 'flight', 'hotel'],
      'Gas' => const ['gas', 'fuel'],
      'Transit' => const ['transit', 'rideshare', 'train', 'commute'],
      'Online shopping' => const ['online', 'amazon', 'shopping'],
      'Rent' => const ['rent', 'housing'],
      'Streaming' => const ['streaming', 'subscription'],
      'Entertainment' => const ['entertainment', 'concert', 'movie'],
      'Drugstores' => const ['drugstore', 'pharmacy'],
      'Wholesale clubs' => const ['wholesale', 'club'],
      'Utilities' => const ['utilities', 'electric', 'utility'],
      'Phone & internet' => const ['phone', 'internet', 'wireless'],
      'Home improvement' => const ['home improvement', 'hardware'],
      'Office supplies' => const ['office', 'shipping'],
      _ => const ['everyday', 'everything', 'all purchases'],
    };
    final match = widget.cards.where((card) {
      final text = '${card.bestUse} ${card.multiplier}'.toLowerCase();
      return terms.any(text.contains);
    });
    if (match.isNotEmpty) return match.first;
    final fallback = switch (category) {
      'Travel' => 1,
      'Gas' => 2,
      'Transit' => 1,
      'Online shopping' => widget.cards.length - 1,
      'Rent' => widget.cards.length - 1,
      'Streaming' => 2,
      'Entertainment' => 2,
      'Drugstores' => 0,
      'Wholesale clubs' => 0,
      'Utilities' => widget.cards.length - 1,
      'Phone & internet' => widget.cards.length - 1,
      'Home improvement' => 2,
      'Office supplies' => 1,
      'General purchases' => widget.cards.length - 1,
      _ => 0,
    };
    return widget.cards[fallback.clamp(0, widget.cards.length - 1)];
  }

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    final card = recommendedCard;
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
                onProfile: () => context.go('/profile'),
                onSearch: () => context.go('/strategy'),
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
                                onTap: () => setState(() => category = item.$1),
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
                  Text(
                    'Best for $category',
                    key: const ValueKey('decision-category-result'),
                    style: TextStyle(
                      color: product.action,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              if (card == null)
                const AppPanel(
                  child: Text('Add a card to get a recommendation.'),
                )
              else ...[
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  child: _DecisionCard(
                    key: ValueKey('decision-card-${card.id}'),
                    card: card,
                    category: category,
                  ),
                ),
                const SizedBox(height: 12),
                _DecisionReason(
                  card: card,
                  category: category,
                  onWhy: () => _showWhy(context, card),
                  onAsk: () => widget.onAskRevo(
                    'Why should I use ${card.name} for $category?',
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _DecisionMetric(
                      label: 'Projected yearly value',
                      value:
                          '\$${_WalletFlowHome._spacedAmount(widget.estimatedValue)}',
                      detail: '\$${widget.projectedValue} cash equivalent',
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
              const SizedBox(height: 27),
              _WalletSectionHeader(
                label: 'Your wallet',
                action: 'Manage  +',
                onAction: () => context.go('/cards'),
              ),
              const SizedBox(height: 11),
              SizedBox(
                height: _StudioCard.height,
                child: ListView.separated(
                  key: const ValueKey('decision-wallet-cards'),
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.cards.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 11),
                  itemBuilder: (context, index) => _StudioCard(
                    card: widget.cards[index],
                    index: index,
                    preferred: widget.cards[index].id == card?.id,
                    onTap: () => context.go('/cards'),
                  ),
                ),
              ),
              const SizedBox(height: 25),
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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.product.surface,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Why ${card.name}?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(card.bestUse, style: const TextStyle(height: 1.5)),
              const SizedBox(height: 12),
              Text(
                '${card.multiplier}. Annual fee ${card.annualFee}. Confirm current issuer terms before relying on this demo recommendation.',
                style: TextStyle(color: context.product.muted, height: 1.5),
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
      setState(() => category = selection);
    }
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
    return 72 + (scale - 1).clamp(0, 1) * 42;
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
                  Text(
                    emoji,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 19, height: 1),
                  ),
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
                    'Choose the purchase type and RevoCred will compare it with your demo wallet.',
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
  const _DecisionCard({required this.card, required this.category, super.key});

  final CreditCard card;
  final String category;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math.min(constraints.maxWidth, 420.0);
      final height = width / 1.586;
      return Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          key: const ValueKey('decision-recommended-card'),
          width: width,
          height: height,
          child: Container(
            padding: EdgeInsets.all(width < 330 ? 18 : 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF17151C), Color(0xFF44365D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2D2440).withValues(alpha: .22),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -50,
                  top: -70,
                  child: Transform.rotate(
                    angle: -.28,
                    child: Container(
                      width: width * .62,
                      height: width * .42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .065),
                        borderRadius: BorderRadius.circular(48),
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .25),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _StudioCard._issuerMonogram(card.issuer),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFB9A5FF,
                            ).withValues(alpha: .2),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'RECOMMENDED',
                            style: TextStyle(
                              color: Color(0xFFD7CEFF),
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .7,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      card.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: width < 330 ? 22 : 28,
                        height: 1.05,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.8,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            card.multiplier,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .72),
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Text(
                          category.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .66),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .7,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
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
    required this.onWhy,
    required this.onAsk,
  });

  final CreditCard card;
  final String category;
  final VoidCallback onWhy;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: product.surface,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.bestUse,
            maxLines: 2,
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

class _DecisionUpcoming extends StatelessWidget {
  const _DecisionUpcoming({required this.onOpenCards});

  final VoidCallback onOpenCards;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.product.surface,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _WalletSectionHeader(label: 'Upcoming'),
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

class _WalletStudioHome extends StatelessWidget {
  const _WalletStudioHome({
    required this.cards,
    required this.estimatedValue,
    required this.projectedValue,
    required this.score,
    required this.nextTarget,
  });

  final List<CreditCard> cards;
  final int estimatedValue;
  final int projectedValue;
  final int score;
  final String nextTarget;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    final safeTop = MediaQuery.paddingOf(context).top;
    return SingleChildScrollView(
      key: const ValueKey('wallet-studio-home'),
      padding: EdgeInsets.fromLTRB(18, 14 + safeTop, 18, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(child: AppLogo(markSize: 35)),
                  _StudioHeaderAction(
                    tooltip: 'Search cards',
                    icon: Icons.search,
                    onTap: () => context.go('/strategy'),
                  ),
                  const SizedBox(width: 8),
                  _StudioHeaderAction(
                    tooltip: 'Open profile',
                    icon: Icons.person_outline,
                    showDot: true,
                    onTap: () => context.go('/profile'),
                  ),
                ],
              ),
              const SizedBox(height: 27),
              Text(
                'GOOD MORNING, ALEX',
                style: TextStyle(
                  color: product.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your wallet, optimized.',
                style: TextStyle(
                  color: product.ink,
                  fontSize: 29,
                  height: 1.05,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.1,
                ),
              ),
              const SizedBox(height: 22),
              _StudioValuePanel(
                estimatedValue: estimatedValue,
                projectedValue: projectedValue,
                cardCount: cards.length,
                score: score,
              ),
              const SizedBox(height: 27),
              _WalletSectionHeader(
                label: 'Your cards',
                action: 'Manage  +',
                onAction: () => context.go('/cards'),
              ),
              const SizedBox(height: 11),
              SizedBox(
                height: _StudioCard.height,
                child: ListView.separated(
                  key: const ValueKey('wallet-studio-cards'),
                  scrollDirection: Axis.horizontal,
                  itemCount: cards.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 11),
                  itemBuilder: (context, index) => _StudioCard(
                    card: cards[index],
                    index: index,
                    preferred: index == 0,
                    onTap: () => context.go('/cards'),
                  ),
                ),
              ),
              const SizedBox(height: 27),
              const _WalletSectionHeader(label: 'Strategy kit'),
              const SizedBox(height: 11),
              SizedBox(
                height: 88,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _StudioShortcut(
                      color: const Color(0xFF7657DD),
                      icon: Icons.credit_score_outlined,
                      label: 'Card fit',
                      onTap: () => context.go('/cards'),
                    ),
                    _StudioShortcut(
                      color: const Color(0xFFFF8C5A),
                      icon: Icons.route_outlined,
                      label: 'Roadmap',
                      onTap: () => context.go('/strategy'),
                    ),
                    _StudioShortcut(
                      color: const Color(0xFFE0446D),
                      icon: Icons.event_repeat_outlined,
                      label: 'Fee watch',
                      onTap: () => context.go('/cards'),
                    ),
                    _StudioShortcut(
                      color: const Color(0xFF3AAFC0),
                      icon: Icons.auto_awesome_outlined,
                      label: 'Ask REVO',
                      onTap: () => context.go('/revo'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _StudioHealthPanel(
                score: score,
                cardCount: cards.length,
                nextTarget: nextTarget,
                onRoadmap: () => context.go('/strategy'),
              ),
              const ApplyOfferButton(placement: ApplyPlacement.recommendation),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudioHeaderAction extends StatelessWidget {
  const _StudioHeaderAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Material(
        color: context.product.surface,
        borderRadius: BorderRadius.circular(13),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          icon: Icon(icon, size: 20),
          constraints: const BoxConstraints.tightFor(width: 42, height: 42),
          padding: EdgeInsets.zero,
        ),
      ),
      if (showDot)
        const Positioned(
          right: 6,
          top: 6,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFFE0446D),
              shape: BoxShape.circle,
            ),
            child: SizedBox(width: 6, height: 6),
          ),
        ),
    ],
  );
}

class _StudioValuePanel extends StatelessWidget {
  const _StudioValuePanel({
    required this.estimatedValue,
    required this.projectedValue,
    required this.cardCount,
    required this.score,
  });

  final int estimatedValue;
  final int projectedValue;
  final int cardCount;
  final int score;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF17141D), Color(0xFF39304A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF241C36).withValues(alpha: .18),
          blurRadius: 26,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'PROJECTED FIRST-YEAR VALUE',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .63),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'DEMO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '\$${_WalletFlowHome._spacedAmount(estimatedValue)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 43,
            height: 1,
            fontWeight: FontWeight.w600,
            letterSpacing: -1.8,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          '\$$projectedValue cash-equivalent value plus demo points estimate',
          style: TextStyle(
            color: Colors.white.withValues(alpha: .6),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _StudioMetric(label: 'WALLET SCORE', value: '$score / 100'),
            const SizedBox(width: 28),
            _StudioMetric(label: 'ACTIVE CARDS', value: '$cardCount'),
          ],
        ),
      ],
    ),
  );
}

class _StudioMetric extends StatelessWidget {
  const _StudioMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: .48),
          fontSize: 8,
          fontWeight: FontWeight.w600,
          letterSpacing: .8,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        style: const TextStyle(
          color: Color(0xFFCBBEFF),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _StudioCard extends StatelessWidget {
  const _StudioCard({
    required this.card,
    required this.index,
    required this.preferred,
    required this.onTap,
  });

  static const width = 184.0;
  static const height = width / 1.586;

  final CreditCard card;
  final int index;
  final bool preferred;
  final VoidCallback onTap;

  static const palettes = [
    [Color(0xFF17161B), Color(0xFF35313D)],
    [Color(0xFF7256D5), Color(0xFFA78CF1)],
    [Color(0xFF214E62), Color(0xFF3DA7A2)],
    [Color(0xFF813E53), Color(0xFFE06C76)],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = palettes[index % palettes.length];
    return Semantics(
      button: true,
      label: 'Open ${card.name}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: SizedBox(
          key: ValueKey('wallet-studio-card-${card.id}'),
          width: width,
          height: height,
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: colors.first.withValues(alpha: .2),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -35,
                  top: -48,
                  child: Transform.rotate(
                    angle: -.25,
                    child: Container(
                      width: 120,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .07),
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .15),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .25),
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _issuerMonogram(card.issuer),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (preferred)
                          Text(
                            'PREFERRED',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .72),
                              fontSize: 7,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .6,
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      card.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
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
                              color: Colors.white.withValues(alpha: .72),
                              fontSize: 8,
                            ),
                          ),
                        ),
                        Text(
                          'FEE ${card.annualFee}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .68),
                            fontSize: 7,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
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
        .split(RegExp(r'\s+'))
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

class _StudioShortcut extends StatelessWidget {
  const _StudioShortcut({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 10),
    child: Material(
      color: context.product.surface,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: SizedBox(
          width: 104,
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 31,
                  height: 31,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 17),
                ),
                const Spacer(),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
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

class _StudioHealthPanel extends StatelessWidget {
  const _StudioHealthPanel({
    required this.score,
    required this.cardCount,
    required this.nextTarget,
    required this.onRoadmap,
  });

  final int score;
  final int cardCount;
  final String nextTarget;
  final VoidCallback onRoadmap;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: product.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: product.ink.withValues(alpha: .04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Wallet health',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                'DEMO MODEL',
                style: TextStyle(
                  color: product.muted,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              SizedBox(
                width: 70,
                height: 70,
                child: CustomPaint(
                  painter: _ScoreRingPainter(
                    progress: score / 100,
                    color: product.action,
                    track: product.subtle,
                  ),
                  child: Center(
                    child: Text(
                      '$score',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$cardCount cards are covering your highest-value categories.',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your next modeled target is $nextTarget.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: product.muted,
                        fontSize: 10,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: product.border),
          InkWell(
            onTap: onRoadmap,
            child: Padding(
              padding: const EdgeInsets.only(top: 13),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Open your strategy roadmap',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward, size: 17, color: product.action),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  const _ScoreRingPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect.deflate(5),
      0,
      math.pi * 2,
      false,
      paint..color = track,
    );
    canvas.drawArc(
      rect.deflate(5),
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0, 1),
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.track != track;
}

class _WalletFlowHome extends StatelessWidget {
  const _WalletFlowHome({
    required this.cards,
    required this.estimatedValue,
    required this.projectedValue,
    required this.nextTarget,
  });

  final List<CreditCard> cards;
  final int estimatedValue;
  final int projectedValue;
  final String nextTarget;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    final safeTop = MediaQuery.paddingOf(context).top;
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(18, 14 + safeTop, 18, 30),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _WalletGreeting(
                onProfile: () => context.go('/profile'),
                onSearch: () => context.go('/strategy'),
                onAlerts: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Your strategy is up to date.')),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Estimated yearly value',
                style: TextStyle(color: product.muted, fontSize: 13),
              ),
              const SizedBox(height: 3),
              Text(
                '\$${_spacedAmount(estimatedValue)}',
                key: const ValueKey('wallet-flow-value'),
                style: TextStyle(
                  color: product.ink,
                  fontSize: 40,
                  height: 1,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(height: 30),
              _WalletSectionHeader(
                label: 'Cards',
                action: 'View all  +',
                onAction: () => context.go('/cards'),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 126,
                child: ListView.separated(
                  key: const ValueKey('wallet-flow-cards'),
                  scrollDirection: Axis.horizontal,
                  itemCount: cards.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) => _WalletPreviewCard(
                    card: cards[index],
                    index: index,
                    value: math.max(1, estimatedValue ~/ cards.length),
                    onTap: () => context.go('/cards'),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const _WalletSectionHeader(label: 'Strategy'),
              const SizedBox(height: 10),
              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _WalletShortcut(
                      color: const Color(0xFF8B6FE8),
                      icon: Icons.star_border,
                      label: 'Best\nrewards',
                      onTap: () => context.go('/cards'),
                    ),
                    _WalletShortcut(
                      color: const Color(0xFFFFA45E),
                      icon: Icons.bar_chart_rounded,
                      label: 'Strategy\nanalysis',
                      onTap: () => context.go('/strategy'),
                    ),
                    _WalletShortcut(
                      color: const Color(0xFFF04472),
                      icon: Icons.receipt_long_outlined,
                      label: 'Fee\nreview',
                      onTap: () => context.go('/cards'),
                    ),
                    _WalletShortcut(
                      color: const Color(0xFF58C5D5),
                      icon: Icons.auto_awesome_outlined,
                      label: 'Ask\nREVO',
                      onTap: () => context.go('/revo'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _WalletRewardsPanel(
                projectedValue: projectedValue,
                nextTarget: nextTarget,
                onRoadmap: () => context.go('/strategy'),
              ),
              const ApplyOfferButton(placement: ApplyPlacement.recommendation),
            ],
          ),
        ),
      ),
    );
  }

  static String _spacedAmount(int value) {
    final digits = value.toString();
    final output = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) output.write(' ');
      output.write(digits[index]);
    }
    return output.toString();
  }
}

class _WalletGreeting extends StatelessWidget {
  const _WalletGreeting({
    required this.onProfile,
    required this.onSearch,
    required this.onAlerts,
  });

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
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFF8267E8),
              shape: BoxShape.circle,
            ),
            child: const Text(
              'AM',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          'Hello, Alex',
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
      Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            tooltip: 'Strategy alerts',
            onPressed: onAlerts,
            icon: const Icon(Icons.notifications_none, size: 22),
          ),
          const Positioned(
            right: 9,
            top: 9,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFF04472),
                shape: BoxShape.circle,
              ),
              child: SizedBox(width: 6, height: 6),
            ),
          ),
        ],
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
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
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

class _WalletPreviewCard extends StatelessWidget {
  const _WalletPreviewCard({
    required this.card,
    required this.index,
    required this.value,
    required this.onTap,
  });

  final CreditCard card;
  final int index;
  final int value;
  final VoidCallback onTap;

  static const palettes = [
    [Color(0xFF28272B), Color(0xFF121214)],
    [Color(0xFFB49CFF), Color(0xFF8974F1)],
    [Color(0xFFFFB16B), Color(0xFFF07868)],
    [Color(0xFF68CFD9), Color(0xFF548ED7)],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = palettes[index % palettes.length];
    return Semantics(
      button: true,
      label: 'Open ${card.name}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Ink(
          width: 164,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -22,
                top: -28,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .06),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.brand.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    card.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .82),
                      fontSize: 9,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '\$${_WalletFlowHome._spacedAmount(value)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .4,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          card.multiplier,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .72),
                            fontSize: 8,
                          ),
                        ),
                      ),
                      Text(
                        '•• ${card.id.hashCode.abs().toString().padLeft(4, '0').substring(0, 4)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .72),
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletShortcut extends StatelessWidget {
  const _WalletShortcut({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 9),
    child: Semantics(
      button: true,
      label: label.replaceAll('\n', ' '),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Ink(
          width: 92,
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: .78), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 19),
              const Spacer(),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _WalletRewardsPanel extends StatelessWidget {
  const _WalletRewardsPanel({
    required this.projectedValue,
    required this.nextTarget,
    required this.onRoadmap,
  });

  final int projectedValue;
  final String nextTarget;
  final VoidCallback onRoadmap;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: product.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: product.ink.withValues(alpha: .04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Projected rewards',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                'This year  ›',
                style: TextStyle(color: product.action, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 68,
                height: 68,
                child: CustomPaint(
                  painter: const _RewardsRingPainter(),
                  child: Center(
                    child: Text(
                      '\$$projectedValue',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Wrap(
                  spacing: 14,
                  runSpacing: 10,
                  children: [
                    _RewardLegend(
                      color: Color(0xFF8267E8),
                      label: '47% Points',
                    ),
                    _RewardLegend(
                      color: Color(0xFFF04472),
                      label: '28% Credits',
                    ),
                    _RewardLegend(
                      color: Color(0xFFFFB166),
                      label: '25% Cash value',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: product.border),
          InkWell(
            onTap: onRoadmap,
            child: Padding(
              padding: const EdgeInsets.only(top: 13),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next best move',
                          style: TextStyle(color: product.muted, fontSize: 10),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Review $nextTarget',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward, size: 17, color: product.action),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardLegend extends StatelessWidget {
  const _RewardLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 9)),
    ],
  );
}

class _RewardsRingPainter extends CustomPainter {
  const _RewardsRingPainter();

  static const values = [.47, .28, .25];
  static const colors = [
    Color(0xFF8267E8),
    Color(0xFFF04472),
    Color(0xFFFFB166),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    const gap = .08;
    var start = -math.pi / 2;
    for (var index = 0; index < values.length; index++) {
      final sweep = math.pi * 2 * values[index] - gap;
      canvas.drawArc(
        rect.deflate(6),
        start,
        sweep,
        false,
        Paint()
          ..color = colors[index]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round,
      );
      start += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ValueHero extends StatelessWidget {
  const _ValueHero({
    required this.estimatedValue,
    required this.projectedValue,
    required this.score,
    required this.activeCards,
  });
  final int estimatedValue;
  final int projectedValue;
  final int score;
  final int activeCards;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    final treatment = product.heroTreatment;
    final decoration = switch (treatment) {
      HeroTreatment.market => BoxDecoration(
        gradient: LinearGradient(
          colors: [product.surface, product.subtle],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(product.radius),
      ),
      HeroTreatment.editorial => BoxDecoration(
        color: product.surface,
        border: Border(
          top: BorderSide(color: product.secondary, width: 3),
          bottom: BorderSide(color: product.border),
        ),
        boxShadow: [
          BoxShadow(
            color: product.ink.withValues(alpha: .07),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      HeroTreatment.terminal => BoxDecoration(
        color: product.subtle.withValues(alpha: .7),
        border: Border.all(color: product.action.withValues(alpha: .55)),
      ),
      HeroTreatment.wallet => BoxDecoration(
        color: product.surface,
        borderRadius: BorderRadius.circular(product.radius),
      ),
      HeroTreatment.walletStudio => BoxDecoration(
        color: product.surface,
        borderRadius: BorderRadius.circular(product.radius),
      ),
      HeroTreatment.decision => BoxDecoration(
        color: product.surface,
        borderRadius: BorderRadius.circular(product.radius),
      ),
      HeroTreatment.balanced => BoxDecoration(
        color: product.subtle,
        border: Border.all(color: product.border),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(product.radius * 1.35),
          topRight: Radius.circular(product.radius),
          bottomLeft: Radius.circular(product.radius),
          bottomRight: Radius.circular(product.radius * .35),
        ),
      ),
    };
    final eyebrow = switch (treatment) {
      HeroTreatment.market => '●  WALLET PERFORMANCE',
      HeroTreatment.editorial => 'The RevoCred Review  /  Portfolio',
      HeroTreatment.terminal => 'VALUE_ENGINE::FIRST_YEAR_ESTIMATE',
      HeroTreatment.wallet => 'Estimated yearly value',
      HeroTreatment.walletStudio => 'Projected rewards value',
      HeroTreatment.decision => 'Best card right now',
      HeroTreatment.balanced => 'Estimated first-year value',
    };
    return Container(
      padding: EdgeInsets.all(
        treatment == HeroTreatment.editorial ? 30 : product.panelPadding + 8,
      ),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: TextStyle(
              color: treatment == HeroTreatment.market
                  ? product.action
                  : product.muted,
              fontFamily: treatment == HeroTreatment.editorial
                  ? product.headingFontFamily
                  : product.bodyFontFamily,
              fontSize: treatment == HeroTreatment.editorial ? 13 : 10,
              fontStyle: treatment == HeroTreatment.editorial
                  ? FontStyle.italic
                  : FontStyle.normal,
              fontWeight: FontWeight.w800,
              letterSpacing: treatment == HeroTreatment.editorial ? .1 : 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '\$$estimatedValue',
            style: TextStyle(
              color:
                  treatment == HeroTreatment.market ||
                      treatment == HeroTreatment.terminal
                  ? product.action
                  : product.ink,
              fontFamily: product.headingFontFamily,
              fontSize: switch (treatment) {
                HeroTreatment.market => 58,
                HeroTreatment.editorial => 56,
                HeroTreatment.terminal => 42,
                HeroTreatment.wallet => 46,
                HeroTreatment.walletStudio => 48,
                HeroTreatment.decision => 48,
                HeroTreatment.balanced => 52,
              },
              height: 1,
              fontWeight: treatment == HeroTreatment.editorial
                  ? FontWeight.w600
                  : FontWeight.w900,
              letterSpacing: treatment == HeroTreatment.terminal ? -1 : -1.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Demo estimate, not guaranteed',
            style: TextStyle(color: product.muted, fontSize: 12),
          ),
          if (treatment == HeroTreatment.market) ...[
            const SizedBox(height: 18),
            SizedBox(
              height: 68,
              width: double.infinity,
              child: CustomPaint(
                painter: _ValueSparkline(
                  color: product.action,
                  fill: product.action.withValues(alpha: .12),
                ),
              ),
            ),
          ] else if (treatment == HeroTreatment.editorial) ...[
            const SizedBox(height: 18),
            Divider(color: product.ink, thickness: 1),
          ] else if (treatment == HeroTreatment.terminal) ...[
            const SizedBox(height: 15),
            Text(
              'MODEL_STATUS=DETERMINISTIC  CONFIDENCE=DEMO',
              style: TextStyle(
                color: product.secondary,
                fontSize: 10,
                letterSpacing: .5,
              ),
            ),
          ],
          SizedBox(height: treatment == HeroTreatment.editorial ? 28 : 22),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _MiniStat(label: 'Cash value', value: '\$$projectedValue'),
              _MiniStat(label: 'Wallet health', value: '$score / 100'),
              _MiniStat(label: 'Active cards', value: '$activeCards'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ValueSparkline extends CustomPainter {
  const _ValueSparkline({required this.color, required this.fill});

  final Color color;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Path()
      ..moveTo(0, size.height * .78)
      ..cubicTo(
        size.width * .15,
        size.height * .62,
        size.width * .2,
        size.height * .74,
        size.width * .31,
        size.height * .5,
      )
      ..cubicTo(
        size.width * .43,
        size.height * .24,
        size.width * .52,
        size.height * .57,
        size.width * .64,
        size.height * .32,
      )
      ..cubicTo(
        size.width * .76,
        size.height * .08,
        size.width * .84,
        size.height * .3,
        size.width,
        0,
      );
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = fill);
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ValueSparkline oldDelegate) =>
      oldDelegate.color != color || oldDelegate.fill != fill;
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 104,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: context.product.muted, fontSize: 11),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: context.product.success,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _NextAction extends StatelessWidget {
  const _NextAction({required this.cardName});
  final String cardName;

  @override
  Widget build(BuildContext context) => AppPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.north_east, color: context.product.action),
        const SizedBox(height: 18),
        const SectionLabel('Next best action'),
        const SizedBox(height: 8),
        Text('Review $cardName', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 7),
        Text(
          'It fills your travel protection gap. Check current issuer terms before applying.',
          style: TextStyle(color: context.product.muted),
        ),
        const SizedBox(height: 18),
        GradientButton(
          label: 'View your roadmap',
          icon: Icons.arrow_forward,
          onPressed: () => context.go('/strategy'),
        ),
      ],
    ),
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

class _DemoBadge extends StatelessWidget {
  const _DemoBadge();

  @override
  Widget build(BuildContext context) =>
      StatusPill(label: 'DEMO ESTIMATES', color: context.product.warning);
}
