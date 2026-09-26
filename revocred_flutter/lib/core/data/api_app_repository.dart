import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_models.dart';
import 'app_repository.dart';

class ApiAppRepository implements AppRepository {
  ApiAppRepository({
    required this.baseUrl,
    required SupabaseClient? supabaseClient,
    http.Client? httpClient,
    String? Function()? accessTokenProvider,
    String? Function()? emailProvider,
    this.authRedirectUrl,
    bool initialPasswordRecovery = false,
  }) : _passwordRecovery = initialPasswordRecovery,
       _supabase = supabaseClient,
       _http = httpClient ?? http.Client(),
       _accessTokenProvider =
           accessTokenProvider ??
           (() => supabaseClient?.auth.currentSession?.accessToken),
       _emailProvider =
           emailProvider ?? (() => supabaseClient?.auth.currentUser?.email);

  final String baseUrl;
  final String? authRedirectUrl;
  final SupabaseClient? _supabase;
  final http.Client _http;
  final String? Function() _accessTokenProvider;
  final String? Function() _emailProvider;
  DateTime? _lastErrorReport;
  Future<void> reportClientError(String kind) async {
    if (!isAuthenticated) return;
    final now = DateTime.now();
    if (_lastErrorReport != null &&
        now.difference(_lastErrorReport!) < const Duration(minutes: 1)) {
      return;
    }
    _lastErrorReport = now;
    try {
      await _request('POST', '/v1/client-errors', body: {'kind': kind});
    } catch (_) {
      /* Reporting must never break the app. */
    }
  }

  bool _passwordRecovery;

  @override
  bool get isPasswordRecovery => _passwordRecovery;
  @override
  Stream<AccountSession> get sessionChanges =>
      _supabase?.auth.onAuthStateChange.map((state) {
        if (state.event == AuthChangeEvent.passwordRecovery) {
          _passwordRecovery = true;
        }
        if (state.event == AuthChangeEvent.signedOut) _passwordRecovery = false;
        return AccountSession(
          authenticated: state.session != null,
          passwordRecovery: _passwordRecovery,
        );
      }) ??
      const Stream.empty();

