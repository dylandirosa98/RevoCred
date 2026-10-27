import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:revocred_flutter/app.dart';
import 'package:revocred_flutter/core/config/app_config.dart';
import 'package:revocred_flutter/core/data/api_app_repository.dart';
import 'package:revocred_flutter/core/data/mock_app_repository.dart';
import 'package:revocred_flutter/core/models/app_models.dart';
import 'package:revocred_flutter/core/models/chat_disclosure.dart';
import 'package:revocred_flutter/core/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _version =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

class _ConsentRepository extends MockAppRepository {
  final permissions = <String?>[];
  String? email = 'member@example.test';
  bool disclosureFails = false;

  @override
  String? get accountEmail => email;

  @override
  Future<ChatDisclosure> loadChatDisclosure() async {
    if (disclosureFails) throw StateError('Disclosure unavailable');
    return const ChatDisclosure(
      version: _version,
      recipient: 'OpenAI',
      model: 'configured-production-model',
      dataUse:
          'Your message and personal plan context are shared for this reply only.',
    );
  }

  @override
  Future<ChatMessage> sendMessage(
    String prompt, {
    String? aiConsentVersion,
  }) async {
    permissions.add(aiConsentVersion);
    return ChatMessage(
      id: 'reply-${permissions.length}',
      role: MessageRole.assistant,
      content: 'A reply to your question.',
      createdAt: DateTime(2026),
    );
  }
}

Future<void> _launch(
  WidgetTester tester,
  _ConsentRepository repository, {
  String route = '/revo',
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    RevoCredBootstrap(
      config: const AppConfig(useMocks: true),
      repository: repository,
      preferences: preferences,
    ),
  );
  await tester.pumpAndSettle();
  appRouter.go(route);
  await tester.pumpAndSettle();
}

Future<void> _compose(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('revo-composer')),
    'Explain my plan',
  );
  await tester.tap(find.byKey(const ValueKey('revo-send')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('cancel never sends and retains the composed message', (
    tester,
  ) async {
    final repository = _ConsentRepository();
    await _launch(tester, repository);
    await _compose(tester);
    expect(find.text('AI service: OpenAI'), findsOneWidget);
    expect(repository.permissions, isEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.permissions, isEmpty);
    expect(find.text('Explain my plan'), findsOneWidget);
  });

  testWidgets('basic reply sends no external AI permission', (tester) async {
    final repository = _ConsentRepository();
    await _launch(tester, repository);
    await _compose(tester);
    await tester.tap(find.text('Use basic reply'));
    await tester.pumpAndSettle();
    expect(repository.permissions, [null]);
  });

  testWidgets(
    'external sharing requires a fresh affirmative action for every message',
    (tester) async {
      final repository = _ConsentRepository();
      await _launch(tester, repository);
      await _compose(tester);
      await tester.tap(find.text('Agree and send'));
      await tester.pumpAndSettle();
      expect(repository.permissions, [_version]);
      await _compose(tester);
      expect(find.text('Share this message with AI?'), findsOneWidget);
      expect(repository.permissions, [_version]);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.permissions, [_version]);
    },
  );

  testWidgets('account changed during permission dialog cannot send', (
    tester,
  ) async {
    final repository = _ConsentRepository();
    await _launch(tester, repository);
    await _compose(tester);
    repository.email = 'another@example.test';
    await tester.tap(find.text('Agree and send'));
    await tester.pumpAndSettle();
    expect(repository.permissions, isEmpty);
  });

  testWidgets('failed disclosure never posts the message', (tester) async {
    final repository = _ConsentRepository()..disclosureFails = true;
    await _launch(tester, repository);
    await _compose(tester);
    expect(repository.permissions, isEmpty);
    expect(find.text('Share this message with AI?'), findsNothing);
    expect(find.textContaining('REVO could not send.'), findsOneWidget);
  });

  for (final route in ['/home', '/cards', '/revo']) {
    for (final choice in ['Cancel', 'Use basic reply', 'Agree and send']) {
      testWidgets('$route quick entry respects $choice', (tester) async {
        final repository = _ConsentRepository();
        await _launch(tester, repository, route: route);
        final label = switch (route) {
          '/home' => 'Ask REVO',
          '/cards' => 'Ask REVO about this card',
          _ => 'What card should I use for groceries?',
        };
        final button = find.text(label).first;
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.text('AI service: OpenAI'), findsOneWidget);
        expect(repository.permissions, isEmpty);
        await tester.tap(find.text(choice));
        await tester.pumpAndSettle();
        expect(repository.permissions, switch (choice) {
          'Cancel' => <String?>[],
          'Use basic reply' => <String?>[null],
          _ => <String?>[_version],
        });
      });
    }
  }

  test('malformed disclosure cannot silently skip explicit permission', () {
    for (final json in <Map<String, dynamic>>[
      {},
      {'external': 'false'},
      {'external': true, 'version': _version, 'recipient': 'OpenAI'},
    ]) {
      expect(() => ChatDisclosure.fromJson(json), throwsFormatException);
    }
    expect(ChatDisclosure.fromJson({'external': false}).external, isFalse);
  });

  test(
    'API carries the specific permission and fetches notice without personal data',
    () async {
      final requests = <http.Request>[];
      final repository = ApiAppRepository(
        baseUrl: 'https://api.example.test',
        supabaseClient: null,
        accessTokenProvider: () => 'test-session',
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'data': {
                  'external': true,
                  'version': _version,
                  'recipient': 'OpenAI',
                  'model': 'test-model',
                  'data_use': 'Test sharing notice',
                },
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'reply',
                  'role': 'assistant',
                  'content': 'Reply',
                  'created_at': '2026-10-19T00:00:00Z',
                },
              ],
            }),
            201,
          );
        }),
      );
      final notice = await repository.loadChatDisclosure();
      expect(requests.single.url.path, '/v1/public/chat-disclosure');
      expect(requests.single.headers['Authorization'], isNull);
      expect(requests.single.body, isEmpty);
      await repository.sendMessage('Explain', aiConsentVersion: notice.version);
      expect(jsonDecode(requests.last.body)['ai_consent_version'], _version);
      await repository.sendMessage('Basic reply');
      expect(
        (jsonDecode(requests.last.body) as Map).containsKey(
          'ai_consent_version',
        ),
        isFalse,
      );
    },
  );
}
