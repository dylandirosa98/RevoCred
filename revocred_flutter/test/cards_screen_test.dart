import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/app.dart';
import 'package:revocred_flutter/core/config/app_config.dart';
import 'package:revocred_flutter/core/data/demo_seed.dart';
import 'package:revocred_flutter/core/data/mock_app_repository.dart';
import 'package:revocred_flutter/core/logic/playbook.dart';
import 'package:revocred_flutter/core/models/app_models.dart';
import 'package:revocred_flutter/core/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('top and bottom Add buttons open the same focused picker', (
    tester,
  ) async {
    await _pumpCards(tester, '/cards');
    final top = find.byKey(const ValueKey('add-card-top-button'));
    final bottom = find.byKey(const ValueKey('add-card-button'));
    expect(top, findsOneWidget);
    expect(bottom, findsOneWidget);
    expect(
      tester.getBottomLeft(top).dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('wallet-card-amex-gold')))
            .dy,
      ),
    );
    await tester.tap(top);
    await tester.pumpAndSettle();
    final search = find.byKey(const ValueKey('wallet-card-search'));
    expect(search, findsOneWidget);
    expect(tester.widget<TextField>(search).focusNode?.hasFocus, isTrue);
    await tester.tap(find.byTooltip('Close card search'));
    await tester.pumpAndSettle();
    expect(search, findsNothing);
    await tester.ensureVisible(bottom);
    await tester.tap(bottom);
    await tester.pumpAndSettle();
    expect(search, findsOneWidget);
    expect(tester.widget<TextField>(search).focusNode?.hasFocus, isTrue);
    expect(tester.getRect(search).top, greaterThanOrEqualTo(0));
    expect(tester.getRect(search).bottom, lessThan(844));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'picker leads with the real strategy next card, not a stale target',
    (tester) async {
      final data = createDemoAppData().copyWith(
        playbook: const PlaybookAssignment(
          code: 'S04',
          title: 'Travel foundation',
          ecosystem: 'Chase',
          steps: [
            PlaybookStep(
              name: 'Freedom Unlimited',
              use: 'Everyday',
              status: 'have',
            ),
            PlaybookStep(
              name: 'Sapphire Preferred',
              use: 'Travel',
              status: 'next',
            ),
            PlaybookStep(
              name: 'Freedom Flex',
              use: 'Rotating',
              status: 'later',
            ),
          ],
          unused: [],
          alternatives: [],
        ),
      );
      expect(data.profile.nextTarget, 'Freedom Flex');
      await _pumpCards(
        tester,
        '/cards?search=1',
        repository: MockAppRepository(initialData: data),
      );
      final results = find.byWidgetPredicate(
        (widget) =>
            widget is ListTile &&
            widget.key.toString().contains('wallet-search-result-'),
      );
      expect(
        tester.widget<ListTile>(results.first).key,
        const ValueKey('wallet-search-result-sapphire-preferred'),
      );
      expect(find.text('Next in your strategy'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('wallet-search-result-amex-gold')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('wallet-card-sapphire-preferred')),
        findsNothing,
      );
      final search = find.byKey(const ValueKey('wallet-card-search'));
      await tester.enterText(search, 'Citi');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('wallet-search-result-sapphire-preferred')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('wallet-search-result-citi-strata')),
        findsOneWidget,
      );
      expect(find.text('Next in your strategy'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('wallet-clear-search')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ListTile>(results.first).key,
        const ValueKey('wallet-search-result-sapphire-preferred'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final nextName in ['', 'Amex Gold']) {
    testWidgets(
      'picker does not invent or re-add an owned next card: $nextName',
      (tester) async {
        final data = createDemoAppData().copyWith(
          playbook: PlaybookAssignment(
            code: 'S04',
            title: 'Current plan',
            ecosystem: 'Chase',
            steps: [
              if (nextName.isNotEmpty)
                PlaybookStep(name: nextName, use: '', status: 'next'),
            ],
            unused: const [],
            alternatives: const [],
          ),
        );
        await _pumpCards(
          tester,
          '/cards?search=1',
          repository: MockAppRepository(initialData: data),
        );
        expect(find.text('Next in your strategy'), findsNothing);
        expect(
          find.byKey(const ValueKey('wallet-search-result-amex-gold')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('add picker fits narrow phones and large text', (tester) async {
    await _pumpCards(tester, '/cards?search=1');
    tester.view.physicalSize = const Size(320, 844);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(find.text('Next in your strategy'), findsOneWidget);
    expect(find.byTooltip('Close card search'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet shows full selected-card details without coverage', (
    tester,
  ) async {
    await _pumpCards(tester, '/cards');

    expect(find.text('Wallet coverage'), findsNothing);
    expect(find.text('REWARDS'), findsOneWidget);
    expect(find.text('4x dining'), findsWidgets);
    expect(find.text(r'$325'), findsOneWidget);
    expect(find.text('CREDITS & BENEFITS'), findsOneWidget);
    expect(find.text('Monthly dining credits'), findsOneWidget);

    final askRevo = find.text('Ask REVO about this card');
    await tester.ensureVisible(askRevo);
    expect(askRevo, findsOneWidget);
    expect(find.text('Remove from wallet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search route opens and focuses the search-first add flow', (
    tester,
  ) async {
    await _pumpCards(tester, '/cards?search=1');

    final search = find.byKey(const ValueKey('wallet-card-search'));
    expect(search, findsOneWidget);
    expect(tester.widget<TextField>(search).focusNode?.hasFocus, isTrue);

    await tester.enterText(search, 'citi');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('wallet-search-result-citi-strata')),
      findsOneWidget,
    );
    expect(find.text("Can't find it? Add it manually"), findsOneWidget);

    final result = find.byKey(
      const ValueKey('wallet-search-result-citi-strata'),
    );
    final add = find.descendant(
      of: result,
      matching: find.widgetWithText(FilledButton, 'Add'),
    );
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wallet-card-search')), findsNothing);
    expect(find.text('4 ACTIVE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'wallet search includes identity-only cards from the full index',
    (tester) async {
      await _pumpCards(
        tester,
        '/cards?search=1',
        repository: _ReferenceSearchRepository(),
      );

      final search = find.byKey(const ValueKey('wallet-card-search'));
      await tester.enterText(search, 'Atmos');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final result = find.byKey(
        const ValueKey('wallet-index-result-atmos-ascent'),
      );
      expect(result, findsOneWidget);
      expect(find.text('Atmos Rewards Ascent Visa Signature'), findsOneWidget);

      final add = find.descendant(
        of: result,
        matching: find.widgetWithText(FilledButton, 'Add'),
      );
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Terms for Bank of America Atmos'),
        findsOneWidget,
      );
      expect(
        find.text('Skip - do not use this card in my score'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpCards(
  WidgetTester tester,
  String location, {
  MockAppRepository? repository,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  appRouter.go(location);
  await tester.pumpWidget(
    RevoCredBootstrap(
      config: const AppConfig(useMocks: true),
      repository: repository ?? MockAppRepository(),
      preferences: preferences,
    ),
  );
  await tester.pumpAndSettle();
}

class _ReferenceSearchRepository extends MockAppRepository {
  @override
  Future<List<ReferenceCard>> searchCardIndex(String query) async => const [
    ReferenceCard(
      id: 'atmos-ascent',
      issuer: 'Bank of America',
      name: 'Atmos Rewards Ascent Visa Signature',
      network: 'Visa',
      rewardsType: 'unknown',
      annualFeeCents: 0,
      rewardRates: {},
      termsStatus: 'partial',
      sourceUrl: 'https://www.bankofamerica.com/',
      sourceCapturedOn: '2026-09-30',
    ),
  ];
}
