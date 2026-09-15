import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

const themePreferenceKey = 'app_theme_variant';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('SharedPreferences must be overridden.'),
);

final themeControllerProvider =
    NotifierProvider<ThemeController, AppThemeVariant>(ThemeController.new);

class ThemeController extends Notifier<AppThemeVariant> {
  SharedPreferences get _preferences => ref.read(sharedPreferencesProvider);

  @override
  AppThemeVariant build() {
    final stored = _preferences.getString(themePreferenceKey);
    return stored == AppThemeVariant.decisionFlowDark.name
        ? AppThemeVariant.decisionFlowDark
        : AppThemeVariant.decisionFlow;
  }

  Future<void> select(AppThemeVariant variant) async {
    if (state == variant) return;
    state = variant;
    await _preferences.setString(themePreferenceKey, variant.name);
  }
}
