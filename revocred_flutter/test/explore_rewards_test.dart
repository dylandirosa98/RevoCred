import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/app.dart';
import 'package:revocred_flutter/core/config/app_config.dart';
import 'package:revocred_flutter/core/data/demo_seed.dart';
import 'package:revocred_flutter/core/data/explore_rewards_asset.dart';
import 'package:revocred_flutter/core/data/mock_app_repository.dart';
import 'package:revocred_flutter/core/logic/explore_rewards.dart';
import 'package:revocred_flutter/core/logic/ongoing_value.dart';
import 'package:revocred_flutter/core/models/app_models.dart';
import 'package:revocred_flutter/core/models/explore_rewards.dart';
import 'package:revocred_flutter/core/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppData _member({
  Map<String, int> spend = const {},
  OngoingValue? value,
  List<CreditCard> wallet = const [],
}) {
  final demo = createDemoAppData();
  return AppData(
    profile: demo.profile,
    wallet: wallet,
    catalog: const [],
    roadmap: const [],
    messages: const [],
    quickPrompts: const [],
    pointsValue: 0,
    projectedYearlyValue: 0,
    monthlySpend: spend,
    ongoingValue: value,
  );
}

/// Demo account with a server-style wallet estimate, as signed-in members get.
class _MemberRepository extends MockAppRepository {
  _MemberRepository(this.examples);
  final ExploreRewards examples;

  @override
  Future<ExploreRewards> loadExploreRewards() async => examples;

  @override
  Future<AppData> loadAppData() async => (await super.loadAppData()).copyWith(
    ongoingValue: const OngoingValue(rewardsCents: 21600),
  );
}

