import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/app.dart';
import 'package:revocred_flutter/core/config/app_config.dart';
import 'package:revocred_flutter/core/data/app_repository.dart';
import 'package:revocred_flutter/core/data/demo_seed.dart';
import 'package:revocred_flutter/core/data/mock_app_repository.dart';
import 'package:revocred_flutter/core/models/app_models.dart';
import 'package:revocred_flutter/core/router/app_router.dart';
import 'package:revocred_flutter/core/state/app_controller.dart';
import 'package:revocred_flutter/core/theme/app_theme.dart';
import 'package:revocred_flutter/features/auth/presentation/auth_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('confirmation-required signup stays outside the account', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = _ConfirmationRepository();
    appRouter.go('/welcome?save=true');
    await tester.pumpWidget(
      RevoCredBootstrap(
        config: const AppConfig(useMocks: false),
        repository: repository,
        preferences: preferences,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('auth-notifications-opt-in')),
          )
          .value,
      isFalse,
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-name')),
      'Test Member',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      'member@example.test',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password')),
      'Long-Test-Password-123!',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('auth-submit')));
    await tester.tap(find.byKey(const ValueKey('auth-submit')));
    await tester.pumpAndSettle();
    expect(
      find.text('Check your email to confirm the account, then sign in.'),
      findsOneWidget,
    );
    expect(repository.recordedNotificationsOptIn, isFalse);
    appRouter.go('/home');
    await tester.pumpAndSettle();
    expect(appRouter.routeInformationProvider.value.uri.path, '/welcome');
  });
  testWidgets(
    'restored account deep link waits for bootstrap and logout redirects',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = _RestoringRepository();
      appRouter.go('/home');
      await tester.pumpWidget(
        RevoCredBootstrap(
          config: const AppConfig(useMocks: false),
          repository: repository,
          preferences: preferences,
        ),
      );
      await tester.pump();
      expect(find.text('Building your strategy'), findsWidgets);
      expect(tester.takeException(), isNull);
      repository.pending.complete(createDemoAppData());
      await tester.pumpAndSettle();
      expect(appRouter.routeInformationProvider.value.uri.path, '/home');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RevoCredApp)),
      );
      await container.read(appControllerProvider.notifier).signOut();
      await tester.pumpAndSettle();
      expect(appRouter.routeInformationProvider.value.uri.path, '/welcome');
      expect(find.text('Building your strategy'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('save-plan screen opens create-account and sign-in forms', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(const AppConfig(useMocks: false)),
        ],
        child: MaterialApp(
          theme: AppTheme.decisionFlow,
          home: const AuthScreen(savePlan: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Build your strategy'), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-email')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-password')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('auth-back')));
    await tester.pumpAndSettle();

    final signIn = find.byKey(const ValueKey('existing-account-action'));
    await tester.ensureVisible(signIn);
    await tester.tap(signIn);
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('confirmed account without answers is routed to onboarding', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = _AuthenticatingRepository();
    appRouter.go('/welcome');

    await tester.pumpWidget(
      RevoCredBootstrap(
        config: const AppConfig(useMocks: false),
        repository: repository,
        preferences: preferences,
      ),
    );
    await tester.pumpAndSettle();

    final signIn = find.byKey(const ValueKey('existing-account-action'));
    await tester.ensureVisible(signIn);
    await tester.tap(signIn);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      'person@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password')),
      'password123',
    );
    await tester.tap(find.byKey(const ValueKey('auth-submit')));
    await tester.pumpAndSettle();

    expect(find.text('What adult life stage fits best?'), findsOneWidget);
    expect(appRouter.routeInformationProvider.value.uri.path, '/questionnaire');
  });

  testWidgets('signed-out real mode cannot open profile', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    appRouter.go('/profile');

    await tester.pumpWidget(
      RevoCredBootstrap(
        config: const AppConfig(useMocks: false),
        repository: _GuestRepository(),
        preferences: preferences,
      ),
    );
    await tester.pumpAndSettle();

    expect(appRouter.routeInformationProvider.value.uri.path, '/welcome');
    for (final path in [
      '/home',
      '/cards',
      '/strategy',
      '/revo',
      '/profile',
      '/account',
      '/reset-password',
      '/strategy-report',
    ]) {
      appRouter.go(path);
      await tester.pumpAndSettle();
      expect(
        appRouter.routeInformationProvider.value.uri.path,
        '/welcome',
        reason: path,
      );
      expect(tester.takeException(), isNull, reason: path);
    }
    appRouter.go('/welcome');
    await tester.pumpAndSettle();
    expect(appRouter.routeInformationProvider.value.uri.path, '/welcome');
  });

  testWidgets('logged-out real mode cannot use the account home', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    appRouter.go('/home');

    await tester.pumpWidget(
      RevoCredBootstrap(
        config: const AppConfig(useMocks: false),
        repository: _GuestRepository(),
        preferences: preferences,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Make the next swipe count.'), findsNothing);
    expect(appRouter.routeInformationProvider.value.uri.path, '/welcome');
  });

  testWidgets(
    'guest report Continue opens authentication, never account home',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      appRouter.go('/welcome');
      await tester.pumpWidget(
        RevoCredBootstrap(
          config: const AppConfig(useMocks: false),
          repository: _GuestRepository(),
          preferences: preferences,
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AuthScreen)),
      );
      await container
          .read(appControllerProvider.notifier)
          .completeQuestionnaire(
            const QuestionnaireAnswers(
              lifeStage: 'adult',
              existingCardIds: [],
              feeTolerance: 'none',
              travelScope: 'none',
              creditTier: 'good',
              monthlySpend: {'other': 200},
              rewardsGoal: 'cash_back',
              idealCardCount: '2-3',
            ),
          );
      appRouter.go('/strategy-report');
      await tester.pumpAndSettle();
      expect(find.byTooltip('Back to settings'), findsNothing);
      expect(find.text('Finish account'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('finish-account-bottom')),
        findsOneWidget,
      );
      expect(find.text('Your personal strategy preview'), findsNothing);
      expect(find.text('Create an account to save my plan'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('continue-strategy-report')));
      await tester.pumpAndSettle();
      expect(
        appRouter.routeInformationProvider.value.uri.toString(),
        '/welcome?save=true&from=report',
      );
      expect(find.byKey(const ValueKey('auth-submit')), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(
        appRouter.routeInformationProvider.value.uri.path,
        '/strategy-report',
      );
      expect(
        find.byKey(const ValueKey('continue-strategy-report')),
        findsOneWidget,
      );
    },
  );
}

