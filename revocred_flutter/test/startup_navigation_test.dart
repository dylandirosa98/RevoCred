import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/app.dart';
import 'package:revocred_flutter/core/config/app_config.dart';
import 'package:revocred_flutter/core/data/mock_app_repository.dart';
import 'package:revocred_flutter/core/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('starts in demo home and navigates to all primary destinations', (
    tester,
  ) async {
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

    expect(find.textContaining('The right card.'), findsOneWidget);
    final enterDemo = find.byKey(const ValueKey('existing-account-action'));
    await tester.ensureVisible(enterDemo);
    await tester.tap(enterDemo);
    await tester.pumpAndSettle();

    expect(find.text('Make the next swipe count.'), findsOneWidget);
    expect(find.byKey(const ValueKey('decision-flow-home')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-home-selected')), findsOneWidget);
    final navigationTheme = Theme.of(
      tester.element(find.byType(NavigationBar)),
    ).navigationBarTheme;
    expect(
      navigationTheme.iconTheme?.resolve({WidgetState.selected})?.color,
      const Color(0xFF6648D8),
    );

    await tester.tap(find.text('Cards'));
    await tester.pumpAndSettle();
    expect(find.text('Your card setup'), findsOneWidget);

    await tester.tap(find.text('Strategy'));
    await tester.pumpAndSettle();
    expect(find.text('YOUR STRATEGY ROADMAP'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-ask-revo-idle')));
    await tester.pumpAndSettle();
    expect(find.textContaining('does not pick cards'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Alex Morgan'), findsWidgets);
    expect(
      find.byKey(const ValueKey('questionnaire-launcher')),
      findsOneWidget,
    );
  });
}
