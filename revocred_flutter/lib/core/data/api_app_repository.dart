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
  }) : _supabase = supabaseClient,
       _http = httpClient ?? http.Client(),
       _accessTokenProvider =
           accessTokenProvider ??
           (() => supabaseClient?.auth.currentSession?.accessToken),
       _emailProvider =
           emailProvider ?? (() => supabaseClient?.auth.currentUser?.email);

  final String baseUrl;
  final SupabaseClient? _supabase;
  final http.Client _http;
  final String? Function() _accessTokenProvider;
  final String? Function() _emailProvider;

  @override
  bool get isAuthenticated => _supabase?.auth.currentSession != null;

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
  Future<AuthResult> signUp(String email, String password) async {
    if (_supabase == null) return _configurationError();
    try {
      final result = await _supabase.auth.signUp(
        email: email,
        password: password,
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
      '/v1/chat/messages',
      body: {'content': prompt},
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
      '/v1/recommendations',
      body: answers.toRecommendationJson(),
    );
    final data = json['data'];
    if (data is! Map) return null;
    final result = data.cast<String, dynamic>();
    final items = result['items'];
    if (items is! List || items.isEmpty) return null;
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

  AuthResult _configurationError() => const AuthResult(
    success: false,
    message: 'Real mode requires SUPABASE_URL and SUPABASE_ANON_KEY.',
  );

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (baseUrl.trim().isEmpty) {
      throw StateError('Real mode requires REVOCRED_API_URL.');
    }
    final token = _accessTokenProvider();
    if (token == null) throw StateError('Sign in before calling the API.');
    final uri = Uri.parse('${baseUrl.replaceFirst(RegExp(r'/$'), '')}$path');
    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
    };
    final response = switch (method) {
      'GET' => await _http.get(uri, headers: headers),
      'POST' => await _http.post(uri, headers: headers, body: jsonEncode(body)),
      'PUT' => await _http.put(uri, headers: headers, body: jsonEncode(body)),
      'DELETE' => await _http.delete(
        uri,
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
      _ => throw ArgumentError.value(method, 'method'),
    };
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'API request failed (${response.statusCode}): ${response.body}',
      );
    }
    if (response.body.isEmpty) return const {};
    return (jsonDecode(response.body) as Map).cast<String, dynamic>();
  }
}
