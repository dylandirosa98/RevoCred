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
    await tester.tap(find.byKey(const ValueKey('purchase-caps-available')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('decision-category-dining')));
    await tester.pumpAndSettle();
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
          of: find.byKey(const ValueKey('decision-recommended-card')),
          matching: find.text('1.5% cash back'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