class _GuestRepository extends MockAppRepository {
  @override
  bool get isAuthenticated => false;

  @override
  Future<AppData> previewQuestionnaire(QuestionnaireAnswers answers) async =>
      createDemoAppData().copyWith(isPersonalPreview: true);
}

class _RestoringRepository extends _AuthenticatingRepository {
  _RestoringRepository() {
    authenticated = true;
  }
  final pending = Completer<AppData>();
  @override
  Future<AppData> loadAppData() => pending.future;
}

class _ConfirmationRepository extends _GuestRepository {
  bool? recordedNotificationsOptIn;
  @override
  Future<AuthResult> signUp(
    String email,
    String password, {
    String displayName = '',
    bool notificationsOptIn = false,
  }) async {
    recordedNotificationsOptIn = notificationsOptIn;
    return const AuthResult(
      success: true,
      message: 'Check your email to confirm the account, then sign in.',
    );
  }
}

class _AuthenticatingRepository extends MockAppRepository {
  bool authenticated = false;

  @override
  bool get isAuthenticated => authenticated;

  @override
  Future<AuthResult> signIn(String email, String password) async {
    authenticated = true;
    return const AuthResult(success: true);
  }

  @override
  Future<AuthResult> signUp(
    String email,
    String password, {
    String displayName = '',
    bool notificationsOptIn = false,
  }) => signIn(email, password);

  @override
  Future<AppData> loadAppData() async => createDemoAppData();

  @override
  Future<void> signOut() async => authenticated = false;

  @override
  Future<void> addCard(String cardId) async {}

  @override
  Future<void> addCustomCard(CustomCardDraft card) async {}

  @override
  Future<void> removeCard(String walletCardId) async {}

  @override
  Future<ChatMessage> sendMessage(
    String prompt, {
    String? aiConsentVersion,
  }) async => ChatMessage(
    id: 'reply',
    role: MessageRole.assistant,
    content: 'Reply',
    createdAt: DateTime(2026),
  );

  @override
  Future<DemoRecommendation?> saveQuestionnaire(
    QuestionnaireAnswers answers,
  ) async => null;

  @override
  Future<void> switchStrategy(String code) async {}
}
