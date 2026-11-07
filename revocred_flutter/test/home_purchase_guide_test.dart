import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/app.dart';
import 'package:revocred_flutter/core/config/app_config.dart';
import 'package:revocred_flutter/core/data/demo_seed.dart';
import 'package:revocred_flutter/core/data/mock_app_repository.dart';
import 'package:revocred_flutter/core/models/app_models.dart';
import 'package:revocred_flutter/core/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'Rent shows the owned base-rate card with a small eligibility note',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final double = CreditCard.fromApiJson({
        'id': 'double',
        'name': 'Double Cash',
        'issuer': 'Citi',
        'reward_rates': {'other': 2},
        'rewards_type': 'cash_back',
      }, isActive: true);
      final discover = CreditCard.fromApiJson({
        'id': 'discover',
        'name': 'Discover it Cash Back',
        'issuer': 'Discover',
        'reward_rates': {'other': 1},
        'rewards_type': 'cash_back',
      }, isActive: true);
      Map<String, dynamic> option(String id, String name, int rate) => {
        'card_id': id,
        'card_name': name,
        'rate': rate,
        'earn_label': '$rate% cash back',
        'reason': 'Rent must qualify as a purchase. Check payment fees first.',
        'conditions': [
          'Cash advances and ineligible payments do not earn purchase rewards.',
        ],
      };
      final guide = PurchaseGuide.fromJson({
        'categories': [
          {
            'id': 'rent',
            'label': 'Rent',
            'options': [],
            'tied': true,
            'fallback_options': [
              option('removed-a', 'Removed card A', 99),
              option('removed-b', 'Removed card B', 99),
              option('double', 'Double Cash', 2),
              option('discover', 'Discover it Cash Back', 1),
            ],
          },
        ],
      });
      final data = createDemoAppData().copyWith(
        wallet: [double, discover],
        purchaseGuide: guide,
      );
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      appRouter.go('/home');
      await tester.pumpWidget(
        RevoCredBootstrap(
          config: const AppConfig(useMocks: true),
          repository: MockAppRepository(initialData: data),
          preferences: prefs,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('decision-more-categories')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('decision-more-category-rent')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        find.byKey(const ValueKey('decision-card-double')),
        findsOneWidget,
      );
      expect(find.text('Base-rate option for Rent'), findsOneWidget);
      expect(find.text('2% cash back before fees · Rent'), findsOneWidget);
      expect(
        find.text('Rent must qualify as a purchase. Check payment fees first.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.text(
                'Rent must qualify as a purchase. Check payment fees first.',
              ),
            )
            .maxLines,
        3,
        reason: 'Do not inherit a single-line ellipsis for the rent warning.',
      );
      expect(find.textContaining('No supported earning rule'), findsNothing);
      expect(find.textContaining('Cash advances'), findsNothing);
      expect(find.textContaining('Removed card'), findsNothing);
      final why = find.text('Why this card?');
      await tester.ensureVisible(why);
      await tester.tap(why);
      await tester.pumpAndSettle();
      expect(find.textContaining('Cash advances'), findsOneWidget);
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      await _openComparison(tester);
      expect(find.text('BASE-RATE OPTIONS — BEFORE FEES'), findsOneWidget);
      expect(find.text('Conditional Double Cash'), findsOneWidget);
      expect(find.text('1. Double Cash'), findsNothing);
      expect(find.textContaining('No supported earning rule'), findsNothing);
      expect(find.textContaining('Removed card'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('category taps update Use now without opening comparison', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    appRouter.go('/home');
    await tester.pumpWidget(
      RevoCredBootstrap(
        config: const AppConfig(useMocks: true),
        repository: MockAppRepository(),
        preferences: prefs,
      ),
    );
    await tester.pumpAndSettle();
    for (final (id, label) in [
      ('groceries', 'Groceries'),
      ('gas', 'Gas'),
      ('online-shopping', 'Online shopping'),
      ('dining', 'Dining'),
      ('travel', 'Travel'),
    ]) {
      await tester.tap(find.byKey(ValueKey('decision-category-$id')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Best known for $label'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('decision-recommended-card')),
        findsOneWidget,
      );
    }
    await _openComparison(tester);
    expect(find.text('Best cards for Travel'), findsOneWidget);
    expect(find.text('How are you booking?'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cap eligibility is scoped to the selected purchase category', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    appRouter.go('/home');
    await tester.pumpWidget(
      RevoCredBootstrap(
        config: const AppConfig(useMocks: true),
        repository: MockAppRepository(),
        preferences: prefs,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('decision-category-groceries')));
    await tester.pumpAndSettle();
    await _openComparison(tester);
    await tester.tap(find.byKey(const ValueKey('purchase-caps-available')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('decision-category-dining')),
    );
    await tester.tap(find.byKey(const ValueKey('decision-category-dining')));
    await tester.pumpAndSettle();
    await _openComparison(tester);
    expect(
      find.text('1. Amex Gold'),
      findsOneWidget,
      reason:
          'Exhausting the grocery cap must not exhaust the separate dining cap.',
    );
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('purchase-caps-available')),
          )
          .value,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Home uses server wallet ranking and category earn label, never global best multiplier',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      CreditCard card(String id, String name, Map<String, num> rates) =>
          CreditCard.fromApiJson({
            'id': id,
            'name': name,
            'issuer': 'Test',
            'reward_rates': rates,
          }, isActive: true);
      final gold = card('gold', 'Amex Gold', {'other': 1, 'dining': 4});
      final quick = card('quick', 'Quicksilver', {'other': 1.5});
      final unowned = card('unowned', 'Not owned 99x', {'other': 99});
      final guide = PurchaseGuide.fromJson({
        'categories': [
          {
            'id': 'dining',
            'label': 'Dining',
            'options': [
              {
                'card_id': 'gold',
                'card_name': 'Amex Gold',
                'rate': 4,
                'earn_label': '4x eligible dining',
                'reason': 'Eligible restaurants',
                'conditions': [],
              },
              {
                'card_id': 'quick',
                'card_name': 'Quicksilver',
                'rate': 1.5,
                'earn_label': '1.5% cash back',
                'reason': 'Base rate',
                'conditions': [],
              },
            ],
          },
          {
            'id': 'online-shopping',
            'label': 'Online shopping',
            'options': [
              {
                'card_id': 'quick',
                'card_name': 'Quicksilver',
                'rate': 1.5,
                'earn_label': '1.5% cash back',
                'reason': 'Base rate for this purchase',
                'conditions': [],
              },
              {
                'card_id': 'gold',
                'card_name': 'Amex Gold',
                'rate': 1,
                'earn_label': '1x other purchases',
                'reason': 'Base rate',
                'conditions': [],
              },
            ],
          },
        ],
        'settings': {'travel_mode': 'general', 'caps_available': true},
      });
      final data = createDemoAppData().copyWith(
        wallet: [gold, quick],
        catalog: [gold, quick, unowned],
        purchaseGuide: guide,
      );
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      appRouter.go('/home');
      await tester.pumpWidget(
        RevoCredBootstrap(
          config: const AppConfig(useMocks: true),
          repository: MockAppRepository(initialData: data),
          preferences: prefs,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('decision-category-online-shopping')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byKey(const ValueKey('decision-card-quick')), findsOneWidget);
      await _openComparison(tester);
      final first = find.byKey(const ValueKey('category-card-quick'));
      final second = find.byKey(const ValueKey('category-card-gold'));
      expect(first, findsOneWidget);
      expect(second, findsOneWidget);
      expect(
        tester.getTopLeft(first).dy,
        lessThan(tester.getTopLeft(second).dy),
      );
      expect(find.byKey(const ValueKey('category-card-unowned')), findsNothing);
      expect(find.text('Apply on Test'), findsNothing);
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('decision-card-quick')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('decision-purchase-summary')),
          matching: find.text('1.5% cash back · Online shopping'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _openComparison(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('decision-comparison-options'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}
