import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/core/state/theme_controller.dart';
import 'package:revocred_flutter/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('only Decision Flow light and dark are user-facing', () {
    final products = availableAppThemeVariants
        .map(
          (variant) => AppTheme.forVariant(variant).extension<ProductTheme>()!,
        )
        .toList();

    expect(availableAppThemeVariants, [
      AppThemeVariant.decisionFlow,
      AppThemeVariant.decisionFlowDark,
    ]);
    expect(products, hasLength(2));
    expect(
      products.every((theme) => theme.heroTreatment == HeroTreatment.decision),
      isTrue,
    );
    expect(AppTheme.decisionFlow.brightness, Brightness.light);
    expect(AppTheme.decisionFlowDark.brightness, Brightness.dark);
  });

  test('defaults to following the phone and persists choices', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    expect(container.read(themeControllerProvider), isNull);

    await container
        .read(themeControllerProvider.notifier)
        .select(AppThemeVariant.decisionFlowDark);
    expect(
      container.read(themeControllerProvider),
      AppThemeVariant.decisionFlowDark,
    );
    expect(preferences.getString(themePreferenceKey), 'decisionFlowDark');

    await container.read(themeControllerProvider.notifier).select(null);
    expect(container.read(themeControllerProvider), isNull);
    expect(preferences.getString(themePreferenceKey), 'system');
  });

  test('loads persisted dark mode synchronously', () async {
    SharedPreferences.setMockInitialValues({
      themePreferenceKey: 'decisionFlowDark',
    });
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(themeControllerProvider),
      AppThemeVariant.decisionFlowDark,
    );
  });

  test('retired themes follow the phone', () async {
    SharedPreferences.setMockInitialValues({
      themePreferenceKey: 'walletStudio',
    });
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    expect(container.read(themeControllerProvider), isNull);
  });
}
