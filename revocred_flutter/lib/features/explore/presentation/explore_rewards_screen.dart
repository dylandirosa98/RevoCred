import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logic/explore_rewards.dart';
import '../../../core/logic/friendly_error.dart';
import '../../../core/models/explore_rewards.dart';
import '../../../core/state/app_controller.dart';
import '../../../core/theme/app_theme.dart';

final exploreRewardsProvider = FutureProvider.autoDispose<ExploreRewards>(
  (ref) => ref.watch(appRepositoryProvider).loadExploreRewards(),
);

/// Shows what the member's own points could unlock, using illustrative flight
/// and hotel examples. Nothing here selects or ranks cards.
class ExploreRewardsScreen extends ConsumerWidget {
  const ExploreRewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final data = state.data;
    final rewards = ref.watch(exploreRewardsProvider);
    final wallet = data == null
        ? WalletEarning.example
        : walletEarning(
            data,
            ownWallet: isOwnWallet(data, authenticated: state.isAuthenticated),
          );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore Rewards'),
        actions: [
          IconButton(
            key: const ValueKey('explore-help'),
            tooltip: 'How this works',
            icon: const Icon(Icons.help_outline),
            onPressed: () => showExploreRewardsHelp(context),
          ),
        ],
      ),
      body: rewards.when(
        data: (rewards) => _ExploreBody(rewards: rewards, wallet: wallet),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(friendlyError(error), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(exploreRewardsProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Plain-language explanation of points value and the "save" figure.
Future<void> showExploreRewardsHelp(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final product = context.product;
      Widget point(IconData icon, String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: product.action),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(body, style: TextStyle(color: product.muted)),
                ],
              ),
            ),
          ],
        ),
      );
      return SafeArea(
        child: SingleChildScrollView(
          key: const ValueKey('explore-help-sheet'),
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How Explore Rewards works',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              point(
                Icons.savings_outlined,
                'Your cards earn points',
                'Every dollar you spend earns points. Cards earn more in some categories, like dining or travel. Your yearly total comes from your own spending and cards.',
              ),
              point(
                Icons.balance_outlined,
                'A point is worth about 1¢',
                'Cash back and most simple redemptions give about 1¢ per point, so 10,000 points ≈ \$100. We use that as the starting line.',
              ),
              point(
                Icons.trending_up,
                'Travel can be worth more',
                'Booking flights or hotels with points often gets more than 1¢ per point. “Each point is worth” shows how much this example gets.',
              ),
              point(
                Icons.check_circle_outline,
                'What “Save” means',
                'Save = cash price − the points’ 1¢ value − any taxes and fees. It is the extra value compared with redeeming at 1¢, not money added to your account.',
              ),
              point(
                Icons.info_outline,
                'These are examples',
                'Prices come from past examples, not live fares or guaranteed award availability. Some programs are only reachable through certain cards and transfer partners.',
              ),
            ],
          ),
        ),
      );
    },
  );
}

enum _Tab { flights, hotels }

class _ExploreBody extends StatefulWidget {
  const _ExploreBody({required this.rewards, required this.wallet});
  final ExploreRewards rewards;
  final WalletEarning wallet;

  @override
  State<_ExploreBody> createState() => _ExploreBodyState();
}

class _ExploreBodyState extends State<_ExploreBody> {
  static const _spendStep = 250;
  static const _minSpend = 250;

  late int spend;

  /// Null means "use the starting wallet's average rate".
  int? fixedMultiplier;
  var tab = _Tab.flights;
  late String region;
  late String airport;
  String? destination;
  String? hotel;

  WalletEarning get wallet => widget.wallet;
  ExploreRewards get rewards => widget.rewards;

  int get maxSpend {
    final needed = (wallet.monthlySpend / _spendStep).ceil() * _spendStep;
    return needed > 10000 ? needed : 10000;
  }

  int get _startSpend =>
      ((wallet.monthlySpend / _spendStep).round() * _spendStep).clamp(
        _minSpend,
        maxSpend,
      );
  double get multiplier => fixedMultiplier?.toDouble() ?? wallet.multiplier;
  int get annualPoints => simulatedAnnualPoints(
    wallet,
    monthlySpend: spend == _startSpend ? wallet.monthlySpend : spend,
    multiplier: multiplier,
  );
  bool get isStartingView => fixedMultiplier == null && spend == _startSpend;

