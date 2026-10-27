import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/app_controller.dart';

import '../../features/cards/presentation/cards_screen.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/auth/presentation/account_screen.dart';
import '../../features/profile/presentation/legal_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/questionnaire_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/revo/presentation/revo_screen.dart';
import '../../features/strategy/presentation/strategy_screen.dart';
import '../../features/strategy/presentation/strategy_report_screen.dart';
import '../../shared/widgets/app_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/welcome',
  redirect: (context, route) {
    final container = ProviderScope.containerOf(context, listen: false);
    if (container.read(appConfigProvider).useMocks) return null;
    final session = container.read(appControllerProvider);
    final path = route.uri.path;
    if (session.passwordRecovery) {
      return path == '/reset-password' ? null : '/reset-password';
    }
    if (session.isAuthenticated) return null;
    if (const [
      '/welcome',
      '/questionnaire',
      '/legal',
      '/account-recovery',
    ].contains(path)) {
      return null;
    }
    if (path == '/strategy-report' && session.data?.isPersonalPreview == true) {
      return null;
    }
    return '/welcome';
  },
  routes: [
    GoRoute(
      path: '/reset-password',
      builder: (context, state) => const AccountScreen(recovery: true),
    ),
    GoRoute(
      path: '/account',
      builder: (context, state) => const AccountScreen(),
    ),
    GoRoute(
      path: '/account-recovery',
      builder: (context, state) => const AccountScreen(help: true),
    ),
    GoRoute(path: '/legal', builder: (context, state) => const LegalScreen()),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/home', pageBuilder: _page(const HomeScreen())),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/cards', pageBuilder: _page(const CardsScreen())),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/strategy',
              pageBuilder: _page(const StrategyScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/revo', pageBuilder: _page(const RevoScreen())),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              pageBuilder: _page(const ProfileScreen()),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/questionnaire',
      pageBuilder: _detailPage(const QuestionnaireScreen()),
    ),
    GoRoute(
      path: '/strategy-report',
      pageBuilder: _detailPage(const _DataReady(child: StrategyReportScreen())),
    ),
    GoRoute(
      path: '/welcome',
      builder: (context, state) => AuthScreen(
        savePlan: state.uri.queryParameters['save'] == 'true',
        returnToReport: state.uri.queryParameters['from'] == 'report',
      ),
    ),
  ],
);

Page<void> Function(BuildContext, GoRouterState) _page(Widget child) =>
    (context, state) => NoTransitionPage<void>(
      key: state.pageKey,
      child: _DataReady(child: child),
    );

/// Restored sessions may reach a deep link before the API bootstrap completes.
/// Never build account content with missing data or a signed-out demo profile.
class _DataReady extends ConsumerWidget {
  const _DataReady({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final mocks = ref.watch(appConfigProvider).useMocks;
    if (!mocks &&
        !state.isAuthenticated &&
        state.data?.isPersonalPreview != true) {
      return const SizedBox.shrink();
    }
    if (state.data == null) {
      return BrandedLoadingScreen(
        error: state.error,
        onRetry: () => ref.read(appControllerProvider.notifier).refresh(),
      );
    }
    return child;
  }
}

Page<void> Function(BuildContext, GoRouterState) _detailPage(Widget child) =>
    (context, state) => CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 190),
      reverseTransitionDuration: const Duration(milliseconds: 150),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curve,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, .025),
              end: Offset.zero,
            ).animate(curve),
            child: child,
          ),
        );
      },
    );
