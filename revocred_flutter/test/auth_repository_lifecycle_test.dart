import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:revocred_flutter/core/data/auth_timeout_client.dart';
import 'package:revocred_flutter/core/data/api_app_repository.dart';
import 'package:revocred_flutter/core/data/app_repository.dart';

Map<String, dynamic> user(String id) => {
  'id': id,
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': '$id@example.test',
  'created_at': '2026-01-01T00:00:00Z',
  'app_metadata': {},
  'user_metadata': {},
};
Map<String, dynamic> session(String id) => {
  'access_token': 'token-$id',
  'refresh_token': 'refresh-$id',
  'token_type': 'bearer',
  'expires_in': 3600,
  'user': user(id),
};
SupabaseClient authClient(
  Future<http.Response> Function(http.Request) handle,
) => SupabaseClient(
  'https://auth.example.test',
  'public-test-key',
  authOptions: const AuthClientOptions(
    autoRefreshToken: false,
    authFlowType: AuthFlowType.implicit,
  ),
  httpClient: MockClient(handle),
);
http.Response jsonResponse(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);

class MemoryPkce extends GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}

void main() {
  test(
    'signin finishing after logout cannot restore the old session',
    () async {
      final response = Completer<http.Response>();
      final auth = authClient(
        (request) async => request.url.path.endsWith('/logout')
            ? http.Response('', 204)
            : response.future,
      );
      addTearDown(auth.dispose);
      final repo = ApiAppRepository(
        baseUrl: 'https://api.example.test',
        supabaseClient: auth,
      );
      final pending = repo.signIn('a@example.test', 'password');
      await Future<void>.delayed(Duration.zero);
      await repo.signOut();
      response.complete(jsonResponse(session('a')));
      final result = await pending;
      expect(result.success, isFalse);
      expect(repo.isAuthenticated, isFalse);
    },
  );
  for (final recovery in [true, false]) {
    for (final cold in [true, false]) {
      test(
        'PKCE ${recovery ? "recovery" : "confirmation"} ${cold ? "cold" : "warm"} session handoff',
        () async {
          final storage = MemoryPkce();
          SupabaseClient createAuth() => SupabaseClient(
            'https://auth.example.test',
            'public-test-key',
            authOptions: AuthClientOptions(
              autoRefreshToken: false,
              pkceAsyncStorage: storage,
            ),
            httpClient: MockClient((request) async {
              if (request.url.path.endsWith('/token')) {
                expect(request.url.queryParameters['grant_type'], 'pkce');
                expect(jsonDecode(request.body)['code_verifier'], isNotEmpty);
                return jsonResponse(session('a'));
              }
              return jsonResponse(
                request.url.path.endsWith('/signup') ? user('a') : {},
              );
            }),
          );
          var auth = createAuth();
          final first = ApiAppRepository(
            baseUrl: 'https://api.example.test',
            supabaseClient: auth,
          );
          if (recovery) {
            await first.requestPasswordReset('a@example.test');
          } else {
            await first.signUp('a@example.test', 'password123');
          }
          if (cold) {
            await auth.dispose();
            auth = createAuth();
          }
          addTearDown(auth.dispose);
          final repo = cold
              ? ApiAppRepository(
                  baseUrl: 'https://api.example.test',
                  supabaseClient: auth,
                )
              : first;
          final events = <AccountSession>[];
          StreamSubscription<AccountSession>? sub;
          if (!cold) sub = repo.sessionChanges.listen(events.add);
          await auth.auth.getSessionFromUrl(
            Uri.parse(
              'com.revocred.app://auth-callback/?code=verified-test-code',
            ),
          );
          sub ??= repo.sessionChanges.listen(events.add);
          await Future<void>.delayed(Duration.zero);
          expect(events.last.authenticated, isTrue);
          expect(events.last.passwordRecovery, recovery);
          expect(storage.values, isEmpty);
          await sub.cancel();
        },
      );
    }
  }
  test('explicit duplicate signup error also preserves privacy', () async {
    final auth = authClient(
      (_) async => jsonResponse({
        'msg': 'User already registered',
        'error_code': 'user_already_exists',
      }, 422),
    );
    addTearDown(auth.dispose);
    final repo = ApiAppRepository(
      baseUrl: 'https://api.example.test',
      supabaseClient: auth,
    );
    final result = await repo.signUp('a@example.test', 'password123');
    expect(result.success, isTrue);
    expect(
      result.message,
      'Check your email to confirm your account, then sign in.',
    );
    expect(repo.isAuthenticated, isFalse);
  });

  test('normal signin exits a prior recovery routing state', () async {
    final auth = authClient(
      (request) async => request.url.path.endsWith('/user')
          ? jsonResponse(user('a'))
          : jsonResponse(session('b')),
    );
    addTearDown(auth.dispose);
    final repo = ApiAppRepository(
      baseUrl: 'https://api.example.test',
      supabaseClient: auth,
    );
    final events = <AccountSession>[];
    final sub = repo.sessionChanges.listen(events.add);
    addTearDown(sub.cancel);
    await auth.auth.getSessionFromUrl(
      Uri.parse(
        'com.revocred.app://auth-callback/#access_token=token-a&refresh_token=refresh-a&expires_in=3600&token_type=bearer&type=recovery',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(events.last.passwordRecovery, isTrue);
    await repo.signIn('b@example.test', 'password');
    await Future<void>.delayed(Duration.zero);
    expect(events.last.passwordRecovery, isFalse);
  });

  test('unverified cold recovery hint never activates recovery alone', () async {
    final auth = authClient(
      (_) async => jsonResponse({'msg': 'Invalid JWT'}, 401),
    );
    addTearDown(auth.dispose);
    final repo = ApiAppRepository(
      baseUrl: 'https://api.example.test',
      supabaseClient: auth,
    );
    await expectLater(
      auth.auth.getSessionFromUrl(
        Uri.parse(
          'com.revocred.app://auth-callback/?recovery=true#access_token=invalid&refresh_token=invalid&expires_in=3600&token_type=bearer&type=recovery',
        ),
      ),
      throwsA(isA<AuthException>()),
    );
    expect(repo.isPasswordRecovery, isFalse);
    expect(repo.isAuthenticated, isFalse);
  });

  test(
    'auth transport timeout cannot later install successful session',
    () async {
      final response = Completer<http.Response>();
      final client = AuthTimeoutClient(
        MockClient((_) => response.future),
        timeout: const Duration(milliseconds: 10),
      );
      final auth = SupabaseClient(
        'https://auth.example.test',
        'public-test-key',
        authOptions: const AuthClientOptions(
          autoRefreshToken: false,
          authFlowType: AuthFlowType.implicit,
        ),
        httpClient: client,
      );
      addTearDown(auth.dispose);
      final repo = ApiAppRepository(
        baseUrl: 'https://api.example.test',
        supabaseClient: auth,
      );
      final result = await repo.signIn('a@example.test', 'password');
      expect(result.success, isFalse);
      response.complete(jsonResponse(session('a')));
      await Future<void>.delayed(Duration.zero);
      expect(repo.isAuthenticated, isFalse);
    },
  );
  for (final cold in [false, true]) {
    test(
      '${cold ? "cold" : "warm"} recovery link uses SDK recovery event',
      () async {
        final auth = authClient(
          (request) async => request.url.path.endsWith('/user')
              ? jsonResponse(user('a'))
              : jsonResponse(session('a')),
        );
        addTearDown(auth.dispose);
        final repo = ApiAppRepository(
          baseUrl: 'https://api.example.test',
          supabaseClient: auth,
        );
        final events = <AccountSession>[];
        StreamSubscription<AccountSession>? sub;
        if (!cold) sub = repo.sessionChanges.listen(events.add);
        await auth.auth.getSessionFromUrl(
          Uri.parse(
            'com.revocred.app://auth-callback/#access_token=token-a&refresh_token=refresh-a&expires_in=3600&token_type=bearer&type=recovery',
          ),
        );
        sub ??= repo.sessionChanges.listen(events.add);
        await Future<void>.delayed(Duration.zero);
        expect(events.last.passwordRecovery, isTrue);
        expect(events.last.authenticated, isTrue);
        await repo.updatePassword('new-password123');
        expect(repo.isPasswordRecovery, isFalse);
        await sub.cancel();
      },
    );
    test(
      '${cold ? "cold" : "warm"} confirmation link authenticates without recovery',
      () async {
        final auth = authClient((_) async => jsonResponse(user('a')));
        addTearDown(auth.dispose);
        final repo = ApiAppRepository(
          baseUrl: 'https://api.example.test',
          supabaseClient: auth,
        );
        final events = <AccountSession>[];
        StreamSubscription<AccountSession>? sub;
        if (!cold) sub = repo.sessionChanges.listen(events.add);
        await auth.auth.getSessionFromUrl(
          Uri.parse(
            'com.revocred.app://auth-callback/#access_token=token-a&refresh_token=refresh-a&expires_in=3600&token_type=bearer&type=signup',
          ),
        );
        sub ??= repo.sessionChanges.listen(events.add);
        await Future<void>.delayed(Duration.zero);
        expect(events.last.passwordRecovery, isFalse);
        expect(events.last.authenticated, isTrue);
        await sub.cancel();
      },
    );
  }

  test(
    'refresh replaces JWT and old 401 cannot revoke refreshed session',
    () async {
      var tokens = 0;
      final auth = authClient(
        (request) async =>
            jsonResponse(session(tokens++ == 0 ? 'a' : 'refreshed')),
      );
      addTearDown(auth.dispose);
      await auth.auth.signInWithPassword(
        email: 'a@example.test',
        password: 'password',
      );
      final delayed = Completer<http.Response>();
      final repo = ApiAppRepository(
        baseUrl: 'https://api.example.test',
        supabaseClient: auth,
        httpClient: MockClient((_) => delayed.future),
      );
      final pending = repo.addCard('card');
      await Future<void>.delayed(Duration.zero);
      await auth.auth.refreshSession();
      delayed.complete(http.Response('', 401));
      await expectLater(pending, throwsA(isA<SessionExpiredException>()));
      expect(auth.auth.currentSession?.accessToken, 'token-refreshed');
    },
  );
  test(
    'confirm-required and privacy-obfuscated duplicate signup match',
    () async {
      final auth = authClient(
        (_) async => jsonResponse({...user('a'), 'identities': []}),
      );
      addTearDown(auth.dispose);
      var apiCalls = 0;
      final repo = ApiAppRepository(
        baseUrl: 'https://api.example.test',
        supabaseClient: auth,
        httpClient: MockClient((_) async {
          apiCalls++;
          return http.Response('', 204);
        }),
      );
      final first = await repo.signUp('a@example.test', 'password123');
      final duplicate = await repo.signUp('a@example.test', 'password123');
      expect(first.success, isTrue);
      expect(duplicate.message, first.message);
      expect(repo.isAuthenticated, isFalse);
      expect(apiCalls, 0);
    },
  );

  test('old 401 never signs out a newly signed in account', () async {
    final auth = authClient(
      (request) async => request.url.path.endsWith('/logout')
          ? http.Response('', 204)
          : jsonResponse(
              session(
                jsonDecode(request.body)['email'].toString().split('@').first,
              ),
            ),
    );
    addTearDown(auth.dispose);
    await auth.auth.signInWithPassword(
      email: 'a@example.test',
      password: 'password',
    );
    final response = Completer<http.Response>();
    final repo = ApiAppRepository(
      baseUrl: 'https://api.example.test',
      supabaseClient: auth,
      httpClient: MockClient((_) => response.future),
    );
    final pending = repo.addCard('card');
    await Future<void>.delayed(Duration.zero);
    await auth.auth.signInWithPassword(
      email: 'b@example.test',
      password: 'password',
    );
    response.complete(http.Response('', 401));
    await expectLater(pending, throwsA(isA<SessionExpiredException>()));
    expect(auth.auth.currentUser?.id, 'b');
  });

  test('anonymous 401 never invalidates authenticated session', () async {
    final auth = authClient(
      (request) async => request.url.path.endsWith('/logout')
          ? http.Response('', 204)
          : jsonResponse(session('a')),
    );
    addTearDown(auth.dispose);
    await auth.auth.signInWithPassword(
      email: 'a@example.test',
      password: 'password',
    );
    final repo = ApiAppRepository(
      baseUrl: 'https://api.example.test',
      supabaseClient: auth,
      httpClient: MockClient((_) async => http.Response('', 401)),
    );
    await expectLater(
      repo.loadCatalog(),
      throwsA(isA<SessionExpiredException>()),
    );
    expect(repo.isAuthenticated, isTrue);
  });

  test('logout server failure still completes local logout', () async {
    final auth = authClient(
      (request) async => request.url.path.endsWith('/logout')
          ? jsonResponse({'message': 'unavailable'}, 503)
          : jsonResponse(session('a')),
    );
    addTearDown(auth.dispose);
    await auth.auth.signInWithPassword(
      email: 'a@example.test',
      password: 'password',
    );
    final repo = ApiAppRepository(
      baseUrl: 'https://api.example.test',
      supabaseClient: auth,
    );
    await expectLater(repo.signOut(), completes);
    expect(repo.isAuthenticated, isFalse);
  });
  test(
    'successful signup is not failed by optional profile API outage',
    () async {
      final auth = authClient((request) async {
        expect(jsonDecode(request.body)['data']['display_name'], 'Avery');
        return jsonResponse(session('a'));
      });
      addTearDown(auth.dispose);
      final repo = ApiAppRepository(
        baseUrl: 'https://api.example.test',
        supabaseClient: auth,
        httpClient: MockClient((_) async => http.Response('offline', 503)),
      );
      final result = await repo.signUp(
        'a@example.test',
        'password123',
        displayName: ' Avery ',
      );
      expect(result.success, isTrue);
      expect(repo.isAuthenticated, isTrue);
    },
  );
}
