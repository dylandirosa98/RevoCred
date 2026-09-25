import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/app.dart';
import 'package:revocred_flutter/core/config/app_config.dart';
import 'package:revocred_flutter/core/data/mock_app_repository.dart';
import 'package:revocred_flutter/core/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    expect(tester.takeException(), isNull);
  });
}
