import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/app_config.dart';
import 'core/data/app_repository.dart';
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
    final variant = ref.watch(themeControllerProvider);
    return MaterialApp.router(
      title: 'RevoCred',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.forVariant(variant),
      themeAnimationDuration: Duration.zero,
      routerConfig: appRouter,
      builder: (context, child) {
        if (!state.isAuthenticated) {
          final path = appRouter.routeInformationProvider.value.uri.path;
          if (path != '/welcome') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) appRouter.go('/welcome');
            });
            return const BrandedLoadingScreen();
          }
          return child ?? const SizedBox.shrink();
        }
        if (state.data == null) {
          return BrandedLoadingScreen(
            error: state.error,
            onRetry: () => ref.read(appControllerProvider.notifier).refresh(),
          );
        }
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
