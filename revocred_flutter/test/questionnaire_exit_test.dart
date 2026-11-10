import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/app.dart';
import 'package:revocred_flutter/core/config/app_config.dart';
import 'package:revocred_flutter/core/data/mock_app_repository.dart';
import 'package:revocred_flutter/core/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The questionnaire is opened with `go`, so there is no page to pop back to.
/// It must still offer a way out instead of trapping the member.
void main() {
  Future<void> launch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
  }

  String location() => appRouter.routerDelegate.currentConfiguration.uri.path;

  testWidgets('closing the questionnaire from Profile returns to Profile', (
    tester,
  ) async {
    await launch(tester);
    appRouter.go('/questionnaire?from=profile');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('questionnaire-close')));
    await tester.pumpAndSettle();
    expect(location(), '/profile');
  });

  testWidgets('closing it from elsewhere returns a member to Home', (
    tester,
  ) async {
    await launch(tester);
    appRouter.go('/questionnaire');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('questionnaire-close')));
    await tester.pumpAndSettle();
    expect(location(), '/home');
  });
}
