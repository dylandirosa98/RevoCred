import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/data/api_app_repository.dart';
import 'core/data/app_repository.dart';
import 'core/data/mock_app_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  const config = AppConfig.fromEnvironment();

  SupabaseClient? supabaseClient;
  if (!config.useMocks && config.hasSupabaseConfiguration) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseAnonKey,
    );
    supabaseClient = Supabase.instance.client;
  }

  final AppRepository repository = config.useMocks
      ? MockAppRepository()
      : ApiAppRepository(
          baseUrl: config.apiUrl,
          supabaseClient: supabaseClient,
        );

  runApp(
    RevoCredBootstrap(
      config: config,
      repository: repository,
      preferences: preferences,
    ),
  );
}
