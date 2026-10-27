import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/app.dart';
import 'package:revocred_flutter/core/config/app_config.dart';
import 'package:revocred_flutter/core/data/demo_seed.dart';
import 'package:revocred_flutter/core/data/mock_app_repository.dart';
import 'package:revocred_flutter/core/logic/playbook.dart';
import 'package:revocred_flutter/core/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:revocred_flutter/core/models/app_models.dart';

void main() {
  testWidgets('strategy prioritizes next action and supports exploration', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'app_theme_variant': 'decisionFlow',
    });
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      RevoCredBootstrap(
        config: const AppConfig(useMocks: true),
        repository: MockAppRepository(),
        preferences: preferences,
      ),
    );
    appRouter.go('/strategy');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('strategy-summary')), findsOneWidget);
    expect(find.byKey(const ValueKey('strategy-next-action')), findsOneWidget);
    expect(find.byKey(const ValueKey('strategy-timeline')), findsOneWidget);
    expect(find.text('Freedom Flex'), findsWidgets);
    expect(find.textContaining('Consider next: Freedom Flex'), findsOneWidget);
    expect(find.text('1 OF 3 ROLES COVERED'), findsOneWidget);
    expect(find.text('ROLE 1: IN YOUR WALLET'), findsOneWidget);
    expect(find.text('Freedom Unlimited'), findsWidgets);
    expect(find.text('APPLICATION TIMELINE'), findsOneWidget);
    expect(find.text('Application timeline'), findsNothing);
    expect(find.textContaining('No new card currently improves'), findsNothing);
    expect(tester.takeException(), isNull);

    final details = find.byKey(const ValueKey('strategy-next-details'));
    await tester.ensureVisible(details);
    await tester.tap(details);
    await tester.pumpAndSettle();
    expect(find.text('Card details'), findsOneWidget);
    expect(find.text('REWARD RATES'), findsOneWidget);
    expect(find.text('BENEFITS'), findsOneWidget);

    await tester.tap(find.byTooltip('Close card details'));
    await tester.pumpAndSettle();

    final search = find.byKey(const ValueKey('card-search-field'));
    await tester.ensureVisible(search);
    await tester.enterText(search, 'citi');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('search-result-citi-strata')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('strategy-clear-search')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('search-result-citi-strata')),
      findsNothing,
    );

    final freedomComparison = find.byKey(
      const ValueKey('strategy-comparison-freedom-flex'),
    );
    final sapphireComparison = find.byKey(
      const ValueKey('strategy-comparison-sapphire-preferred'),
    );
    await tester.ensureVisible(freedomComparison);
    expect(freedomComparison, findsOneWidget);
    expect(sapphireComparison, findsOneWidget);
    expect(
      tester.getTopLeft(freedomComparison).dy,
      lessThan(tester.getTopLeft(sapphireComparison).dy),
    );

    appRouter.go('/home');
    await tester.pumpAndSettle();
    expect(
      find.text('Review Freedom Flex', skipOffstage: false),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('strategy shows an owned substitute without recommending one', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final base = createDemoAppData();
    final discover = demoCatalog
        .firstWhere((card) => card.id == 'discover-it')
        .copyWith(isActive: true);
    final data = base.copyWith(
      wallet: [...base.wallet, discover],
      playbook: const PlaybookAssignment(
        code: 'S04',
        title: 'Flexible travel foundation',
        ecosystem: 'Chase',
        steps: [
          PlaybookStep(
            name: 'Freedom Unlimited',
            use: 'Everyday catch-all',
            status: 'have',
            coveredBy: 'Freedom Unlimited',
          ),
          PlaybookStep(
            name: 'Freedom Flex',
            use: 'Rotating categories',
            status: 'have',
            coveredBy: 'Discover it Cash Back',
            note:
                'Keep your Discover it Cash Back; it covers the Freedom Flex role in this strategy.',
          ),
          PlaybookStep(
            name: 'Sapphire Preferred',
            use: 'Transfer partners',
            status: 'next',
          ),
        ],
        unused: [],
        alternatives: [],
      ),
    );

    await tester.pumpWidget(
      RevoCredBootstrap(
        config: const AppConfig(useMocks: true),
        repository: MockAppRepository(initialData: data),
        preferences: preferences,
      ),
    );
    appRouter.go('/strategy');
    await tester.pumpAndSettle();

    expect(find.text('2 OF 3 ROLES COVERED'), findsOneWidget);
    expect(find.text('ROLE 2: COVERED BY OWNED CARD'), findsOneWidget);
    expect(find.text('Replacing Freedom Flex'), findsOneWidget);
    expect(find.text('Discover it Cash Back'), findsWidgets);
    expect(
      find.text(
        'Keep this card for the Freedom Flex role. No replacement application is needed.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Consider next: Sapphire Preferred'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('roadmap explains roles and flags excellent-credit later steps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final base = createDemoAppData();
    final quicksilver = CreditCard.fromApiJson({
      'id': '20000000-0000-4000-8000-000000000008',
      'issuer': 'Capital One',
      'network': 'Visa',
      'name': 'Quicksilver',
      'annual_fee_cents': 0,
      'best_use': 'Everyday catch-all cash back.',
      'reward_rates': {'other': 1.5},
      'benefits': [r'$0 annual fee'],
      'minimum_credit_tier': 'excellent',
    });
    final data = base.copyWith(
      wallet: const [],
      catalog: [quicksilver],
      playbook: const PlaybookAssignment(
        code: 'S01',
        title: 'Build credit with simple cash back',
        ecosystem: 'Capital One',
        steps: [
          PlaybookStep(
            name: 'Savor for Students',
            use: 'Dining and groceries while you build credit.',
            status: 'next',
          ),
          PlaybookStep(
            name: 'Quicksilver',
            use: 'Everyday catch-all cash back.',
            status: 'later',
            timing:
                'Wait approximately 3-6 months after the previous application',
            timingNote:
                'Planning estimate only. Proceed only if issuer rules permit.',
          ),
        ],
        unused: [],
        alternatives: [],
      ),
    );

    await tester.pumpWidget(
      RevoCredBootstrap(
        config: const AppConfig(useMocks: true),
        repository: MockAppRepository(initialData: data),
        preferences: preferences,
      ),
    );
    appRouter.go('/strategy');
    await tester.pumpAndSettle();

    expect(
      find.textContaining('already fill roles', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('Requires excellent credit'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
