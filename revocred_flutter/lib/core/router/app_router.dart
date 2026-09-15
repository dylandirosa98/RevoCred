import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/cards/presentation/cards_screen.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/questionnaire_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/revo/presentation/revo_screen.dart';
import '../../features/strategy/presentation/strategy_screen.dart';
import '../../shared/widgets/app_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/welcome',
  routes: [
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
    GoRoute(path: '/welcome', pageBuilder: _detailPage(const AuthScreen())),
  ],
);

Page<void> Function(BuildContext, GoRouterState) _page(Widget child) =>
    (context, state) =>
        NoTransitionPage<void>(key: state.pageKey, child: child);

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
