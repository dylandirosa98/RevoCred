import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:revocred_flutter/app.dart';
import 'package:revocred_flutter/core/config/app_config.dart';
import 'package:revocred_flutter/core/data/mock_app_repository.dart';
import 'package:revocred_flutter/core/models/app_models.dart';
import 'package:revocred_flutter/core/router/app_router.dart';
import 'package:revocred_flutter/core/state/app_controller.dart';
import 'package:revocred_flutter/core/state/theme_controller.dart';
import 'package:revocred_flutter/core/theme/app_theme.dart';
import 'package:revocred_flutter/features/auth/presentation/account_screen.dart';
import 'package:revocred_flutter/features/cards/presentation/cards_screen.dart';
import 'package:revocred_flutter/features/explore/presentation/explore_rewards_screen.dart';
import 'package:revocred_flutter/features/profile/presentation/legal_screen.dart';
import 'package:revocred_flutter/features/revo/presentation/message_feedback.dart';
import 'package:revocred_flutter/features/revo/presentation/revo_screen.dart';
import 'package:revocred_flutter/shared/widgets/card_terms_sheet.dart';
import 'package:revocred_flutter/shared/widgets/custom_card_form.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailingChatRepository extends MockAppRepository {
  @override
  Future<ChatMessage> sendMessage(
    String prompt, {
    String? aiConsentVersion,
  }) async {
    throw StateError('Temporary network failure while contacting REVO.');
  }
}

