import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:revocred_flutter/app.dart';
import 'package:revocred_flutter/core/config/app_config.dart';
import 'package:revocred_flutter/core/data/mock_app_repository.dart';
import 'package:revocred_flutter/core/router/app_router.dart';
import 'package:revocred_flutter/features/profile/presentation/profile_screen.dart';

/// "Tune your recommendation" lives inside the stateful shell. Pushing a
/// top-level route from a shell branch must still move the URL, otherwise the
/// address bar, reload and back button all describe the wrong screen.
void main() {
  testWidgets('tuning the recommendation puts the questionnaire in the URL', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 950);
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
    expect(appRouter.routeInformationProvider.value.uri.path, '/profile');

    await tester.ensureVisible(
      find.byKey(const ValueKey('questionnaire-launcher')),
    );
    await tester.tap(find.byKey(const ValueKey('questionnaire-launcher')));
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print(
      'DEBUG path=${appRouter.routeInformationProvider.value.uri.path} '
      'launcherPresent=${find.byKey(const ValueKey('questionnaire-launcher')).evaluate().isNotEmpty} '
      'questionText=${find.text('What adult life stage fits best?').evaluate().isNotEmpty}',
    );

    expect(
      appRouter.routeInformationProvider.value.uri.path,
      '/questionnaire',
      reason: 'the URL must follow the pushed questionnaire',
    );
    expect(find.byType(ProfileScreen), findsNothing);
  });
}
