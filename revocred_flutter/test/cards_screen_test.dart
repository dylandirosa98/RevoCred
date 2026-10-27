import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/app.dart';
import 'package:revocred_flutter/core/config/app_config.dart';
import 'package:revocred_flutter/core/data/mock_app_repository.dart';
import 'package:revocred_flutter/core/models/app_models.dart';
import 'package:revocred_flutter/core/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('wallet shows full selected-card details without coverage', (
    tester,
  ) async {
    await _pumpCards(tester, '/cards');

    expect(find.text('Wallet coverage'), findsNothing);
    expect(find.text('REWARD MULTIPLIERS'), findsOneWidget);
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
