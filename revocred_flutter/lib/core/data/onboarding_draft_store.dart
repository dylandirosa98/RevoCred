import 'dart:convert';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_models.dart';

final onboardingDraftStoreProvider = Provider<OnboardingDraftStore>(
  (ref) => OnboardingDraftStore(),
);

// A short-lived, device-local draft survives the email-confirmation round trip.
// It is imported only into the explicitly chosen email's empty account.
class OnboardingDraftStore {
  OnboardingDraftStore([this.preferences]);
  final SharedPreferences? preferences;
  String? _memory;
  static const _key = 'onboarding_draft_v1';
  Map<String, dynamic>? get _value {
    try {
      final raw = preferences?.getString(_key) ?? _memory;
      if (raw == null) return null;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final saved = DateTime.parse(data['saved_at'] as String);
      if (DateTime.now().difference(saved) > const Duration(days: 1)) {
        unawaited(clear());
        return null;
      }
      return data;
    } catch (_) {
      return null;
    }
  }

  QuestionnaireAnswers? get answers {
    final data = _value;
    if (data == null) return null;
    final answers = parseHandoff(data);
    if (answers == null) unawaited(clear());
    return answers;
  }

  /// The draft as it rides along in the new account's sign-up metadata, so a
  /// confirmation link opened in another browser or device still finds it.
  Map<String, dynamic>? get handoff {
    final data = _value;
    if (data == null || data['answers'] is! Map) return null;
    return {
      'answers': data['answers'],
      'card_labels': data['card_labels'] ?? const <String, dynamic>{},
      if (data['display_name'] != null) 'display_name': data['display_name'],
    };
  }

  /// Reads a draft or a sign-up handoff. Returns null when it is malformed.
  static QuestionnaireAnswers? parseHandoff(Map<dynamic, dynamic> data) {
    try {
      return QuestionnaireAnswers.fromRecommendationJson(
        {
          ...(data['answers'] as Map).cast<String, dynamic>(),
          if (data['display_name'] != null)
            'display_name': data['display_name'],
        },
        cardLabels:
            (data['card_labels'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
    } catch (_) {
      return null;
    }
  }

  String? get email => _value?['email'] as String?;
  String? get displayName => _value?['display_name'] as String?;

  Future<void> saveName(String name) async {
    final value = _value;
    if (value == null) return;
    value['display_name'] = name.trim();
    _memory = jsonEncode(value);
    await preferences?.setString(_key, _memory!);
  }

  Future<void> save(QuestionnaireAnswers answers, {String? email}) async {
    _memory = jsonEncode({
      'saved_at': DateTime.now().toUtc().toIso8601String(),
      'answers': answers.toRecommendationJson(),
      'card_labels': {
        for (final card in answers.addedCards)
          card.referenceId: {'name': card.cardName, 'issuer': card.issuer},
      },
      'email': email?.trim().toLowerCase(),
    });
    await preferences?.setString(_key, _memory!);
  }

  Future<void> bind(String email) async {
    final value = _value;
    if (value == null) return;
    final normalized = email.trim().toLowerCase();
    // A confirmation handoff belongs to its original account, not whichever
    // account next signs in on this device.
    if (value['email'] != null && value['email'] != normalized) return;
    value['email'] = normalized;
    _memory = jsonEncode(value);
    await preferences?.setString(_key, _memory!);
  }

  Future<void> clear() async {
    _memory = null;
    await preferences?.remove(_key);
  }
}
