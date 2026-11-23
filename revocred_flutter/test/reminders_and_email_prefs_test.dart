import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:revocred_flutter/core/config/app_config.dart';
import 'package:revocred_flutter/core/data/api_app_repository.dart';
import 'package:revocred_flutter/core/data/mock_app_repository.dart';
import 'package:revocred_flutter/core/data/onboarding_draft_store.dart';
import 'package:revocred_flutter/core/models/app_models.dart';
import 'package:revocred_flutter/core/state/app_controller.dart';
import 'package:revocred_flutter/core/state/theme_controller.dart';
import 'package:revocred_flutter/core/theme/app_theme.dart';
import 'package:revocred_flutter/features/auth/presentation/account_screen.dart';
import 'package:revocred_flutter/features/home/presentation/home_screen.dart';
import 'package:revocred_flutter/features/profile/presentation/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TrackingRepository extends MockAppRepository {
  _TrackingRepository({
    this.authenticated = true,
    this.initialEmailOptIn = false,
  }) {
    _optIn = initialEmailOptIn;
  }

  final bool authenticated;
  final bool initialEmailOptIn;
  bool _optIn = false;
  Object? emailUpdateError;
  final List<(String, String, int?)> reminderUpdates = [];
  final List<(String, int?)> renewalMonthUpdates = [];
  final List<bool> emailOptInUpdates = [];

  @override
  bool get isAuthenticated => authenticated;

  @override
  bool get emailNotificationsOptIn => _optIn;

  @override
  Future<bool> updateEmailNotificationsOptIn(bool enabled) async {
    emailOptInUpdates.add(enabled);
    if (emailUpdateError != null) throw emailUpdateError!;
    _optIn = enabled;
    return _optIn;
  }

  @override
  Future<ReminderFeed> updateReminderState(
    String key, {
    required String status,
    int? snoozeDays,
  }) async {
    reminderUpdates.add((key, status, snoozeDays));
    return super.updateReminderState(
      key,
      status: status,
      snoozeDays: snoozeDays,
    );
  }

  @override
  Future<void> updateWalletRenewalMonth(
    String walletCardId,
    int? renewalMonth,
  ) async {
    renewalMonthUpdates.add((walletCardId, renewalMonth));
    return super.updateWalletRenewalMonth(walletCardId, renewalMonth);
  }
}

