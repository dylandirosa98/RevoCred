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

  testWidgets('signing out returns to welcome and keeps the guest demo shell', (
    tester,
  ) async {
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

    // A signed-out visitor keeps the demo shell on purpose, so the app must not
    // trap them on an account page after sign-out.
    expect(appRouter.routeInformationProvider.value.uri.path, '/profile');
    appRouter.go('/welcome');
    await tester.pumpAndSettle();
    expect(appRouter.routeInformationProvider.value.uri.path, '/welcome');
  });

  testWidgets('logged-out real mode still shows the demo home', (tester) async {
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

    expect(find.text('Make the next swipe count.'), findsOneWidget);
    expect(appRouter.routeInformationProvider.value.uri.path, '/home');
  });
}

class _GuestRepository extends MockAppRepository {
  @override
  bool get isAuthenticated => false;
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
  Future<ChatMessage> sendMessage(String prompt) async => ChatMessage(
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
