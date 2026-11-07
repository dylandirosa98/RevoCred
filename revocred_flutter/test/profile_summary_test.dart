import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/app.dart';
import 'package:revocred_flutter/core/config/app_config.dart';
import 'package:revocred_flutter/core/data/mock_app_repository.dart';
import 'package:revocred_flutter/core/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('account summary rows are centered on narrow and wide screens', (
    tester,
  ) async {
    for (final width in [390.0, 900.0]) {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      appRouter.go('/profile');
      await tester.pumpWidget(
        RevoCredBootstrap(
          config: const AppConfig(useMocks: true),
          repository: MockAppRepository(),
          preferences: preferences,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ACCOUNT SUMMARY'), findsOneWidget);
      for (final text in ['Email', 'demo@revocred.local', 'Goal', 'Setup']) {
        final widget = tester.widget<Text>(find.text(text).first);
        expect(
          widget.textAlign,
          TextAlign.center,
          reason: '$text should be centered at ${width.toInt()}px',
        );
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('profile links to a credit card expert', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    appRouter.go('/profile');
    await tester.pumpWidget(
      RevoCredBootstrap(
        config: const AppConfig(useMocks: true),
        repository: MockAppRepository(),
        preferences: preferences,
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Talk to a credit card expert'));
    expect(find.text('Talk to a credit card expert'), findsOneWidget);
    expect(find.byKey(const ValueKey('expert-link')), findsOneWidget);
    expect(find.text('thecreditcardstrategist.com'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
