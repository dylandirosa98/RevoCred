import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/app.dart';
import 'package:revocred_flutter/core/config/app_config.dart';
import 'package:revocred_flutter/core/data/mock_app_repository.dart';
import 'package:revocred_flutter/core/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(r'onboarding uses names, wallet size, and $50 spend steps', (
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

    expect(find.text('18+ and currently a student'), findsNothing);
    expect(find.byKey(const ValueKey('onboarding-first-name')), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-last-name')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('questionnaire-next')),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byKey(const ValueKey('onboarding-first-name')),
      'Javed',
    );
    await tester.enterText(
      find.byKey(const ValueKey('onboarding-last-name')),
      'Khan',
    );
    await tester.tap(find.text('Adult and building a foundation'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('questionnaire-next')));
    await tester.pumpAndSettle();

    final noCards = find.text('I do not have any credit cards');
    await tester.ensureVisible(noCards);
    await tester.tap(noCards);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('questionnaire-next')));
    await tester.pumpAndSettle();

    expect(
      find.text('How many cards would you like to ideally stay within?'),
      findsOneWidget,
    );
    expect(find.text('What annual fee feels reasonable?'), findsNothing);
    for (final choice in ['1–2 cards', '2–4 cards', '4+ cards']) {
      expect(find.text(choice), findsOneWidget);
    }
    expect(find.text('2–3 cards'), findsNothing);
    expect(find.text('3–4 cards'), findsNothing);
    await tester.tap(find.text('2–4 cards'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('questionnaire-next')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Domestic and international'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('questionnaire-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Good'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('questionnaire-next')));
    await tester.pumpAndSettle();

    final dining = find.descendant(
      of: find.byKey(const ValueKey('spend-dining')),
      matching: find.byType(Slider),
    );
    expect(dining, findsOneWidget);
    final slider = tester.widget<Slider>(dining);
    expect(slider.divisions, 100);
    slider.onChanged!(126);
    await tester.pump();
    expect(find.text(r'$150'), findsOneWidget);
    expect(find.text(r'$0'), findsWidgets);
    expect(find.text(r'$2,500'), findsWidgets);
    expect(find.text(r'$5,000+'), findsWidgets);
  });
}
