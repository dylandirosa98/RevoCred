import 'dart:io';
import 'package:revocred_flutter/core/config/app_config.dart';

void main() {
  final env = Platform.environment;
  final config = AppConfig(
    useMocks: env['REVOCRED_USE_MOCKS'] != 'false',
    production: env['REVOCRED_PRODUCTION'] == 'true',
    apiUrl: env['REVOCRED_API_URL'] ?? '',
    supabaseUrl: env['SUPABASE_URL'] ?? '',
    supabaseAnonKey: env['SUPABASE_ANON_KEY'] ?? '',
    authRedirectUrl: env['REVOCRED_AUTH_REDIRECT_URL'] ?? '',
  );
  try {
    config.validate();
  } catch (_) {
    stderr.writeln(
      'Invalid build configuration. Check public endpoints, auth callback, mock flag and public Supabase key.',
    );
    exit(1);
  }
}