  /// The wallet pays plain cash back, so amounts are dollars, not points.
  bool get cash => wallet.cashBack;

  /// Who "your" refers to in copy.
  String get _whose => switch (wallet.source) {
    EarningSource.wallet => 'your cards',
    EarningSource.sample => 'the sample wallet',
    EarningSource.example => 'a typical card',
  };

  String get _walletChipLabel => switch (wallet.source) {
    EarningSource.wallet => 'My cards',
    EarningSource.sample => 'Sample wallet',
    EarningSource.example => 'Typical',
  };

  ExploreRegion get activeRegion =>
      rewards.regions.firstWhere((r) => r.name == region);

  @override
  void initState() {
    super.initState();
    spend = _startSpend;
    region = rewards.regions
        .firstWhere(
          (r) => r.name == 'Europe',
          orElse: () => rewards.regions.first,
        )
        .name;
    airport = rewards.airports.first.code;
  }

  void _reset() => setState(() {
    spend = _startSpend;
    fixedMultiplier = null;
  });

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return SingleChildScrollView(
      key: const ValueKey('explore-rewards'),
      padding: EdgeInsets.fromLTRB(18, 8, 18, 32 + safeBottom),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                !wallet.personalized
                    ? 'See how many points cards can earn in a year, then what those points could book.'
                    : cash
                    ? 'See how much cash back your cards earn in a year, and the trips it could pay for.'
                    : 'See how many points your cards earn in a year, then what those points could book.',
                style: TextStyle(color: product.muted, fontSize: 15),
              ),
              const SizedBox(height: 18),
              _StepTitle(
                number: 1,
                title: cash ? 'Your yearly cash back' : 'Your yearly points',
              ),
              const SizedBox(height: 10),
              _simulator(context),
              const SizedBox(height: 26),
              const _StepTitle(number: 2, title: 'Pick a trip'),
              const SizedBox(height: 10),
              SegmentedButton<_Tab>(
                key: const ValueKey('explore-tab'),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _Tab.flights,
                    label: Text('Flights'),
                    icon: Icon(Icons.flight_takeoff),
                  ),
                  ButtonSegment(
                    value: _Tab.hotels,
                    label: Text('Hotels'),
                    icon: Icon(Icons.hotel_outlined),
                  ),
                ],
                selected: {tab},
                onSelectionChanged: (value) =>
                    setState(() => tab = value.first),
              ),
              if (tab == _Tab.flights) ...[
                const SizedBox(height: 16),
                _label(context, 'Flying from'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in rewards.airports)
                      ChoiceChip(
                        key: ValueKey('explore-airport-${item.code}'),
                        label: Text('${item.city} (${item.code})'),
                        selected: airport == item.code,
                        onSelected: (_) => setState(() => airport = item.code),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              _label(context, 'Region'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in rewards.regions)
                    ChoiceChip(
                      key: ValueKey('explore-region-${item.name}'),
                      label: Text(item.name),
                      selected: region == item.name,
                      onSelected: (_) => setState(() {
                        region = item.name;
                        destination = null;
                        hotel = null;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (tab == _Tab.flights)
                ..._flights(context)
              else
                ..._hotels(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _simulator(BuildContext context) {
    final product = context.product;
    final monthlyPoints = (annualPoints / 12).round();
    final basis = switch (wallet.source) {
      EarningSource.wallet =>
        cash
            ? 'Starting from your wallet: about ${_money(wallet.monthlySpend)} a month on cards, earning ${_rate(wallet.multiplier)}% cash back on average.'
            : 'Starting from your wallet: about ${_money(wallet.monthlySpend)} a month on cards, earning ${_rate(wallet.multiplier)} points per \$1 on average.',
      EarningSource.sample =>
        'Starting from a sample wallet. Create an account or answer a few questions to see your own numbers.',
      EarningSource.example =>
        'Example numbers. Add your spending and cards to see your own.',
    };
    return _Panel(
      key: const ValueKey('explore-simulator'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            basis,
            key: const ValueKey('explore-basis'),
            style: TextStyle(color: product.muted, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 14),
          _Metric(
            label: cash ? 'Cash back a year' : 'Points a year',
            value: cash
                ? _money((annualPoints / 100).round())
                : _count(annualPoints),
            valueKey: const ValueKey('explore-annual-points'),
          ),
          const SizedBox(height: 4),
          Text(
            key: const ValueKey('explore-value-range'),
            cash
                ? 'Cash back is worth its face value toward any trip.'
                : 'Worth about ${_money(annualPoints * .01)} at 1¢ each, and often more when booked as travel.',
            style: TextStyle(
              color: product.action,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            cash
                ? '${_money((annualPoints / 1200).round())} a month · Estimated from your spending; actual cash back depends on each card\'s terms.'
                : '${_count(monthlyPoints)} points a month · ${rewards.estimateDisclaimer}',
            style: TextStyle(color: product.muted, fontSize: 12),
          ),
          const Divider(height: 28),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Try different numbers',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (!isStartingView)
                TextButton.icon(
                  key: const ValueKey('explore-reset-wallet'),
                  onPressed: _reset,
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: Text(
                    wallet.personalized ? 'Back to my numbers' : 'Reset',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Expanded(child: Text('Monthly card spending')),
              Text(
                _money(spend == _startSpend ? wallet.monthlySpend : spend),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          Slider(
            key: const ValueKey('explore-spend-slider'),
            min: _minSpend.toDouble(),
            max: maxSpend.toDouble(),
            divisions: (maxSpend - _minSpend) ~/ _spendStep,
            value: spend.toDouble(),
            label: _money(spend),
            // At the starting position the screen shows the exact wallet
            // spend; announce that same number.
            semanticFormatterCallback: (value) =>
                '${_money(value.round() == _startSpend ? wallet.monthlySpend : value.round())} a month',
            onChanged: (value) => setState(() => spend = value.round()),
          ),
          Text(
            cash ? 'Cash back per \$1 (average)' : 'Points per \$1 (average)',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                key: const ValueKey('explore-mult-wallet'),
                label: Text(
                  '$_walletChipLabel · ${_rate(wallet.multiplier)}${cash ? '%' : 'x'}',
                ),
                selected: fixedMultiplier == null,
                onSelected: (_) => setState(() => fixedMultiplier = null),
              ),
              // Few wallets average more than 3x across all spending.
              for (final value in const [1, 2, 3])
                ChoiceChip(
                  key: ValueKey('explore-mult-$value'),
                  label: Text(cash ? '$value%' : '${value}x'),
                  selected: fixedMultiplier == value,
                  onSelected: (_) => setState(() => fixedMultiplier = value),
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _flights(BuildContext context) {
    final product = context.product;
    final options = rewards.destinations(activeRegion, airport);
    if (options.isEmpty) {
      return [
        Text(
          'No examples from $airport in this region yet.',
          style: TextStyle(color: product.muted),
        ),
      ];
    }
    final selected = options.firstWhere(
      (d) => d.code == destination,
      orElse: () => options.first,
    );
    final fare = rewards.fare(airport, selected.code)!;
    final origin = rewards.airports.firstWhere((a) => a.code == airport);
    return [
      _label(context, 'Destination'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in options)
            ChoiceChip(
              key: ValueKey('explore-destination-${item.code}'),
              label: Text(item.name),
              selected: item.code == selected.code,
              onSelected: (_) => setState(() => destination = item.code),
            ),
        ],
      ),
      const SizedBox(height: 16),
      _Panel(
        key: const ValueKey('explore-flight-result'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _ResultHeader(title: 'ONE-WAY FLIGHT EXAMPLE'),
            const SizedBox(height: 14),
            Row(
              children: [
                _Endpoint(code: airport, caption: origin.city),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: Divider(color: product.border)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.flight, color: product.action),
                      ),
                      Expanded(child: Divider(color: product.border)),
                    ],
                  ),
                ),
                _Endpoint(
                  code: selected.code,
                  caption: selected.name.split(',').first,
                  end: true,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              cash
                  ? 'Example ${fare.airline} fare'
                  : 'Booked through ${fare.airline}’s rewards program',
              style: TextStyle(color: product.muted, fontSize: 13),
            ),
            const Divider(height: 24),
            if (cash) ...[
              _CashPrice(cash: fare.cash),
              _Affordability(
                points: fare.cash * 100,
                annualPoints: annualPoints,
                whose: _whose,
                cashBack: true,
              ),
              _TravelCardTip(
                cash: fare.cash,
                points: fare.points,
                fees: fare.fees,
              ),
            ] else ...[
              _Comparison(
                cashLabel: 'Pay cash',
                cash: fare.cash,
                pointsLabel: 'Or use points',
                points: fare.points,
                fees: fare.fees,
              ),
              _Summary(cash: fare.cash, points: fare.points, fees: fare.fees),
              _Affordability(
                points: fare.points,
                annualPoints: annualPoints,
                whose: _whose,
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      _Disclaimer(rewards.flightDisclaimer),
    ];
  }

  List<Widget> _hotels(BuildContext context) {
    final product = context.product;
    final options = activeRegion.hotels;
    final selected = options.firstWhere(
      (h) => h.name == hotel,
      orElse: () => options.first,
    );
    return [
      _label(context, 'Hotel'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in options)
            ChoiceChip(
              key: ValueKey('explore-hotel-${item.name}'),
              label: Text(item.name),
              selected: item.name == selected.name,
              onSelected: (_) => setState(() => hotel = item.name),
            ),
        ],
      ),
      const SizedBox(height: 16),
      _Panel(
        key: const ValueKey('explore-hotel-result'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _ResultHeader(title: 'ONE-NIGHT HOTEL EXAMPLE'),
            const SizedBox(height: 10),
            Text(selected.name, style: Theme.of(context).textTheme.titleMedium),
            Text(
              '${selected.place} · ${selected.program}',
              style: TextStyle(color: product.muted, fontSize: 13),
            ),
            const Divider(height: 24),
            if (cash) ...[
              _CashPrice(cash: selected.cash),
              _Affordability(
                points: selected.cash * 100,
                annualPoints: annualPoints,
                whose: _whose,
                unit: 'night',
                cashBack: true,
              ),
              _TravelCardTip(cash: selected.cash, points: selected.points),
            ] else ...[
              _Comparison(
                cashLabel: 'Pay cash',
                cash: selected.cash,
                pointsLabel: 'Or use points',
                points: selected.points,
              ),
              _Summary(cash: selected.cash, points: selected.points),
              _Affordability(
                points: selected.points,
                annualPoints: annualPoints,
                whose: _whose,
                unit: 'night',
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (!cash)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline, color: product.action, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Eligible credit card points may also transfer to this hotel’s loyalty program, depending on the card and program.',
                style: TextStyle(color: product.muted, fontSize: 13),
              ),
            ),
          ],
        ),
      const SizedBox(height: 12),
      _Disclaimer(rewards.hotelDisclaimer),
    ];
  }

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({required this.number, required this.title});
  final int number;
  final String title;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: product.action,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: TextStyle(
              color: product.actionInk,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: product.surface,
        borderRadius: BorderRadius.circular(product.radius),
        border: Border.all(color: product.border),
      ),
      child: child,
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.valueKey});
  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: product.muted, fontSize: 13)),
        const SizedBox(height: 2),
        Text(
          value,
          key: valueKey,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: product.ink,
          ),
        ),
      ],
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: product.muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: product.subtle,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            'Example',
            style: TextStyle(color: product.muted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _Endpoint extends StatelessWidget {
  const _Endpoint({
    required this.code,
    required this.caption,
    this.end = false,
  });
  final String code;
  final String caption;
  final bool end;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 120),
    child: Column(
      crossAxisAlignment: end
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          code,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        Text(
          caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: context.product.muted, fontSize: 12),
        ),
      ],
    ),
  );
}

class _Comparison extends StatelessWidget {
  const _Comparison({
    required this.cashLabel,
    required this.cash,
    required this.pointsLabel,
    required this.points,
    this.fees,
  });
  final String cashLabel;
  final int cash;
  final String pointsLabel;
  final int points;
  final int? fees;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    final small = TextStyle(color: product.muted, fontSize: 12);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(cashLabel, style: small),
              Text(
                _money(cash),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(pointsLabel, style: small),
              Text(
                '${_count(points)} pts',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (fees != null && fees! > 0)
                Text('+ ${_money(fees!)} taxes & fees', style: small),
              Text(
                '≈ ${_money(pointsBaselineDollars(points))} at 1¢ each',
                style: small,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.cash, required this.points, this.fees = 0});
  final int cash;
  final int points;
  final int fees;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    final extra = extraValueDollars(cash: cash, points: points, fees: fees);
    final cents = redemptionCentsPerPoint(
      cash: cash,
      points: points,
      fees: fees,
    );
    final good = extra > 0.005;
    final afterFees = fees > 0 ? ' after fees' : '';
    final message = good
        ? 'Save ${_money(extra)} by booking with points'
        : extra < -0.005
        ? '${_money(extra.abs())} below the points baseline$afterFees'
        : 'Equal to the points baseline$afterFees';
    final explain = good
        ? cents >= 1.95
              ? 'About ${cents.toStringAsFixed(1)}× the value of using points as 1¢ cash back.'
              : 'More value than using points as 1¢ cash back.'
        : 'Paying cash is the better deal for this one — your points go further on other trips.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Each point is worth',
                style: TextStyle(color: product.muted),
              ),
            ),
            Text(
              '${cents.toStringAsFixed(2)}¢',
              key: const ValueKey('explore-redemption-value'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (good ? product.success : product.warning).withValues(
              alpha: .1,
            ),
            borderRadius: BorderRadius.circular(product.radius),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                good ? Icons.check_circle_outline : Icons.info_outline,
                color: good ? product.success : product.warning,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      key: const ValueKey('explore-savings'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      explain,
                      style: TextStyle(color: product.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Ties the example back to the wallet's own earning.
class _Affordability extends StatelessWidget {
  const _Affordability({
    required this.points,
    required this.annualPoints,
    required this.whose,
    this.unit = 'trip',
    this.cashBack = false,
  });

  /// Points needed, or for cash back the price in cents.
  final int points;
  final int annualPoints;
  final String whose;
  final String unit;
  final bool cashBack;

  @override
  Widget build(BuildContext context) {
    if (annualPoints <= 0) return const SizedBox.shrink();
    final product = context.product;
    final months = monthsToEarn(points, annualPoints);
    final perYear = annualPoints ~/ points;
    final timing = months < 1
        ? 'less than a month'
        : months < 1.5
        ? 'about 1 month'
        : 'about ${months.round()} months';
    final plural = perYear == 1 ? unit : '${unit}s';
    final earn = cashBack ? 'enough cash back' : 'enough';
    final text = perYear >= 1
        ? 'With $whose, you earn $earn for this $unit in $timing — about $perYear $plural a year.'
        : 'With $whose, this $unit takes $timing of earning${cashBack ? ' cash back' : ''}.';
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: product.action.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(product.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.calendar_month_outlined, color: product.action, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              key: const ValueKey('explore-affordability'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// The cash price of an example, for a cash-back wallet.
class _CashPrice extends StatelessWidget {
  const _CashPrice({required this.cash});
  final int cash;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          'Cash price',
          style: TextStyle(color: context.product.muted),
        ),
      ),
      Text(
        _money(cash),
        key: const ValueKey('explore-cash-price'),
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
      ),
    ],
  );
}

/// For a cash-back wallet: what travel points would get on the same booking.
class _TravelCardTip extends StatelessWidget {
  const _TravelCardTip({
    required this.cash,
    required this.points,
    this.fees = 0,
  });
  final int cash;
  final int points;
  final int fees;

  @override
  Widget build(BuildContext context) {
    final cents = redemptionCentsPerPoint(
      cash: cash,
      points: points,
      fees: fees,
    );
    if (cents < 1.2) return const SizedBox.shrink();
    final product = context.product;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: product.action, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'With travel points instead, this booking gets about ${cents.toStringAsFixed(1)}¢ a point, versus 1¢ for cash back. A travel card could stretch your rewards further.',
              key: const ValueKey('explore-travel-tip'),
              style: TextStyle(color: product.muted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(color: context.product.muted, fontSize: 12, height: 1.4),
  );
}

/// A blended rate for display, e.g. `1.8`.
String _rate(double value) =>
    formatMultiplier(value).replaceFirst(RegExp(r'x$'), '');

String _money(num value) {
  final whole = value == value.roundToDouble();
  final fixed = value.abs().toStringAsFixed(whole ? 0 : 2);
  final parts = fixed.split('.');
  final grouped = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '${value < 0 ? '-' : ''}\$$grouped${parts.length > 1 ? '.${parts[1]}' : ''}';
}

String _count(int value) => value.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);
