import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/core/config/app_config.dart';
import 'package:revocred_flutter/core/theme/app_theme.dart';
import 'package:revocred_flutter/core/data/app_repository.dart';
import 'package:revocred_flutter/core/data/mock_app_repository.dart';
import 'package:revocred_flutter/core/data/onboarding_draft_store.dart';
import 'package:revocred_flutter/core/state/app_controller.dart';
import 'package:revocred_flutter/features/auth/presentation/account_screen.dart';
import 'package:revocred_flutter/features/auth/presentation/auth_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RecordingRepository extends MockAppRepository {
  int calls = 0;
  String? receivedEmail;
  String? receivedPassword;
  Completer<AuthResult>? pending;
  Object? failure;
  Completer<void>? accountPending;
  @override
  bool get isAuthenticated => false;
  @override
  Future<AuthResult> signUp(
    String email,
    String password, {
    String displayName = '',
    bool notificationsOptIn = false,
  }) async {
    calls++;
    receivedEmail = email;
    receivedPassword = password;
    if (failure != null) throw failure!;
    return pending == null
        ? const AuthResult(success: false, message: 'Invalid login credentials')
        : pending!.future;
  }

  @override
  Future<AuthResult> signIn(String email, String password) =>
      signUp(email, password);
  @override
  Future<void> resendVerification(String email) async {
    calls++;
    receivedEmail = email;
    if (failure != null) throw failure!;
    if (accountPending != null) await accountPending!.future;
  }

  @override
  Future<void> requestPasswordReset(String email) => resendVerification(email);
  @override
  Future<void> updateEmail(String email) => resendVerification(email);
  @override
  Future<void> updatePassword(String password) async {
    calls++;
    receivedPassword = password;
    if (failure != null) throw failure!;
    if (accountPending != null) await accountPending!.future;
  }

  @override
  Future<void> deleteAccount(String password) => updatePassword(password);
  @override
  Future<void> signOut() async {
    calls++;
    if (failure != null) throw failure!;
  }
}

