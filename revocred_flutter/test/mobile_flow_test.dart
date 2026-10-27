import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/app.dart';
import 'package:revocred_flutter/core/config/app_config.dart';
import 'package:revocred_flutter/core/data/mock_app_repository.dart';
import 'package:revocred_flutter/core/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('mobile routes fit common phone widths in light and dark', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(
      RevoCredBootstrap(
        config: const AppConfig(useMocks: true),
        repository: MockAppRepository(),
        preferences: preferences,
      ),
    );
    await tester.pumpAndSettle();

    const routes = [
      '/welcome',
      '/home',
      '/cards',
      '/strategy',
      '/revo',
      '/profile',
      '/questionnaire',
      '/strategy-report',
    ];
    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      tester.view.physicalSize = Size(width, 844);
      await tester.pumpAndSettle();
      for (final route in routes) {
        appRouter.go(route);
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '$route overflowed at ${width.toInt()}px',
        );
      }
    }

    tester.view.physicalSize = const Size(320, 844);
    for (final variant in const ['decisionFlowDark']) {
      appRouter.go('/profile');
      await tester.pumpAndSettle();
      final option = find.byKey(ValueKey('theme-option-$variant'));
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pumpAndSettle();
      for (final route in routes) {
        appRouter.go(route);
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '$route overflowed in $variant at 320px',
        );
      }
    }
  });

  testWidgets(
    'welcome questionnaire flow completes and opens strategy report',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      appRouter.go('/welcome');

      await tester.pumpWidget(
        RevoCredBootstrap(
          config: const AppConfig(useMocks: true),
          repository: MockAppRepository(),
          preferences: preferences,
        ),
      );
      await tester.pumpAndSettle();

      final start = find.byKey(const ValueKey('build-strategy-action'));
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pumpAndSettle();
      expect(
        appRouter.routeInformationProvider.value.uri.path,
        '/questionnaire',
      );

      for (var step = 0; step < 7; step++) {
        if (step == 0) {
          await tester.enterText(
            find.byKey(const ValueKey('onboarding-first-name')),
            'Taylor',
          );
          await tester.enterText(
            find.byKey(const ValueKey('onboarding-last-name')),
            'Morgan',
          );
        }
        final choice = switch (step) {
          0 => 'Adult and building a foundation',
          1 => 'I do not have any credit cards',
          2 => '2–4 cards',
          3 => 'Domestic and international',
          4 => 'Good',
          6 => 'Flexible travel points',
          _ => null,
        };
        if (choice != null) {
          final option = find.text(choice);
          await tester.ensureVisible(option);
          await tester.tap(option);
          await tester.pumpAndSettle();
        }
        if (step == 5) {
          final dining = find.descendant(
            of: find.byKey(const ValueKey('spend-dining')),
            matching: find.byType(Slider),
          );
          tester.widget<Slider>(dining).onChanged!(350);
          await tester.pump();
          expect(find.text(r'$350'), findsOneWidget);
        }
        await tester.tap(find.byKey(const ValueKey('questionnaire-next')));
        await tester.pumpAndSettle();
      }
      expect(
        appRouter.routeInformationProvider.value.uri.path,
        '/strategy-report',
      );
      expect(find.byKey(const ValueKey('strategy-report')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('strategy-roadmap-view')),
        findsOneWidget,
      );
    },
  );

  testWidgets('onboarding lists catalog cards before any search is typed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    appRouter.go('/questionnaire');

    await tester.pumpWidget(
      RevoCredBootstrap(
        config: const AppConfig(useMocks: true),
        repository: MockAppRepository(),
        preferences: preferences,
      ),
    );
    await tester.pumpAndSettle();

    // A user must be able to say which cards they own without typing a search.
    await tester.tap(find.text('Adult and building a foundation'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('questionnaire-next')));
    await tester.pumpAndSettle();
    final search = find.byKey(const ValueKey('questionnaire-card-search'));
    expect(search, findsOneWidget);
    expect(
      tester.widget<TextField>(search).controller?.text ?? '',
      isEmpty,
      reason: 'the search box must start empty for this test to be meaningful',
    );
    final cards = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .where((tile) => tile.title is Text)
        .map((tile) => (tile.title! as Text).data)
        .toList();
    expect(
      cards.length,
      greaterThan(3),
      reason: 'the owned-card step must show the catalog, not an empty list',
    );
    expect(find.text('I do not have any credit cards'), findsOneWidget);
  });

  testWidgets('REVO remains usable when the mobile keyboard opens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      RevoCredBootstrap(
        config: const AppConfig(useMocks: true),
        repository: MockAppRepository(),
        preferences: preferences,
      ),
    );
    appRouter.go('/revo');
    await tester.pumpAndSettle();

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('revo-composer')), findsOneWidget);
    expect(find.byKey(const ValueKey('revo-send')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('REVO shows one thinking state per request', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      RevoCredBootstrap(
        config: const AppConfig(useMocks: true),
        repository: MockAppRepository(),
        preferences: preferences,
      ),
    );
    appRouter.go('/revo');
    await tester.pumpAndSettle();

    await tester.tap(find.text('What card should I use for groceries?'));
    await tester.pump();

    expect(find.text('REVO is thinking', skipOffstage: false), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('primary routes support larger mobile text', (tester) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      RevoCredBootstrap(
        config: const AppConfig(useMocks: true),
        repository: MockAppRepository(),
        preferences: preferences,
      ),
    );
    await tester.pumpAndSettle();

    for (final route in const [
      '/welcome',
      '/home',
      '/cards',
      '/strategy',
      '/revo',
      '/profile',
      '/questionnaire',
      '/strategy-report',
    ]) {
      appRouter.go(route);
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: '$route overflowed at 1.6x text scaling',
      );
    }
  });
}
