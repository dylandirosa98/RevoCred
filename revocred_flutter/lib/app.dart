import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/app_config.dart';
import 'core/data/app_repository.dart';
import 'core/data/onboarding_draft_store.dart';
import 'core/router/app_router.dart';
import 'core/state/app_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/state/theme_controller.dart';
import 'features/auth/presentation/auth_screen.dart';

class RevoCredBootstrap extends StatelessWidget {
  const RevoCredBootstrap({
    required this.config,
    required this.repository,
    required this.preferences,
    super.key,
  });

  final AppConfig config;
  final AppRepository repository;
  final SharedPreferences preferences;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(config),
      appRepositoryProvider.overrideWithValue(repository),
      sharedPreferencesProvider.overrideWithValue(preferences),
      onboardingDraftStoreProvider.overrideWithValue(
        OnboardingDraftStore(preferences),
      ),
    ],
    child: const RevoCredApp(),
  );
}

class RevoCredApp extends ConsumerStatefulWidget {
  const RevoCredApp({super.key});
  @override
  ConsumerState<RevoCredApp> createState() => _RevoCredAppState();
}

class _RevoCredAppState extends ConsumerState<RevoCredApp> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(appControllerProvider.notifier).initialize(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    ref.listen(appControllerProvider, (previous, next) {
      if (previous?.isAuthenticated != next.isAuthenticated ||
          previous?.passwordRecovery != next.passwordRecovery ||
          previous?.data?.isPersonalPreview != next.data?.isPersonalPreview) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) appRouter.refresh();
        });
      }
    });
    final variant = ref.watch(themeControllerProvider);
    return MaterialApp.router(
      title: 'RevoCred',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.forVariant(variant),
      themeAnimationDuration: Duration.zero,
      routerConfig: appRouter,
      builder: (context, child) => ListenableBuilder(
        listenable: appRouter.routeInformationProvider,
        builder: (context, _) {
          final page = child ?? const SizedBox.shrink();
          final path = appRouter.routeInformationProvider.value.uri.path;
          if (!ref.read(appConfigProvider).useMocks &&
              state.isAuthenticated &&
              !state.isLoading &&
              state.error == null &&
              state.data != null &&
              !state.data!.isPersonalPreview &&
              !state.passwordRecovery &&
              path == '/welcome') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                appRouter.go(
                  state.data!.questionnaireAnswers == null
                      ? '/questionnaire'
                      : '/home',
                );
              }
            });
          }
          if (state.passwordRecovery && path != '/reset-password') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) appRouter.go('/reset-password');
            });
          }
          if (!state.isAuthenticated) {
            // Router redirects protect deep links; hide private pages immediately
            // while an expired session or logout redirect is being processed.
            if (!ref.read(appConfigProvider).useMocks &&
                !const [
                  '/welcome',
                  '/questionnaire',
                  '/legal',
                  '/account-recovery',
                ].contains(path) &&
                !(path == '/strategy-report' &&
                    state.data?.isPersonalPreview == true) &&
                !state.passwordRecovery) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) appRouter.go('/welcome');
              });
              // Keep the Router mounted so it can finish the redirect. An opaque
              // loading overlay prevents interaction with the outgoing page.
              return Stack(
                fit: StackFit.expand,
                children: [page, const BrandedLoadingScreen()],
              );
            }
            if (state.data != null) return page;
          }
          if (state.isAuthenticated && state.data == null) {
            // Overlay instead of replacing the Navigator: unmounting routes would
            // drop in-progress screens (such as a sign-in form awaiting its
            // server refresh) and lose their navigation continuations.
            return Stack(
              fit: StackFit.expand,
              children: [
                page,
                BrandedLoadingScreen(
                  error: state.error,
                  onRetry: () =>
                      ref.read(appControllerProvider.notifier).refresh(),
                ),
              ],
            );
          }
          return page;
        },
      ),
    );
  }
}