void main() {
  group('resolveAuthRedirectUrl', () {
    test('uses active HTTPS browser origin on web across aliased domains', () {
      const config = AppConfig(
        useMocks: false,
        production: true,
        authRedirectUrl: 'https://app.revocred.com/',
      );
      expect(
        resolveAuthRedirectUrl(
          config,
          isWeb: true,
          baseUri: Uri.parse('https://revocred-pwa.vercel.app/#/welcome'),
        ),
        'https://revocred-pwa.vercel.app/',
      );
      expect(
        resolveAuthRedirectUrl(
          config,
          isWeb: true,
          baseUri: Uri.parse('https://app.revocred.com/?recovery=true'),
        ),
        'https://app.revocred.com/',
      );
    });

    test('uses loopback HTTP origin on non-production web', () {
      const config = AppConfig(
        useMocks: false,
        production: false,
        authRedirectUrl: 'https://stale-tunnel.trycloudflare.com/',
      );
      expect(
        resolveAuthRedirectUrl(
          config,
          isWeb: true,
          baseUri: Uri.parse('http://127.0.0.1:8083/#/welcome'),
        ),
        'http://127.0.0.1:8083/',
      );
    });

    test('rejects insecure HTTP origin in production web builds', () {
      const config = AppConfig(
        useMocks: false,
        production: true,
        authRedirectUrl: 'https://app.revocred.com/',
      );
      expect(
        resolveAuthRedirectUrl(
          config,
          isWeb: true,
          baseUri: Uri.parse('http://insecure.example.test/'),
        ),
        'https://app.revocred.com/',
      );
    });

    test('preserves configured native callback when not on web', () {
      const config = AppConfig(
        useMocks: false,
        production: true,
        authRedirectUrl: 'com.revocred.app://auth-callback/',
      );
      expect(
        resolveAuthRedirectUrl(
          config,
          isWeb: false,
          baseUri: Uri.parse('https://revocred-pwa.vercel.app/'),
        ),
        'com.revocred.app://auth-callback/',
      );
      expect(
        resolveAuthRedirectUrl(const AppConfig(useMocks: false), isWeb: false),
        'com.revocred.app://auth-callback/',
      );
    });
  });

  group('mobile PWA & tablet responsive layouts', () {
    testWidgets(
      'bottom nav uses short labels at 390px with large text and full labels at 1.0x',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();

        appRouter.go('/home');
        await tester.pumpWidget(
          RevoCredBootstrap(
            config: const AppConfig(useMocks: true),
            repository: MockAppRepository(),
            preferences: preferences,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Ask REVO'), findsWidgets);
        expect(find.text('Strategy'), findsWidgets);

        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        await tester.pumpAndSettle();

        expect(find.text('REVO'), findsOneWidget);
        expect(find.text('Plan'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'modal sheets fit 390px mobile with keyboard open, dark theme, and 1.6x text',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        const sampleRef = ReferenceCard(
          id: 'ref-1',
          issuer: 'Citi',
          name: 'Citi Custom Cash',
          network: 'Mastercard',
          rewardsType: 'cash_back',
          annualFeeCents: 0,
          rewardRates: {'groceries': 5, 'other': 1},
          termsStatus: 'verified',
          sourceUrl: 'https://example.test/citi',
          sourceCapturedOn: '2026-10-01',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appConfigProvider.overrideWithValue(
                const AppConfig(useMocks: true),
              ),
              appRepositoryProvider.overrideWithValue(MockAppRepository()),
            ],
            child: MaterialApp(
              theme: AppTheme.decisionFlowDark,
              home: Scaffold(
                body: Builder(
                  builder: (context) => Column(
                    children: [
                      ElevatedButton(
                        onPressed: () => showCardTermsSheet(context, sampleRef),
                        child: const Text('Open terms'),
                      ),
                      ElevatedButton(
                        onPressed: () => showCustomCardSheet(context),
                        child: const Text('Open custom'),
                      ),
                      ElevatedButton(
                        onPressed: () => showExploreRewardsHelp(context),
                        child: const Text('Open help'),
                      ),
                      const MessageFeedback(
                        messageId: '00000000-0000-4000-8000-000000000001',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open terms'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Close card terms'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Close card terms'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open custom'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Close custom card form'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Close custom card form'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open help'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Close help'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Close help'));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Not helpful'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Close feedback'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Close feedback'));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'deep-linked Account, Legal, and Explore screens provide a fallback back button',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();

        final visited = <String>[];
        final router = GoRouter(
          initialLocation: '/account',
          routes: [
            GoRoute(path: '/account', builder: (_, _) => const AccountScreen()),
            GoRoute(
              path: '/reset-password',
              builder: (_, _) => const AccountScreen(recovery: true),
            ),
            GoRoute(path: '/legal', builder: (_, _) => const LegalScreen()),
            GoRoute(
              path: '/explore-rewards',
              builder: (_, _) => const ExploreRewardsScreen(),
            ),
            GoRoute(
              path: '/profile',
              builder: (_, _) {
                visited.add('/profile');
                return const Scaffold(body: Text('Profile destination'));
              },
            ),
            GoRoute(
              path: '/home',
              builder: (_, _) {
                visited.add('/home');
                return const Scaffold(body: Text('Home destination'));
              },
            ),
            GoRoute(
              path: '/welcome',
              builder: (_, _) {
                visited.add('/welcome');
                return const Scaffold(body: Text('Welcome destination'));
              },
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appConfigProvider.overrideWithValue(
                const AppConfig(useMocks: true),
              ),
              appRepositoryProvider.overrideWithValue(MockAppRepository()),
              sharedPreferencesProvider.overrideWithValue(preferences),
            ],
            child: MaterialApp.router(
              theme: AppTheme.decisionFlow,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // /account deep link navigates back to /profile.
        expect(find.byType(BackButton), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(visited.last, '/profile');

        // /reset-password forced recovery hides the back button.
        router.go('/reset-password');
        await tester.pumpAndSettle();
        expect(find.byType(BackButton), findsNothing);

        // /legal deep link navigates back to /profile when signed in.
        router.go('/legal');
        await tester.pumpAndSettle();
        expect(find.byType(BackButton), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(visited.last, '/profile');

        // /explore-rewards deep link navigates back to /home.
        router.go('/explore-rewards');
        await tester.pumpAndSettle();
        expect(find.byType(BackButton), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(visited.last, '/home');
      },
    );

    testWidgets(
      'home screen issuer monogram uses initials for multi-word issuers and tablet 768px renders cleanly',
      (tester) async {
        tester.view.physicalSize = const Size(768, 1024);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.4;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();

        appRouter.go('/home');
        await tester.pumpWidget(
          RevoCredBootstrap(
            config: const AppConfig(useMocks: true),
            repository: MockAppRepository(),
            preferences: preferences,
          ),
        );
        await tester.pumpAndSettle();

        // Demo wallet includes Capital One Venture X -> monogram must be "CO", not "CA".
        expect(find.text('CO'), findsWidgets);
        expect(find.text('CA'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'account deletion password visibility toggles and export dialog fits 390px screen',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appConfigProvider.overrideWithValue(
                const AppConfig(useMocks: true),
              ),
              appRepositoryProvider.overrideWithValue(MockAppRepository()),
            ],
            child: MaterialApp(
              theme: AppTheme.decisionFlowDark,
              home: const AccountScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final deleteFieldFinder = find.byKey(
          const ValueKey('account-delete-password'),
        );
        await tester.ensureVisible(deleteFieldFinder);
        expect(tester.widget<TextField>(deleteFieldFinder).obscureText, isTrue);

        await tester.tap(find.byTooltip('Show current password'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(deleteFieldFinder).obscureText,
          isFalse,
        );

        await tester.tap(find.text('Export my data'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Your account data (JSON)'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'REVO error banner fits 360px mobile screen at 1.6x text scale without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(360, 844);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appConfigProvider.overrideWithValue(
                const AppConfig(useMocks: true),
              ),
              appRepositoryProvider.overrideWithValue(_FailingChatRepository()),
            ],
            child: MaterialApp(
              theme: AppTheme.decisionFlowDark,
              home: const Scaffold(body: RevoScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('revo-composer')),
          'Which card for dining?',
        );
        await tester.tap(find.byKey(const ValueKey('revo-send')));
        await tester.pumpAndSettle();

        expect(find.text('Try again'), findsOneWidget);
        expect(find.text('Dismiss'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'CardsScreen renders cleanly at 390px dark mode with 1.6x large text and open picker',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final router = GoRouter(
          initialLocation: '/cards',
          routes: [
            GoRoute(
              path: '/cards',
              builder: (_, _) => const Scaffold(body: CardsScreen()),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appConfigProvider.overrideWithValue(
                const AppConfig(useMocks: true),
              ),
              appRepositoryProvider.overrideWithValue(MockAppRepository()),
            ],
            child: MaterialApp.router(
              theme: AppTheme.decisionFlowDark,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('add-card-top-button')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('wallet-card-search')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
