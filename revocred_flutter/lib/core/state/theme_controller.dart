import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

const themePreferenceKey = 'app_theme_variant';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('SharedPreferences must be overridden.'),
);

/// The chosen appearance: a fixed light or dark theme, or null to follow the
/// phone's light/dark setting (the default).
final themeControllerProvider =
    NotifierProvider<ThemeController, AppThemeVariant?>(ThemeController.new);

const _followSystem = 'system';

class ThemeController extends Notifier<AppThemeVariant?> {
  SharedPreferences get _preferences => ref.read(sharedPreferencesProvider);

  @override
  AppThemeVariant? build() {
    final stored = _preferences.getString(themePreferenceKey);
    // Retired themes and no choice yet follow the phone.
    return availableAppThemeVariants
        .where((variant) => variant.name == stored)
        .firstOrNull;
  }

  Future<void> select(AppThemeVariant? variant) async {
    if (state == variant) return;
    state = variant;
    await _preferences.setString(
      themePreferenceKey,
      variant?.name ?? _followSystem,
    );
  }
}