Future<ProviderContainer> _pumpRealScreen(
  WidgetTester tester,
  _TrackingRepository repository,
  Widget screen,
) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(const AppConfig(useMocks: false)),
      appRepositoryProvider.overrideWithValue(repository),
      sharedPreferencesProvider.overrideWithValue(prefs),
      onboardingDraftStoreProvider.overrideWithValue(
        OnboardingDraftStore(prefs),
      ),
    ],
  );
  addTearDown(container.dispose);
  await container.read(appControllerProvider.notifier).initialize();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.decisionFlow,
        home: Scaffold(body: screen),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets(
    'real mode Home shows reminders bell with badge and supports complete, restore, snooze, and renewal month',
    (tester) async {
      final repo = _TrackingRepository(authenticated: true);
      await _pumpRealScreen(tester, repo, const HomeScreen());

      // Bell icon and active count badge render in real authenticated mode.
      expect(find.byKey(const ValueKey('home-reminders-bell')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('home-reminders-badge')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('home-reminders-preview')),
        findsOneWidget,
      );

      // Open reminders sheet.
      await tester.tap(find.byKey(const ValueKey('home-reminders-bell')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('reminders-sheet')), findsOneWidget);

      // Mark the Gold dining credit used.
      final feed = await repo.loadReminders();
      final credit = feed.reminders.firstWhere((r) => r.kind == 'credit');
      final renewal = feed.reminders.firstWhere(
        (r) => r.actionKind == 'set_renewal_month',
      );
      await tester.tap(find.byKey(ValueKey('reminder-primary-${credit.key}')));
      await tester.pumpAndSettle();
      expect(
        repo.reminderUpdates.any(
          (u) => u.$1 == credit.key && u.$2 == 'completed',
        ),
        isTrue,
      );

      // Open Handled section and restore the credit reminder.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('reminders-handled-toggle')),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('reminders-sheet')),
              matching: find.byType(Scrollable),
            )
            .last,
      );
      await tester.tap(find.byKey(const ValueKey('reminders-handled-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('reminder-restore-${credit.key}')));
      await tester.pumpAndSettle();
      expect(
        repo.reminderUpdates.any((u) => u.$1 == credit.key && u.$2 == 'active'),
        isTrue,
      );

      // Snooze the restored credit reminder for 7 days.
      final sheetList = find
          .descendant(
            of: find.byKey(const ValueKey('reminders-sheet')),
            matching: find.byType(ListView),
          )
          .first;
      await tester.drag(sheetList, const Offset(0, 500));
      await tester.pumpAndSettle();
      final snoozeFinder = find.byKey(
        ValueKey('reminder-snooze-${credit.key}'),
      );
      await tester.ensureVisible(snoozeFinder);
      await tester.pumpAndSettle();
      await tester.tap(snoozeFinder);
      await tester.pumpAndSettle();
      expect(
        repo.reminderUpdates.any(
          (u) => u.$1 == credit.key && u.$2 == 'snoozed' && u.$3 == 7,
        ),
        isTrue,
      );

      // Set renewal month via the month picker dialog.
      final renewalFinder = find.byKey(
        ValueKey('reminder-primary-${renewal.key}'),
      );
      await tester.ensureVisible(renewalFinder);
      await tester.pumpAndSettle();
      await tester.tap(renewalFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('renewal-month-option-6')));
      await tester.pumpAndSettle();
      expect(repo.renewalMonthUpdates, contains((renewal.walletCardId, 6)));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('real guest mode hides reminders bell', (tester) async {
    final repo = _TrackingRepository(authenticated: false);
    await _pumpRealScreen(tester, repo, const HomeScreen());
    expect(find.byKey(const ValueKey('home-reminders-bell')), findsNothing);
    expect(find.byKey(const ValueKey('home-reminders-preview')), findsNothing);
  });

  testWidgets(
    'AccountScreen email notifications toggle persists opt-in and withdrawal',
    (tester) async {
      final repo = _TrackingRepository(
        authenticated: true,
        initialEmailOptIn: false,
      );
      await _pumpRealScreen(tester, repo, const AccountScreen());

      final toggleFinder = find.byKey(
        const ValueKey('email-notifications-toggle'),
      );
      await tester.ensureVisible(toggleFinder);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(toggleFinder).value, isFalse);

      // Opt in.
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();
      expect(repo.emailOptInUpdates, [true]);
      expect(tester.widget<SwitchListTile>(toggleFinder).value, isTrue);
      expect(
        find.text('Subscribed to RevoCred update emails.'),
        findsOneWidget,
      );

      // Withdraw consent.
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();
      expect(repo.emailOptInUpdates, [true, false]);
      expect(tester.widget<SwitchListTile>(toggleFinder).value, isFalse);
      expect(
        find.text('Unsubscribed from RevoCred update emails.'),
        findsOneWidget,
      );

      // Failure keeps current value and reports friendly feedback.
      repo.emailUpdateError = Exception('network down');
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(toggleFinder).value, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ProfileScreen shows email updates toggle in real signed-in mode',
    (tester) async {
      final repo = _TrackingRepository(
        authenticated: true,
        initialEmailOptIn: true,
      );
      await _pumpRealScreen(tester, repo, const ProfileScreen());
      final toggleFinder = find.byKey(
        const ValueKey('profile-email-notifications-toggle'),
      );
      await tester.ensureVisible(toggleFinder);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(toggleFinder).value, isTrue);

      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();
      expect(repo.emailOptInUpdates, [false]);
      expect(tester.widget<SwitchListTile>(toggleFinder).value, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('recovery and help AccountScreens do not show email toggle', (
    tester,
  ) async {
    final repo = _TrackingRepository(authenticated: false);
    await _pumpRealScreen(tester, repo, const AccountScreen(recovery: true));
    expect(
      find.byKey(const ValueKey('email-notifications-toggle')),
      findsNothing,
    );

    await _pumpRealScreen(tester, repo, const AccountScreen(help: true));
    expect(
      find.byKey(const ValueKey('email-notifications-toggle')),
      findsNothing,
    );
  });

  test(
    'ApiAppRepository calls reminders and renewal-month endpoints',
    () async {
      final requests = <(String, String, String)>[];
      final client = MockClient((request) async {
        requests.add((request.method, request.url.path, request.body));
        if (request.url.path.startsWith('/v1/reminders')) {
          return http.Response(
            jsonEncode({
              'data': {
                'generated_at': '2026-11-23T12:00:00Z',
                'active_count': 1,
                'reminders': [
                  {
                    'key': 'credit.gold.uber.2026-11',
                    'kind': 'credit',
                    'priority': 'high',
                    'status': 'active',
                    'title': r'Use $10 Uber Cash',
                    'detail': 'Monthly credit · Resets Dec 1',
                    'card_id': '20000000-0000-4000-8000-000000000016',
                    'wallet_card_id': 'w-1',
                    'card_name': 'Amex Gold',
                    'amount_cents': 1000,
                    'period_label': 'Nov 2026',
                    'action_kind': 'mark_used',
                    'action_label': 'Mark used',
                    'route': '/cards',
                    'can_complete': true,
                  },
                ],
              },
            }),
            200,
          );
        }
        if (request.url.path == '/v1/wallet/w-1/renewal-month') {
          return http.Response(
            jsonEncode({
              'data': {'id': 'w-1', 'renewal_month': 4},
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      });

      final repo = ApiAppRepository(
        baseUrl: 'https://api.example.test',
        supabaseClient: null,
        accessTokenProvider: () => 'token-123',
        httpClient: client,
      );

      final loaded = await repo.loadReminders();
      expect(loaded.activeCount, 1);
      expect(loaded.reminders.first.key, 'credit.gold.uber.2026-11');
      expect(loaded.reminders.first.formattedAmount, r'$10');

      await repo.updateReminderState(
        'credit.gold.uber.2026-11',
        status: 'snoozed',
        snoozeDays: 7,
      );
      await repo.updateWalletRenewalMonth('w-1', 4);

      expect(requests[0].$1, 'GET');
      expect(requests[0].$2, '/v1/reminders');
      expect(requests[1].$1, 'PUT');
      expect(requests[1].$2, '/v1/reminders/credit.gold.uber.2026-11');
      expect(jsonDecode(requests[1].$3), {
        'status': 'snoozed',
        'snooze_days': 7,
      });
      expect(requests[2].$1, 'PUT');
      expect(requests[2].$2, '/v1/wallet/w-1/renewal-month');
      expect(jsonDecode(requests[2].$3), {'renewal_month': 4});
    },
  );
}
