import 'dart:convert';

class AppConfig {
  const AppConfig({
    required this.useMocks,
    this.apiUrl = '',
    this.supabaseUrl = '',
    this.supabaseAnonKey = '',
    this.production = false,
    this.authRedirectUrl = '',
    this.legalEntity = '',
    this.supportEmail = '',
    this.legalJurisdiction = '',
    this.legalEffectiveDate = '',
    this.privacyUrl = '',
    this.termsUrl = '',
    this.revenueCatIosApiKey = '',
  });

  const AppConfig.fromEnvironment()
    : useMocks = const bool.fromEnvironment(
        'REVOCRED_USE_MOCKS',
        defaultValue: true,
      ),
      apiUrl = const String.fromEnvironment('REVOCRED_API_URL'),
      supabaseUrl = const String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY'),
      production = const bool.fromEnvironment('REVOCRED_PRODUCTION'),
      authRedirectUrl = const String.fromEnvironment(
        'REVOCRED_AUTH_REDIRECT_URL',
      ),
      legalEntity = const String.fromEnvironment('REVOCRED_LEGAL_ENTITY'),
      supportEmail = const String.fromEnvironment('REVOCRED_SUPPORT_EMAIL'),
      legalJurisdiction = const String.fromEnvironment(
        'REVOCRED_LEGAL_JURISDICTION',
      ),
      legalEffectiveDate = const String.fromEnvironment(
        'REVOCRED_LEGAL_EFFECTIVE_DATE',
      ),
      privacyUrl = const String.fromEnvironment('REVOCRED_PRIVACY_URL'),
      termsUrl = const String.fromEnvironment('REVOCRED_TERMS_URL'),
      revenueCatIosApiKey = const String.fromEnvironment(
        'REVENUECAT_IOS_API_KEY',
      );

  final bool useMocks;
  final String apiUrl;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final bool production;
  final String authRedirectUrl;

  final String legalEntity;
  final String supportEmail;
  final String legalJurisdiction;
  final String legalEffectiveDate;
  final String privacyUrl;
  final String termsUrl;

  /// RevenueCat's public iOS SDK key (appl_...). Empty keeps in-app
  /// purchases off; the app then never offers the REVO AI subscription.
  final String revenueCatIosApiKey;

  void validate() {
    if (supabaseAnonKey.startsWith('sb_secret_') ||
        revenueCatIosApiKey.startsWith('sk_')) {
      throw StateError('Secret keys must never be embedded in the client.');
    }
    if (production && useMocks) {
      throw StateError('Production builds must disable mocks.');
    }
    if (!useMocks && (apiUrl.isEmpty || !hasSupabaseConfiguration)) {
      throw StateError('Real mode requires API and Supabase configuration.');
    }
    if (production) {
      if ([
        legalEntity,
        supportEmail,
        legalJurisdiction,
        legalEffectiveDate,
        privacyUrl,
        termsUrl,
      ].any((value) => value.trim().isEmpty)) {
        throw StateError('Production requires complete legal configuration.');
      }
      for (final value in [privacyUrl, termsUrl]) {
        final uri = Uri.tryParse(value);
        if (uri == null ||
            uri.scheme != 'https' ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty) {
          throw StateError('Legal URLs must use HTTPS.');
        }
      }

      for (final value in [apiUrl, supabaseUrl]) {
        final uri = Uri.tryParse(value);
        if (uri == null ||
            uri.scheme != 'https' ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty ||
            const ['localhost', '127.0.0.1', '::1'].contains(uri.host)) {
          throw StateError('Production endpoints must use HTTPS.');
        }
      }
      if (authRedirectUrl.isEmpty) {
        throw StateError('Production requires an auth callback URL.');
      }
      final callback = Uri.tryParse(authRedirectUrl);
      if (callback == null ||
          !const ['https', 'com.revocred.app'].contains(callback.scheme) ||
          callback.host.isEmpty) {
        throw StateError('Invalid production auth callback.');
      }
      if (!supabaseAnonKey.startsWith('sb_publishable_')) {
        try {
          final payload =
              jsonDecode(
                    utf8.decode(
                      base64Url.decode(
                        base64Url.normalize(supabaseAnonKey.split('.')[1]),
                      ),
                    ),
                  )
                  as Map;
          if (payload['role'] != 'anon') throw const FormatException();
        } catch (_) {
          throw StateError(
            'Production requires a public Supabase publishable or anon key.',
          );
        }
      }
    }
  }

  bool get hasSupabaseConfiguration =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
