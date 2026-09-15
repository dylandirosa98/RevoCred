import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/app.dart';
import 'package:revocred_flutter/core/config/app_config.dart';
import 'package:revocred_flutter/core/data/mock_app_repository.dart';
import 'package:revocred_flutter/core/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Decision Flow light is the default interface', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      RevoCredBootstrap(
        config: const AppConfig(useMocks: true),
        repository: MockAppRepository(),
        preferences: preferences,
      ),
    );
    appRouter.go('/home');
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.brightness, Brightness.light);
    expect(app.theme?.scaffoldBackgroundColor, const Color(0xFFF5F5F3));
    expect(find.byKey(const ValueKey('decision-flow-home')), findsOneWidget);
  });

  testWidgets('appearance switches only between Decision Flow light and dark', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      RevoCredBootstrap(
        config: const AppConfig(useMocks: true),
        repository: MockAppRepository(),
        preferences: preferences,
      ),
    );
    appRouter.go('/profile');
    await tester.pumpAndSettle();

    final light = find.byKey(const ValueKey('theme-option-decisionFlow'));
    final dark = find.byKey(const ValueKey('theme-option-decisionFlowDark'));
    expect(light, findsOneWidget);
    expect(dark, findsOneWidget);
    expect(find.byKey(const ValueKey('theme-option-clear')), findsNothing);
    expect(
      find.byKey(const ValueKey('theme-option-walletStudio')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('theme-comparison-launcher')),
      findsNothing,
    );

    await tester.ensureVisible(dark);
    await tester.tap(dark);
    await tester.pumpAndSettle();
    var app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.brightness, Brightness.dark);
    expect(app.theme?.scaffoldBackgroundColor, const Color(0xFF0D0C11));
    expect(preferences.getString('app_theme_variant'), 'decisionFlowDark');
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(light);
    await tester.tap(light);
    await tester.pumpAndSettle();
    app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.brightness, Brightness.light);
    expect(preferences.getString('app_theme_variant'), 'decisionFlow');
  });

  testWidgets('Decision Flow changes recommendations by purchase category', (
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
    appRouter.go('/home');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('decision-flow-home')), findsOneWidget);
    expect(find.text('Make the next swipe count.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('decision-category-transit')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('decision-category-online-shopping')),
      findsOneWidget,
    );
    final card = find.byKey(const ValueKey('decision-recommended-card'));
    expect(card, findsOneWidget);
    final size = tester.getSize(card);
    expect(size.width / size.height, closeTo(1.586, .001));

    await tester.tap(find.byKey(const ValueKey('decision-category-travel')));
    await tester.pumpAndSettle();
    expect(find.text('Best for Travel'), findsOneWidget);
    expect(find.text('Why this card?'), findsOneWidget);
    expect(find.text('Ask REVO'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('decision-more-categories')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('decision-more-category-grid')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('decision-more-category-rent')));
    await tester.pumpAndSettle();
    expect(find.text('Best for Rent'), findsOneWidget);
    expect(find.text('More: Rent'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
