import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/core/config/app_config.dart';

Map<String, String> _validProductionEnv() => {
  'REVOCRED_USE_MOCKS': 'false',
  'REVOCRED_PRODUCTION': 'true',
  'REVOCRED_API_URL': 'https://api.revocred.com',
  'SUPABASE_URL': 'https://project.supabase.co',
  'SUPABASE_ANON_KEY': 'sb_publishable_example_public_key_123',
  'REVOCRED_AUTH_REDIRECT_URL': 'https://app.revocred.com/',
  'REVOCRED_LEGAL_ENTITY': 'RevoCred Example LLC',
  'REVOCRED_LEGAL_JURISDICTION': 'Delaware, USA',
  'REVOCRED_LEGAL_EFFECTIVE_DATE': '2026-11-23',
  'REVOCRED_SUPPORT_EMAIL': 'support@revocred.com',
  'REVOCRED_PRIVACY_URL': 'https://api.revocred.com/privacy',
  'REVOCRED_TERMS_URL': 'https://api.revocred.com/terms',
  'REVOCRED_SUPPORT_URL': 'https://api.revocred.com/support',
};

void main() {
  test('AppConfig.fromMap validates complete production legal defines', () {
    final config = AppConfig.fromMap(_validProductionEnv());
    expect(config.validate, returnsNormally);
    expect(config.legalEntity, 'RevoCred Example LLC');
    expect(config.legalJurisdiction, 'Delaware, USA');
    expect(config.legalEffectiveDate, '2026-11-23');
    expect(config.supportEmail, 'support@revocred.com');
    expect(config.privacyUrl, 'https://api.revocred.com/privacy');
    expect(config.termsUrl, 'https://api.revocred.com/terms');
    expect(config.supportUrl, 'https://api.revocred.com/support');
  });

  test(
    'AppConfig.fromMap defaults hosted legal URLs and support email when omitted',
    () {
      final env = _validProductionEnv()
        ..remove('REVOCRED_SUPPORT_EMAIL')
        ..remove('REVOCRED_PRIVACY_URL')
        ..remove('REVOCRED_TERMS_URL')
        ..remove('REVOCRED_SUPPORT_URL');
      final config = AppConfig.fromMap(env);
      expect(config.validate, returnsNormally);
      expect(config.supportEmail, defaultSupportEmail);
      expect(config.privacyUrl, defaultPrivacyUrl);
      expect(config.termsUrl, defaultTermsUrl);
      expect(config.supportUrl, defaultSupportUrl);
    },
  );

  test(
    'AppConfig.fromMap rejects missing or placeholder production legal defines',
    () {
      for (final key in [
        'REVOCRED_LEGAL_ENTITY',
        'REVOCRED_LEGAL_JURISDICTION',
        'REVOCRED_LEGAL_EFFECTIVE_DATE',
        'REVOCRED_SUPPORT_EMAIL',
        'REVOCRED_PRIVACY_URL',
        'REVOCRED_TERMS_URL',
        'REVOCRED_SUPPORT_URL',
      ]) {
        final emptyEnv = _validProductionEnv()..[key] = '';
        expect(
          AppConfig.fromMap(emptyEnv).validate,
          throwsStateError,
          reason: 'Expected empty $key to fail production validation',
        );
      }

      for (final placeholder in [
        '{{LEGAL_ENTITY}}',
        '[[COMPANY LEGAL NAME]]',
      ]) {
        final placeholderEnv = _validProductionEnv()
          ..['REVOCRED_LEGAL_ENTITY'] = placeholder;
        expect(
          AppConfig.fromMap(placeholderEnv).validate,
          throwsStateError,
          reason: 'Expected placeholder $placeholder to fail validation',
        );
      }
    },
  );

  test('AppConfig.fromMap rejects non-HTTPS legal URLs in production', () {
    for (final key in [
      'REVOCRED_PRIVACY_URL',
      'REVOCRED_TERMS_URL',
      'REVOCRED_SUPPORT_URL',
    ]) {
      final env = _validProductionEnv()..[key] = 'http://api.revocred.com/page';
      expect(
        AppConfig.fromMap(env).validate,
        throwsStateError,
        reason: 'Expected non-HTTPS $key to fail production validation',
      );
    }
  });

  test(
    'AppConfig.fromMap allows non-production live preview without legal entity',
    () {
      final env = {
        'REVOCRED_USE_MOCKS': 'false',
        'REVOCRED_PRODUCTION': 'false',
        'REVOCRED_API_URL': 'https://api.revocred.com',
        'SUPABASE_URL': 'https://project.supabase.co',
        'SUPABASE_ANON_KEY': 'sb_publishable_example_public_key_123',
        'REVOCRED_AUTH_REDIRECT_URL': 'https://revocred-pwa.vercel.app/',
      };
      expect(AppConfig.fromMap(env).validate, returnsNormally);
    },
  );
}