  SupabaseClient get _authClient =>
      _supabase ?? (throw StateError('Authentication is not configured.'));
  @override
  Future<void> requestPasswordReset(String email) =>
      _authClient.auth.resetPasswordForEmail(
        email,
        redirectTo: authRedirectUrl == null
            ? null
            : Uri.parse(authRedirectUrl!)
                  .replace(
                    queryParameters: {
                      ...Uri.parse(authRedirectUrl!).queryParameters,
                      'recovery': 'true',
                    },
                  )
                  .toString(),
      );
  @override
  Future<void> resendVerification(String email) async =>
      _authClient.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: authRedirectUrl,
      );
  @override
  Future<void> updatePassword(String password) async {
    await _authClient.auth.updateUser(UserAttributes(password: password));
    _passwordRecovery = false;
  }

  @override
  Future<void> updateEmail(String email) async => _authClient.auth.updateUser(
    UserAttributes(email: email),
    emailRedirectTo: authRedirectUrl,
  );
  @override
  Future<String> exportAccount() async => const JsonEncoder.withIndent(
    '  ',
  ).convert(await _request('GET', '/v1/account/export'));
  @override
  Future<void> deleteAccount(String password) async {
    final email = _emailProvider();
    if (email == null) throw const SessionExpiredException();
    await _authClient.auth.signInWithPassword(email: email, password: password);
    await _request('DELETE', '/v1/account');
    await _authClient.auth.signOut(scope: SignOutScope.local);
  }

  @override
  bool get isAuthenticated => _supabase?.auth.currentSession != null;
  @override
  String? get accountEmail => _emailProvider();

  @override
  Future<List<CreditCard>> loadCatalog() async {
    final json = await _request('GET', '/v1/public/cards', anonymous: true);
    return (json['data'] as List)
        .map(
          (item) =>
              CreditCard.fromApiJson((item as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  @override
  Future<List<ReferenceCard>> searchCardIndex(String query) async {
    final uri =
        Uri.parse(
          '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/v1/public/card-index',
        ).replace(
          queryParameters: {if (query.trim().isNotEmpty) 'q': query.trim()},
        );
    final json = await _request(
      'GET',
      uri.toString(),
      absolute: true,
      anonymous: true,
    );
    return (json['data'] as List)
        .map(
          (item) =>
              ReferenceCard.fromJson((item as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  @override
  Future<AppData> previewQuestionnaire(QuestionnaireAnswers answers) async {
    final json = await _request(
      'POST',
      '/v1/public/plan',
      anonymous: true,
      body: answers.toRecommendationJson(),
    );
    return AppData.fromApiJson(
      (json['data'] as Map).cast<String, dynamic>(),
      messages: const [],
      email: '',
    ).copyWith(isPersonalPreview: true);
  }

  @override
  Future<AuthResult> signIn(String email, String password) async {
    if (_supabase == null) return _configurationError();
    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);
      return const AuthResult(success: true);
    } on AuthException catch (error) {
      return AuthResult(success: false, message: error.message);
    }
  }

  @override
  Future<AuthResult> signUp(
    String email,
    String password, {
    String displayName = '',
  }) async {
    if (_supabase == null) return _configurationError();
    try {
      final result = await _supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: authRedirectUrl,
      );
      return AuthResult(
        success: true,
        message: result.session == null
            ? 'Check your email to confirm the account, then sign in.'
            : 'Account created.',
      );
    } on AuthException catch (error) {
      return AuthResult(success: false, message: error.message);
    }
  }

  @override
  Future<void> signOut() async => _supabase?.auth.signOut();

  @override
  Future<AppData> loadAppData() async {
    final responses = await Future.wait([
      _request('GET', '/v1/bootstrap'),
      _request('GET', '/v1/chat/messages?limit=100'),
    ]);
    final json = responses[0];
    final payload = json['data'] is Map ? json['data'] as Map : json;
    final messagesPayload = responses[1]['data'];
    return AppData.fromApiJson(
      payload.cast<String, dynamic>(),
      messages: messagesPayload is List ? messagesPayload : const [],
      email: _emailProvider() ?? '',
    );
  }

  @override
  Future<void> addCard(String cardId) async {
    await _request(
      'POST',
      '/v1/wallet',
      body: {'catalog_card_id': cardId, 'nickname': '', 'status': 'active'},
    );
  }

  @override
  Future<void> addCustomCard(CustomCardDraft card) async {
    await _request(
      'POST',
      '/v1/wallet/custom',
      body: {
        'name': card.name,
        'issuer': card.issuer,
        'network': card.network,
        'annual_fee_cents': card.annualFeeDollars * 100,
        'reward_rates': card.rates,
        'transferable_points': card.transferablePoints,
        'best_use': card.bestUse,
        'benefits': ['User-supplied terms'],
      },
    );
  }

  @override
  Future<void> removeCard(String walletCardId) async {
    await _request(
      'DELETE',
      '/v1/wallet',
      body: {'wallet_card_id': walletCardId},
    );
  }

  @override
  Future<ChatMessage> sendMessage(String prompt) async {
    final json = await _request(
      'POST',
      _accessTokenProvider() == null
          ? '/v1/public/explain'
          : '/v1/chat/messages',
      body: {'content': prompt},
      anonymous: _accessTokenProvider() == null,
    );
    final payload = json['data'];
    if (payload is! List || payload.isEmpty) {
      throw const FormatException('Chat API returned no messages.');
    }
    final assistant = payload.last;
    return ChatMessage.fromJson((assistant as Map).cast<String, dynamic>());
  }

  @override
  Future<DemoRecommendation?> saveQuestionnaire(
    QuestionnaireAnswers answers,
  ) async {
    final json = await _request(
      'POST',
      '/v1/onboarding',
      body: answers.toRecommendationJson(),
    );
    final data = json['data'];
    if (data is! Map) {
      throw const FormatException('Invalid recommendation response.');
    }
    final result = data.cast<String, dynamic>();
    final items = result['items'];
    if (items is! List) {
      throw const FormatException('Invalid recommendation items.');
    }
    if (items.isEmpty) return null;
    final top = (items.first as Map).cast<String, dynamic>();
    return DemoRecommendation(
      cardId: top['card_id'].toString(),
      cardName: top['card_name'].toString(),
      estimatedYearlyValue:
          ((top['ongoing_annual_estimate_cents'] as num?)?.round() ?? 0) ~/ 100,
      reasons: (top['reasons'] as List? ?? const [])
          .map((reason) => reason.toString())
          .toList(),
      formula:
          'Server engine ${result['engine_version'] ?? 'v1'} using dataset ${result['dataset_version'] ?? 'unknown'}.',
    );
  }

  @override
  Future<void> updateDisplayName(String name) async {
    await _request(
      'PUT',
      '/v1/profile/display-name',
      body: {'display_name': name.trim()},
    );
  }

  @override
  Future<void> switchStrategy(String code) async {
    await _request('PUT', '/v1/strategy', body: {'strategy_code': code});
  }

  AuthResult _configurationError() => const AuthResult(
    success: false,
    message: 'Real mode requires SUPABASE_URL and SUPABASE_ANON_KEY.',
  );

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool anonymous = false,
    bool absolute = false,
  }) async {
    if (baseUrl.trim().isEmpty) {
      throw StateError('Real mode requires REVOCRED_API_URL.');
    }
    final token = _accessTokenProvider();
    if (!anonymous && token == null) {
      throw StateError('Sign in before calling the API.');
    }
    final uri = absolute
        ? Uri.parse(path)
        : Uri.parse('${baseUrl.replaceFirst(RegExp(r'/$'), '')}$path');
    final headers = {
      if (!anonymous && token != null) 'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
    };
    final response = await switch (method) {
      'GET' => _http.get(uri, headers: headers),
      'POST' => _http.post(uri, headers: headers, body: jsonEncode(body)),
      'PUT' => _http.put(uri, headers: headers, body: jsonEncode(body)),
      'DELETE' => _http.delete(
        uri,
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
      _ => throw ArgumentError.value(method, 'method'),
    }.timeout(const Duration(seconds: 35));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) {
        await _supabase?.auth.signOut(scope: SignOutScope.local);
        throw const SessionExpiredException();
      }
      String message = 'The request could not be completed. Please try again.';
      try {
        final error = (jsonDecode(response.body) as Map)['error'] as Map?;
        message = error?['message']?.toString() ?? message;
      } on FormatException {
        /* Proxy errors need not be JSON. */
      }
      throw StateError(message);
    }
    if (response.body.isEmpty) return const {};
    return (jsonDecode(response.body) as Map).cast<String, dynamic>();
  }
}
