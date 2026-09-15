class AppConfig {
  const AppConfig({
    required this.useMocks,
    this.apiUrl = '',
    this.supabaseUrl = '',
    this.supabaseAnonKey = '',
  });

  const AppConfig.fromEnvironment()
    : useMocks = const bool.fromEnvironment(
        'REVOCRED_USE_MOCKS',
        defaultValue: true,
      ),
      apiUrl = const String.fromEnvironment('REVOCRED_API_URL'),
      supabaseUrl = const String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');

  final bool useMocks;
  final String apiUrl;
  final String supabaseUrl;
  final String supabaseAnonKey;

  bool get hasSupabaseConfiguration =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
