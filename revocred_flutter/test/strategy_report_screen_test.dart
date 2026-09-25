import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/app.dart';
import 'package:revocred_flutter/core/config/app_config.dart';
import 'package:revocred_flutter/core/data/mock_app_repository.dart';
import 'package:revocred_flutter/core/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('strategy report presents the reusable personalized format', (
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
    appRouter.go('/strategy-report');
    await tester.pumpAndSettle();

    expect(find.text('Your Personalized Credit Card Strategy'), findsOneWidget);
    expect(find.byTooltip('Back to settings'), findsOneWidget);
    expect(find.byKey(const ValueKey('strategy-report')), findsOneWidget);
    expect(find.text('YOUR CREDIT PROFILE'), findsOneWidget);
    expect(find.text('CARDS YOU ALREADY HAVE'), findsOneWidget);
    expect(find.text('RECOMMENDED STRATEGY'), findsOneWidget);
    expect(find.text('HOW TO USE YOUR WALLET'), findsOneWidget);
    expect(find.text('APPLICATION ROADMAP'), findsOneWidget);
    expect(find.text('CURRENT WALLET ANNUAL VALUE'), findsOneWidget);
    expect(find.text('IMPORTANT NOTES'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('download-strategy-report')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('share-strategy-report')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile settings links to the saved strategy report', (
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

    final reportLink = find.byKey(const ValueKey('view-strategy-report')).last;
    final link = tester.widget<InkWell>(reportLink);
    link.onTap!();
    await tester.pumpAndSettle();

    expect(
      appRouter.routeInformationProvider.value.uri.path,
      '/strategy-report',
    );
    expect(find.byKey(const ValueKey('strategy-report')), findsOneWidget);
  });
}