Future<void> mount(
  WidgetTester tester,
  RecordingRepository repository, {
  Widget screen = const AuthScreen(savePlan: true),
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(const AppConfig(useMocks: false)),
        appRepositoryProvider.overrideWithValue(repository),
        onboardingDraftStoreProvider.overrideWithValue(
          OnboardingDraftStore(prefs),
        ),
      ],
      child: MaterialApp(theme: AppTheme.decisionFlow, home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> credentials(
  WidgetTester tester, {
  String email = 'member@example.test',
  String password = 'LongPassword123!',
}) async {
  await tester.enterText(find.byKey(const ValueKey('auth-name')), 'Member');
  await tester.enterText(find.byKey(const ValueKey('auth-email')), email);
  await tester.enterText(find.byKey(const ValueKey('auth-password')), password);
}

void main() {
  testWidgets('auth side note wraps at tablet desktop breakpoint', (
    tester,
  ) async {
    await mount(tester, RecordingRepository());
    tester.view.physicalSize = const Size(1000, 1400);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling deletion never claims account was deleted', (
    tester,
  ) async {
    final repository = RecordingRepository();
    await mount(tester, repository, screen: const AccountScreen());
    await tester.enterText(find.byType(TextField).last, 'current');
    await tester.tap(find.text('Delete my account'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.calls, 0);
    expect(find.text('Account deleted.'), findsNothing);
  });

  testWidgets('keyboard duplicate submit is guarded before next frame', (
    tester,
  ) async {
    final repository = RecordingRepository()..pending = Completer<AuthResult>();
    await mount(tester, repository);
    await credentials(tester, password: '  LongPassword123!  ');
    final submit = tester
        .widget<TextField>(find.byKey(const ValueKey('auth-password')))
        .onSubmitted!;
    submit('');
    submit('');
    await tester.pump();
    expect(repository.calls, 1);
    expect(repository.receivedPassword, '  LongPassword123!  ');
    repository.pending!.complete(const AuthResult(success: false));
    await tester.pumpAndSettle();
  });

  testWidgets('auth response after disposal cannot mutate widget state', (
    tester,
  ) async {
    final repository = RecordingRepository()..pending = Completer<AuthResult>();
    await mount(tester, repository);
    await credentials(tester);
    await tester.tap(find.byKey(const ValueKey('auth-submit')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    repository.pending!.complete(const AuthResult(success: false));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('unreachable authentication is distinct from invalid credentials', (
    tester,
  ) async {
    final repository = RecordingRepository()..failure = Exception('offline');
    await mount(tester, repository);
    await credentials(tester);
    await tester.tap(find.byKey(const ValueKey('auth-submit')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Unable to reach the authentication service. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Invalid login credentials'), findsNothing);
  });

  testWidgets('signup name and password requirements do not apply to login', (
    tester,
  ) async {
    final repository = RecordingRepository();
    await mount(tester, repository);
    await credentials(tester, password: 'short');
    await tester.tap(find.byKey(const ValueKey('auth-submit')));
    await tester.pumpAndSettle();
    expect(repository.calls, 0);
    await tester.enterText(find.byKey(const ValueKey('auth-name')), '   ');
    await tester.enterText(
      find.byKey(const ValueKey('auth-password')),
      'LongPassword123!',
    );
    await tester.tap(find.byKey(const ValueKey('auth-submit')));
    await tester.pumpAndSettle();
    expect(repository.calls, 0);
    expect(
      find.text('Enter the name you want to see in RevoCred.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('auth-switch-mode')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('auth-password')), 'old');
    await tester.tap(find.byKey(const ValueKey('auth-submit')));
    await tester.pumpAndSettle();
    expect(repository.calls, 1);
  });

  testWidgets(
    'email change rejects invalid email and reports reauthentication',
    (tester) async {
      final repository = RecordingRepository()
        ..failure = const AuthException(
          'Reauthentication required',
          code: 'reauthentication_needed',
        );
      await mount(tester, repository, screen: const AccountScreen());
      await tester.enterText(find.byType(TextField).first, 'member@');
      await tester.tap(find.text('Change email'));
      await tester.pumpAndSettle();
      expect(repository.calls, 0);
      await tester.enterText(
        find.byType(TextField).first,
        '  member@example.test  ',
      );
      await tester.tap(find.text('Change email'));
      await tester.pumpAndSettle();
      expect(repository.receivedEmail, 'member@example.test');
      expect(
        find.text(
          'For your security, sign in again before changing your account.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('password update validates and stays retryable on failure', (
    tester,
  ) async {
    final repository = RecordingRepository()..failure = Exception('offline');
    await mount(
      tester,
      repository,
      screen: const AccountScreen(recovery: true),
    );
    await tester.enterText(find.byType(TextField), 'short');
    await tester.tap(find.text('Update password'));
    await tester.pumpAndSettle();
    expect(repository.calls, 0);
    await tester.enterText(find.byType(TextField), 'LongPassword123!');
    await tester.tap(find.text('Update password'));
    await tester.pumpAndSettle();
    expect(repository.calls, 1);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, true);
    expect(
      find.text(
        'Unable to complete this request. Check your connection and try again.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('pending password update may complete after disposal', (
    tester,
  ) async {
    final repository = RecordingRepository()
      ..accountPending = Completer<void>();
    await mount(
      tester,
      repository,
      screen: const AccountScreen(recovery: true),
    );
    await tester.enterText(find.byType(TextField), 'LongPassword123!');
    await tester.tap(find.text('Update password'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);
    await tester.pumpWidget(const SizedBox());
    repository.accountPending!.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('delete requires current password and explicit confirmation', (
    tester,
  ) async {
    final repository = RecordingRepository()
      ..failure = const AuthException('Invalid login credentials');
    await mount(tester, repository, screen: const AccountScreen());
    await tester.tap(find.text('Delete my account'));
    await tester.pumpAndSettle();
    expect(repository.calls, 0);
    expect(
      find.text('Enter your current password to confirm deletion.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField).last, 'current');
    await tester.tap(find.text('Delete my account'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(repository.calls, 0);
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    expect(repository.calls, 1);
    expect(repository.receivedPassword, 'current');
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('form switch conceals password and clears stale feedback', (
    tester,
  ) async {
    await mount(tester, RecordingRepository());
    await credentials(tester);
    await tester.tap(find.byTooltip('Show password'));
    await tester.tap(find.byKey(const ValueKey('auth-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('auth-switch-mode')));
    await tester.pumpAndSettle();
    expect(find.text('Invalid login credentials'), findsNothing);
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('auth-password')),
    );
    expect(field.obscureText, true);
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('recovery unknown account response remains private', (
    tester,
  ) async {
    final repository = RecordingRepository()
      ..failure = const AuthException('User not found', code: 'user_not_found');
    await mount(tester, repository, screen: const AccountScreen(help: true));
    await tester.enterText(find.byType(TextField).first, 'absent@example.test');
    await tester.tap(find.text('Send password reset'));
    await tester.pumpAndSettle();
    expect(find.text('User not found'), findsNothing);
    expect(
      find.text(
        'If an account exists, a recovery email has been sent. Check your inbox.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('cancel recovery reports failure instead of uncaught error', (
    tester,
  ) async {
    final repository = RecordingRepository()..failure = Exception('offline');
    await mount(
      tester,
      repository,
      screen: const AccountScreen(recovery: true),
    );
    await tester.tap(find.text('Cancel recovery and sign out'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.text(
        'Unable to complete this request. Check your connection and try again.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('signup rejects malformed email before contacting auth', (
    tester,
  ) async {
    final repository = RecordingRepository();
    await mount(tester, repository);
    await credentials(tester, email: 'not-an-email');
    await tester.tap(find.byKey(const ValueKey('auth-submit')));
    await tester.pumpAndSettle();
    expect(repository.calls, 0);
    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('pending auth locks inputs and back navigation', (tester) async {
    final repository = RecordingRepository()..pending = Completer<AuthResult>();
    await mount(tester, repository);
    await credentials(tester, email: '  member@example.test  ');
    await tester.tap(find.byKey(const ValueKey('auth-submit')));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('auth-email')))
          .enabled,
      false,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('auth-back')))
          .onPressed,
      isNull,
    );
    expect(repository.receivedEmail, 'member@example.test');
    repository.pending!.complete(
      const AuthResult(success: false, message: 'Invalid login credentials'),
    );
    await tester.pumpAndSettle();
    expect(repository.calls, 1);
  });

  testWidgets(
    'confirmation-required signup offers sign in without signup password',
    (tester) async {
      final repository = RecordingRepository()
        ..pending = Completer<AuthResult>();
      await mount(tester, repository);
      await credentials(tester);
      await tester.tap(find.byKey(const ValueKey('auth-submit')));
      await tester.pump();
      repository.pending!.complete(
        const AuthResult(
          success: true,
          message: 'Check your email to confirm the account, then sign in.',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('auth-password')))
            .controller!
            .text,
        isEmpty,
      );
      expect(
        find.text('Check your email to confirm the account, then sign in.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('resend and email change validate before repository calls', (
    tester,
  ) async {
    final repository = RecordingRepository();
    await mount(tester, repository, screen: const AccountScreen(help: true));
    await tester.enterText(find.byType(TextField).first, 'invalid');
    await tester.tap(find.text('Resend account confirmation'));
    await tester.pumpAndSettle();
    expect(repository.calls, 0);
    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('account password visibility can be toggled', (tester) async {
    await mount(
      tester,
      RecordingRepository(),
      screen: const AccountScreen(recovery: true),
    );
    await tester.tap(find.byTooltip('Show password'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).obscureText, false);
  });
}
