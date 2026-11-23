import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/app_config.dart';
import 'core/data/app_repository.dart';
import 'core/data/onboarding_draft_store.dart';
import 'core/router/app_router.dart';
import 'core/services/pwa_install.dart';
import 'core/services/subscriptions.dart';
import 'core/state/app_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/state/theme_controller.dart';
import 'features/auth/presentation/auth_screen.dart';

class RevoCredBootstrap extends StatelessWidget {
  const RevoCredBootstrap({
    required this.config,
    required this.repository,
    required this.preferences,
    this.subscriptions = const UnavailableSubscriptionService(),
    super.key,
  });

  final AppConfig config;
  final AppRepository repository;
  final SharedPreferences preferences;

  /// In-app purchases; unavailable except in configured iOS builds.
  final SubscriptionService subscriptions;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(config),
      appRepositoryProvider.overrideWithValue(repository),
      sharedPreferencesProvider.overrideWithValue(preferences),
      subscriptionServiceProvider.overrideWithValue(subscriptions),
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
  final _messenger = GlobalKey<ScaffoldMessengerState>();

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
    // Confirm finished actions (card added, name updated, signed out…).
    ref.listen(appControllerProvider.select((state) => state.actionMessage), (
      _,
      message,
    ) {
      if (message == null || message.isEmpty) return;
      _messenger.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      ref.read(appControllerProvider.notifier).clearActionMessage();
    });
    final variant = ref.watch(themeControllerProvider);
    return MaterialApp.router(
      scaffoldMessengerKey: _messenger,
      title: 'RevoCred',
      debugShowCheckedModeBanner: false,
      theme: variant == null
          ? AppTheme.decisionFlow
          : AppTheme.forVariant(variant),
      darkTheme: AppTheme.decisionFlowDark,
      themeMode: variant == null ? ThemeMode.system : ThemeMode.light,
      themeAnimationDuration: Duration.zero,
      routerConfig: appRouter,
      builder: (context, child) => WebSafeAreaScope(
        child: ListenableBuilder(
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
      ),
    );
  }
}

/// Bridges browser CSS `env(safe-area-inset-*)` into Flutter's [MediaQuery] so
/// [SafeArea] and [NavigationBar] clear notches and home indicators in mobile
/// PWAs. Native builds report [EdgeInsets.zero] here and keep platform insets.
class WebSafeAreaScope extends ConsumerStatefulWidget {
  const WebSafeAreaScope({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<WebSafeAreaScope> createState() => _WebSafeAreaScopeState();
}

class _WebSafeAreaScopeState extends ConsumerState<WebSafeAreaScope> {
  EdgeInsets _insets = EdgeInsets.zero;
  StreamSubscription<PwaInstallStatus>? _subscription;

  @override
  void initState() {
    super.initState();
    final client = ref.read(pwaInstallClientProvider);
    _insets = client.readStatus().safeAreaInsets;
    _subscription = client.statusChanges.listen((status) {
      if (mounted && status.safeAreaInsets != _insets) {
        setState(() => _insets = status.safeAreaInsets);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_insets == EdgeInsets.zero) return widget.child;
    final media = MediaQuery.of(context);
    final viewPadding = EdgeInsets.only(
      top: math.max(media.viewPadding.top, _insets.top),
      right: math.max(media.viewPadding.right, _insets.right),
      bottom: math.max(media.viewPadding.bottom, _insets.bottom),
      left: math.max(media.viewPadding.left, _insets.left),
    );
    final padding = EdgeInsets.only(
      top: math.max(0.0, viewPadding.top - media.viewInsets.top),
      right: math.max(0.0, viewPadding.right - media.viewInsets.right),
      bottom: math.max(0.0, viewPadding.bottom - media.viewInsets.bottom),
      left: math.max(0.0, viewPadding.left - media.viewInsets.left),
    );
    return MediaQuery(
      data: media.copyWith(padding: padding, viewPadding: viewPadding),
      child: widget.child,
    );
  }
}
