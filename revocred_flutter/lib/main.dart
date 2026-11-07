import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/data/api_app_repository.dart';
import 'core/data/auth_timeout_client.dart';
import 'core/data/app_repository.dart';
import 'core/data/mock_app_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  const config = AppConfig.fromEnvironment();
  try {
    if (kReleaseMode && !kIsWeb && config.useMocks) {
      throw StateError('Native release builds require live configuration.');
    }
    config.validate();
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'This build is missing valid service configuration. Please contact the deployment operator.',
            ),
          ),
        ),
      ),
    );
    return;
  }

  SupabaseClient? supabaseClient;
  if (!config.useMocks && config.hasSupabaseConfiguration) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseAnonKey,
      httpClient: AuthTimeoutClient(http.Client()),
    );
    supabaseClient = Supabase.instance.client;
  }

  final AppRepository repository = config.useMocks
      ? MockAppRepository()
      : ApiAppRepository(
          baseUrl: config.apiUrl,
          supabaseClient: supabaseClient,
          authRedirectUrl: config.authRedirectUrl.isNotEmpty
              ? config.authRedirectUrl
              : kIsWeb
              ? '${Uri.base.origin}/'
              : 'com.revocred.app://auth-callback/',
        );

  if (repository is ApiAppRepository) {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      unawaited(repository.reportClientError('flutter'));
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(repository.reportClientError('platform'));
      return false;
    };
  }
  runApp(
    RevoCredBootstrap(
      config: config,
      repository: repository,
      preferences: preferences,
    ),
  );
}