String _grouped(int value) => value.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('community wallet rates and provenance reach Explore inputs', () {
    final card = CreditCard.fromApiJson({
      'id': 'owned-community',
      'name': 'Active Cash',
      'terms_source': 'community',
      'terms_unknown': false,
      'rewards_type': 'cash_back',
      'reward_rates': {'other': 2},
      'community_terms': {
        'source_name': 'OpenCard DB community data',
        'captured_at': '2026-11-09T00:00:00Z',
        'mapping_version': 'opencard-terms-v2',
      },
    }, isActive: true).copyWith(walletCardId: 'wallet-id');
    expect(card.termsSource, 'community');
    expect(card.communityTerms?['captured_at'], '2026-11-09T00:00:00Z');
    final earning = walletEarning(
      _member(
        wallet: [card],
        spend: {'other': 1000},
        value: const OngoingValue(rewardsCents: 24000),
      ),
    );
    expect(earning.annualPoints, 24000);
    expect(earning.cashBack, isTrue);
    expect(earning.multiplier, 2);
  });

  group('formulas match the approved handoff', () {
    test('flight value subtracts taxes and fees', () {
      // SFO → Paris: $603 cash, 21,000 points + $5.
      expect(
        redemptionCentsPerPoint(cash: 603, points: 21000, fees: 5),
        closeTo(2.8476, .0001),
      );
      expect(extraValueDollars(cash: 603, points: 21000, fees: 5), 388);
    });

    test('hotel value has no fees', () {
      // Park Hyatt Paris: $1,700 or 45,000 points.
      expect(
        redemptionCentsPerPoint(cash: 1700, points: 45000),
        closeTo(3.7778, .0001),
      );
      expect(extraValueDollars(cash: 1700, points: 45000), 1250);
    });

    test('below-baseline redemptions are negative, not savings', () {
      // SFO → Bangkok: $419 cash vs 50,000 points + $16.
      expect(extraValueDollars(cash: 419, points: 50000, fees: 16), -97);
    });

    test('Cape Town uses the 1¢ baseline, not the table annotation', () {
      expect(pointsBaselineDollars(11000), 110);
    });
  });

  group('personalized to the wallet', () {
    test('uses the server estimate and excludes housing from card spend', () {
      final earning = walletEarning(
        _member(
          spend: const {'rent': 2000, 'dining': 500, 'other': 1500},
          value: const OngoingValue(rewardsCents: 60000),
        ),
      );
      expect(earning.personalized, isTrue);
      expect(earning.monthlySpend, 2000);
      expect(earning.annualPoints, 60000);
      expect(earning.multiplier, 2.5);
      expect(formatMultiplier(earning.multiplier), '2.5x');
    });

    test('falls back to example numbers without spending or rewards', () {
      expect(walletEarning(_member()).personalized, isFalse);
      expect(
        walletEarning(
          _member(spend: const {'dining': 500}, value: const OngoingValue()),
        ).personalized,
        isFalse,
      );
    });

    test('an all cash-back wallet is shown in dollars, not points', () {
      CreditCard card(String id, {String type = 'cash_back', bool t = false}) =>
          CreditCard.fromApiJson({
            'id': id,
            'name': id,
            'issuer': 'Test',
            'rewards_type': type,
            'transferable_points': t,
            'reward_rates': {'other': 2},
          }, isActive: true);
      final spend = const {'other': 1000};
      const value = OngoingValue(rewardsCents: 24000);
      final cash = walletEarning(
        _member(spend: spend, value: value, wallet: [card('double')]),
      );
      expect(cash.cashBack, isTrue);
      expect(cash.annualDollars, 240);
      final travel = walletEarning(
        _member(
          spend: spend,
          value: value,
          wallet: [
            card('double'),
            card('sapphire', type: 'travel', t: true),
          ],
        ),
      );
      expect(travel.cashBack, isFalse);
      expect(
        walletEarning(_member(spend: spend, value: value)).cashBack,
        isFalse,
      );
    });

    test('the wallet view reproduces the wallet estimate exactly', () {
      const earning = WalletEarning(monthlySpend: 900, annualPoints: 21601);
      expect(
        simulatedAnnualPoints(
          earning,
          monthlySpend: 900,
          multiplier: earning.multiplier,
        ),
        21601,
      );
      expect(
        simulatedAnnualPoints(earning, monthlySpend: 1000, multiplier: 3),
        36000,
      );
    });

    test('guests see the sample wallet, not "your" numbers', () {
      final demo = createDemoAppData().copyWith(
        ongoingValue: const OngoingValue(rewardsCents: 21600),
      );
      final sample = walletEarning(demo, ownWallet: false);
      expect(sample.source, EarningSource.sample);
      expect(sample.personalized, isFalse);
      expect(sample.annualPoints, 21600);
      expect(isOwnWallet(demo, authenticated: false), isFalse);
      expect(isOwnWallet(demo, authenticated: true), isTrue);
      expect(
        isOwnWallet(
          demo.copyWith(isPersonalPreview: true),
          authenticated: false,
        ),
        isTrue,
      );
    });

    test('demo card labels map to the server rate keys', () {
      expect(
        ratesFromLabels([
          '4x dining',
          '4x U.S. supermarkets',
          '3x flights',
          '1.5% cash back everywhere',
          '5x portal travel',
          '5% rotating categories',
          '3x gas and EV charging',
        ]),
        {'dining': 4, 'groceries': 4, 'flights': 3, 'other': 1.5, 'gas': 3},
      );
    });

    test('the demo wallet earns points in the local estimate', () {
      final demo = createDemoAppData();
      final value = estimateOngoingValue(demo.wallet, demo.monthlySpend, '');
      expect(value.rewardsCents, greaterThan(0));
      final earning = walletEarning(demo);
      expect(earning.personalized, isTrue);
      expect(earning.monthlySpend, 900);
      expect(earning.annualPoints, value.rewardsCents);
    });

    test('months to earn', () {
      expect(monthsToEarn(21000, 42000), 6);
      expect(monthsToEarn(1, 0), double.infinity);
    });
  });

  test('bundled examples are complete and every route has a fare', () async {
    final rewards = await loadBundledExploreRewards();
    expect(rewards.airports.map((a) => a.code), ['SFO', 'DFW', 'JFK', 'MIA']);
    expect(rewards.regions, hasLength(6));
    expect(rewards.regions.expand((r) => r.hotels), hasLength(15));
    expect(rewards.fares.values.expand((f) => f.values), hasLength(112));
    for (final airport in rewards.airports) {
      for (final region in rewards.regions) {
        for (final destination in rewards.destinations(region, airport.code)) {
          expect(destination.code, isNot(airport.code));
          expect(rewards.fare(airport.code, destination.code), isNotNull);
        }
      }
    }
  });

  testWidgets('Home opens Explore Rewards with the member’s own numbers', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final examples = (await tester.runAsync(loadBundledExploreRewards))!;
    final repository = _MemberRepository(examples);
    await tester.pumpWidget(
      RevoCredBootstrap(
        config: const AppConfig(useMocks: true),
        repository: repository,
        preferences: preferences,
      ),
    );
    await tester.pumpAndSettle();
    appRouter.go('/home');
    await tester.pumpAndSettle();

    final data = await repository.loadAppData();
    final earning = walletEarning(data);
    expect(earning.personalized, isTrue);

    final entry = find.byKey(const ValueKey('explore-rewards-entry'));
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('${_grouped(earning.annualPoints)} points a year'),
      findsOneWidget,
    );
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.text('Explore Rewards'), findsWidgets);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('explore-annual-points')))
          .data,
      _grouped(earning.annualPoints),
    );
    expect(
      find.textContaining(formatMultiplier(earning.multiplier)),
      findsWidgets,
    );

    // A fixed multiplier recalculates from the slider spend.
    await tester.tap(find.byKey(const ValueKey('explore-mult-3')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('explore-annual-points')))
          .data,
      _grouped(earning.monthlySpend * 12 * 3),
    );
    await tester.tap(find.byKey(const ValueKey('explore-reset-wallet')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('explore-annual-points')))
          .data,
      _grouped(earning.annualPoints),
    );

    // Default flight: SFO → London in Europe ($552, 21,000 + $5).
    final savings = find.byKey(const ValueKey('explore-savings'));
    await tester.ensureVisible(savings);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(savings).data,
      'Save \$337 by booking with points',
    );
    expect(find.byKey(const ValueKey('explore-affordability')), findsOneWidget);

    // A below-baseline example says so plainly instead of claiming savings.
    // JFK → Cabo: $223 cash vs 15,000 points + $103.
    await tester.ensureVisible(
      find.byKey(const ValueKey('explore-airport-JFK')),
    );
    await tester.tap(find.byKey(const ValueKey('explore-airport-JFK')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('explore-region-North America')),
    );
    await tester.tap(
      find.byKey(const ValueKey('explore-region-North America')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('explore-destination-SJD')),
    );
    await tester.tap(find.byKey(const ValueKey('explore-destination-SJD')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(savings);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(savings).data,
      '\$30 below the points baseline after fees',
    );
    expect(
      find.textContaining('Paying cash is the better deal'),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('explore-region-Europe')),
    );
    await tester.tap(find.byKey(const ValueKey('explore-region-Europe')));
    await tester.pumpAndSettle();

    // Hotels: Park Hyatt Paris is first in Europe.
    await tester.ensureVisible(find.byKey(const ValueKey('explore-tab')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hotels'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(savings);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(savings).data,
      'Save \$1,250 by booking with points',
    );

    // The help sheet explains points value in plain language.
    await tester.tap(find.byKey(const ValueKey('explore-help')));
    await tester.pumpAndSettle();
    expect(find.text('How Explore Rewards works'), findsOneWidget);
    expect(
      find.textContaining('not money added to your account'),
      findsOneWidget,
    );
  });
}
