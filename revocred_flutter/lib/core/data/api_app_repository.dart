import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_models.dart';
import '../models/chat_disclosure.dart';
import '../models/chat_errors.dart';
import 'app_repository.dart';

class ApiAppRepository implements AppRepository {
  ApiAppRepository({
    required this.baseUrl,
    required SupabaseClient? supabaseClient,
    http.Client? httpClient,
    String? Function()? accessTokenProvider,
    String? Function()? emailProvider,
    this.authRedirectUrl,
  }) : _supabase = supabaseClient,
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

  bool _passwordRecovery = false;
  int _authGeneration = 0;

  @override
  bool get isPasswordRecovery => isAuthenticated && _passwordRecovery;
  @override
  Stream<AccountSession> get sessionChanges =>
      _supabase?.auth.onAuthStateChange.map((state) {
        if (state.event == AuthChangeEvent.passwordRecovery) {
          _passwordRecovery = true;
        }
        if (state.event == AuthChangeEvent.signedOut ||
            state.event == AuthChangeEvent.signedIn) {
          _passwordRecovery = false;
        }
        return AccountSession(
          authenticated: state.session != null,
          userId: state.session?.user.id,
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
    final generation = ++_authGeneration;
    try {
      final result = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (generation != _authGeneration) {
        await _discardStaleAuth(result);
        return const AuthResult(
          success: false,
          message: 'Sign-in cancelled. Please try again.',
        );
      }
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
    bool notificationsOptIn = false,
  }) async {
    if (_supabase == null) return _configurationError();
    final generation = ++_authGeneration;
    try {
      final result = await _supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: authRedirectUrl,
        data: {
          'display_name': displayName.trim(),
          'email_notifications_opt_in': notificationsOptIn,
          'notification_preference_recorded_at': DateTime.now()
              .toUtc()
              .toIso8601String(),
        },
      );
      if (generation != _authGeneration) {
        await _discardStaleAuth(result);
        return const AuthResult(
          success: false,
          message: 'Sign-up cancelled. Please sign in to continue.',
        );
      }
      if (result.session != null &&
          result.session?.accessToken == _accessTokenProvider() &&
          displayName.trim().isNotEmpty) {
        // Sign-up collects the name, so persist it as soon as there is a
        // session to authenticate the write with.
        try {
          await _request(
            'PUT',
            '/v1/profile/display-name',
            body: {'display_name': displayName.trim()},
          );
        } catch (_) {
          // Auth already created the account. The name is also in Supabase
          // metadata; an optional API write must not invite another signup.
        }
      }
      return AuthResult(
        success: true,
        message: result.session == null
            ? 'Check your email to confirm the account, then sign in.'
            : 'Account created.',
      );
    } on AuthException catch (error) {
      if (error.code == 'user_already_exists' || error.code == 'email_exists') {
        // Match GoTrue's obfuscated duplicate signup response. Never turn its
        // privacy-preserving flow into an account-enumeration message.
        return const AuthResult(
          success: true,
          message: 'Check your email to confirm your account, then sign in.',
        );
      }
      return AuthResult(success: false, message: error.message);
    }
  }

  Future<void> _discardStaleAuth(AuthResponse result) async {
    if (result.session != null &&
        result.session?.accessToken ==
            _supabase?.auth.currentSession?.accessToken) {
      await _signOutLocal();
    }
  }

  @override
  Future<void> signOut() async {
    _authGeneration++;
    await _signOutLocal();
  }

  Future<void> _signOutLocal() async {
    try {
      await _supabase?.auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      // GoTrue clears the local session before revoking it over the network.
      // A failed remote revoke must not strand the app on a private screen.
      if (_supabase?.auth.currentSession != null) rethrow;
    }
  }

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
      // Supabase stores the name at account creation. Use it only when the API
      // profile has no name yet, such as during the first post-sign-up refresh.
      displayNameFallback:
          _supabase?.auth.currentUser?.userMetadata?['display_name']
              ?.toString() ??
          '',
    );
  }

  @override
  Future<PurchaseGuide> loadPurchaseGuide({
    String travelMode = 'general',
    bool capsAvailable = true,
  }) async {
    final query = Uri(
      queryParameters: {
        'travel_mode': travelMode,
        'caps_available': '$capsAvailable',
      },
    ).query;
    final response = await _request('GET', '/v1/purchase-guide?$query');
    return PurchaseGuide.fromJson(
      (response['data'] as Map).cast<String, dynamic>(),
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
        'benefits': [
          card.termsUnknown
              ? 'Terms not supplied; excluded from scoring'
              : 'User-supplied terms',
        ],
        'terms_unknown': card.termsUnknown,
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
  Future<ChatDisclosure> loadChatDisclosure() async {
    final json = await _request(
      'GET',
      '/v1/public/chat-disclosure',
      anonymous: true,
    );
    final data = json['data'];
    if (data is! Map) {
      throw const FormatException('AI sharing notice is unavailable.');
    }
    return ChatDisclosure.fromJson(data.cast<String, dynamic>());
  }

  @override
  Future<ChatMessage> sendMessage(
    String prompt, {
    String? aiConsentVersion,
  }) async {
    final json = await _request(
      'POST',
      _accessTokenProvider() == null
          ? '/v1/public/explain'
          : '/v1/chat/messages',
      body: {'content': prompt, 'ai_consent_version': ?aiConsentVersion},
      anonymous: _accessTokenProvider() == null,
      // The server allows chat 45 seconds, so wait a little longer than that.
      timeout: const Duration(seconds: 55),
    );
    final payload = json['data'];
    if (payload is! List || payload.isEmpty) {
      throw const FormatException('Chat API returned no messages.');
    }
    final assistant = payload.last;
    return ChatMessage.fromJson((assistant as Map).cast<String, dynamic>());
  }

  /// Streams progress as server-sent events; an older server or a buffering
  /// browser client answers with plain JSON, which is handled the same way.
  @override
  Stream<ChatStreamEvent> streamMessage(
    String prompt, {
    String? aiConsentVersion,
  }) {
    final abort = Completer<void>();
    void cancel() {
      if (!abort.isCompleted) abort.complete();
    }

    final events = StreamController<ChatStreamEvent>(onCancel: cancel);
    Future<void> run() async {
      final token = _accessTokenProvider();
      final request = http.AbortableRequest(
        'POST',
        _chatUri(token == null ? '/v1/public/explain' : '/v1/chat/messages'),
        abortTrigger: abort.future,
      );
      request.headers.addAll({
        'Authorization': ?(token == null ? null : 'Bearer $token'),
        'Accept': 'text/event-stream, application/json',
        'Content-Type': 'application/json',
      });
      request.body = jsonEncode({
        'content': prompt,
        'ai_consent_version': ?aiConsentVersion,
      });
      // The server answers within 45 seconds; keep-alives arrive every 10.
      final response = await _http
          .send(request)
          .timeout(const Duration(seconds: 55));
      if (response.statusCode == 401 && token != null) {
        if (token == _accessTokenProvider()) await signOut();
        throw const SessionExpiredException();
      }
      final type = response.headers['content-type'] ?? '';
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          type.startsWith('text/event-stream')) {
        final lines = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .timeout(const Duration(seconds: 30));
        await for (final event in parseChatEvents(lines)) {
          if (events.isClosed) return;
          events.add(event);
        }
        return;
      }
      final body = await response.stream.bytesToString().timeout(
        const Duration(seconds: 55),
      );
      Object? json;
      try {
        json = body.isEmpty ? null : jsonDecode(body);
      } on FormatException {
        json = null;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw chatErrorFromJson(json, response.statusCode);
      }
      events.add(ChatDoneEvent.fromEnvelope(json));
    }

    run()
        .catchError((Object error, StackTrace stack) {
          // A cancelled request has no listener left to tell.
          if (!abort.isCompleted && !events.isClosed) {
            events.addError(
              error is TimeoutException
                  ? const ChatSendException(
                      'timeout',
                      'REVO took too long to respond. Please try again.',
                    )
                  : error,
              stack,
            );
          }
        })
        .whenComplete(() {
          if (!events.isClosed) events.close();
        });
    return events.stream;
  }

  @override
  Future<ChatConsentStatus> loadChatConsent() async =>
      ChatConsentStatus.fromJson(await _chatRequest('GET', '/v1/chat/consent'));

  @override
  Future<ChatConsentStatus> grantChatConsent(String version) async =>
      ChatConsentStatus.fromJson(
        await _chatRequest('PUT', '/v1/chat/consent', {'version': version}),
      );

  @override
  Future<void> revokeChatConsent() async {
    await _chatRequest('DELETE', '/v1/chat/consent');
  }

  @override
  Future<void> clearChatHistory() async {
    await _chatRequest('DELETE', '/v1/chat/messages');
  }

  @override
  Future<void> sendChatFeedback(
    String messageId, {
    required String rating,
    String? reason,
  }) async {
    final trimmed = reason?.trim();
    await _chatRequest(
      'POST',
      '/v1/chat/messages/${Uri.encodeComponent(messageId)}/feedback',
      {
        'rating': rating,
        if (trimmed != null && trimmed.isNotEmpty) 'reason': trimmed,
      },
    );
  }

  Uri _chatUri(String path) {
    if (baseUrl.trim().isEmpty) {
      throw StateError('Real mode requires REVOCRED_API_URL.');
    }
    return Uri.parse('${baseUrl.replaceFirst(RegExp(r'/$'), '')}$path');
  }

  /// Signed-in chat calls whose error codes the UI acts on, so failures are
  /// [ChatSendException]s rather than plain messages.
  Future<Object?> _chatRequest(
    String method,
    String path, [
    Map<String, Object?>? body,
  ]) async {
    final token = _accessTokenProvider();
    if (token == null) {
      throw const ChatSendException(
        'account_required',
        'Create an account to let REVO discuss your personal plan.',
      );
    }
    final request = http.Request(method, _chatUri(path))
      ..headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        if (body != null) 'Content-Type': 'application/json',
      });
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await _http.send(request).timeout(const Duration(seconds: 20)),
    );
    if (response.statusCode == 401) {
      if (token == _accessTokenProvider()) await signOut();
      throw const SessionExpiredException();
    }
    Object? json;
    try {
      json = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      json = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw chatErrorFromJson(json, response.statusCode);
    }
    return json;
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
    Duration timeout = const Duration(seconds: 35),
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
    }.timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) {
        if (!anonymous && token == _accessTokenProvider()) {
          await signOut();
        }
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
