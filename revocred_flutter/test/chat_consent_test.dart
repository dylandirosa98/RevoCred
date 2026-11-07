import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:revocred_flutter/app.dart';
import 'package:revocred_flutter/core/config/app_config.dart';
import 'package:revocred_flutter/core/data/api_app_repository.dart';
import 'package:revocred_flutter/core/data/chat_stream.dart';
import 'package:revocred_flutter/core/data/mock_app_repository.dart';
import 'package:revocred_flutter/core/models/app_models.dart';
import 'package:revocred_flutter/core/models/chat_disclosure.dart';
import 'package:revocred_flutter/core/models/chat_errors.dart';
import 'package:revocred_flutter/core/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _version =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

class _ConsentRepository extends MockAppRepository {
  final permissions = <String?>[];
  String? email = 'member@example.test';
  String version = _version;
  bool disclosureFails = false;

  /// Errors thrown by the next sends, in order.
  final failures = <Object>[];

  @override
  String? get accountEmail => email;

  @override
  Future<ChatDisclosure> loadChatDisclosure() async {
    if (disclosureFails) throw StateError('Disclosure unavailable');
    return ChatDisclosure(
      version: version,
      recipient: 'OpenAI',
      model: 'configured-production-model',
      dataUse: 'Your message and plan context are shared with the AI service.',
      dataUsePoints: const [
        'Your message and plan context are shared with the AI service.',
        'Permission is saved until you turn it off in Profile.',
      ],
      searchProvider: 'Brave Search',
    );
  }

  @override
  Future<ChatMessage> sendMessage(
    String prompt, {
    String? aiConsentVersion,
  }) async {
    if (failures.isNotEmpty) throw failures.removeAt(0);
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

Future<void> _compose(
  WidgetTester tester, [
  String text = 'Explain my plan',
]) async {
  await tester.enterText(find.byKey(const ValueKey('revo-composer')), text);
  await tester.tap(find.byKey(const ValueKey('revo-send')));
  await tester.pumpAndSettle();
}

final _sheet = find.text('Let REVO use AI?');

Future<void> _choose(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

int _bubbles(WidgetTester tester, String text) =>
    find.text(text, findRichText: true).evaluate().length;

void main() {
  testWidgets('cancel never sends and retains the composed message', (
    tester,
  ) async {
    final repository = _ConsentRepository();
    await _launch(tester, repository);
    await _compose(tester);
    expect(_sheet, findsOneWidget);
    expect(find.textContaining('OpenAI', findRichText: true), findsWidgets);
    expect(
      find.textContaining('Brave Search', findRichText: true),
      findsOneWidget,
    );
    await _choose(tester, 'ai-consent-cancel');
    expect(repository.permissions, isEmpty);
    expect(find.text('Explain my plan'), findsOneWidget);
  });

  testWidgets('basic answer saves nothing, so the next message asks again', (
    tester,
  ) async {
    final repository = _ConsentRepository();
    await _launch(tester, repository);
    await _compose(tester);
    await _choose(tester, 'ai-consent-basic');
    expect(repository.permissions, [null]);
    await _compose(tester, 'And travel?');
    expect(_sheet, findsOneWidget);
  });

  testWidgets('agreeing once covers later messages', (tester) async {
    final repository = _ConsentRepository();
    await _launch(tester, repository);
    await _compose(tester);
    await _choose(tester, 'ai-consent-agree');
    expect(repository.permissions, [_version]);
    await _compose(tester, 'And travel?');
    expect(_sheet, findsNothing);
    expect(repository.permissions, [_version, _version]);
  });

  testWidgets('a changed sharing notice asks again', (tester) async {
    final repository = _ConsentRepository();
    await _launch(tester, repository);
    await _compose(tester);
    await _choose(tester, 'ai-consent-agree');
    // The server reports the notice changed between asking and sending.
    repository
      ..version = 'b' * 64
      ..failures.add(
        const ChatSendException(
          'ai_consent_changed',
          'The AI service changed.',
        ),
      );
    // The reply spinner stays up behind the sheet, so pump instead of settle.
    await tester.enterText(
      find.byKey(const ValueKey('revo-composer')),
      'And travel?',
    );
    await tester.tap(find.byKey(const ValueKey('revo-send')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(_sheet, findsOneWidget);
    await _choose(tester, 'ai-consent-agree');
    expect(repository.permissions, [_version, 'b' * 64]);
    expect(_bubbles(tester, 'And travel?'), 1);
  });

  testWidgets('account changed during permission sheet cannot send', (
    tester,
  ) async {
    final repository = _ConsentRepository();
    await _launch(tester, repository);
    await _compose(tester);
    repository.email = 'another@example.test';
    await _choose(tester, 'ai-consent-agree');
    expect(repository.permissions, isEmpty);
    expect(find.textContaining('Your account changed'), findsOneWidget);
  });

  testWidgets('failed disclosure never posts the message', (tester) async {
    final repository = _ConsentRepository()..disclosureFails = true;
    await _launch(tester, repository);
    await _compose(tester);
    expect(repository.permissions, isEmpty);
    expect(_sheet, findsNothing);
    expect(find.textContaining('REVO could not send.'), findsOneWidget);
  });

  testWidgets('a failed send shows a specific error without a stray bubble', (
    tester,
  ) async {
    final repository = _ConsentRepository();
    await _launch(tester, repository);
    await _compose(tester);
    await _choose(tester, 'ai-consent-agree');
    repository.failures.add(
      const ChatSendException(
        'chat_daily_limit',
        "You've reached today's REVO AI limit. Basic answers are still available.",
      ),
    );
    await _compose(tester, 'One more question');
    expect(find.textContaining("today's REVO AI limit"), findsOneWidget);
    // Only the composer still holds the text; no orphaned user bubble.
    expect(_bubbles(tester, 'One more question'), 1);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(_bubbles(tester, 'One more question'), 1);
    expect(repository.permissions.length, 2);
  });

  testWidgets('turning AI answers off in Profile asks again next time', (
    tester,
  ) async {
    final repository = _ConsentRepository();
    await _launch(tester, repository);
    await _compose(tester);
    await _choose(tester, 'ai-consent-agree');
    appRouter.go('/profile');
    await tester.pumpAndSettle();
    final toggle = find.byKey(const ValueKey('ai-answers-toggle'));
    await tester.ensureVisible(toggle);
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    expect((await repository.loadChatConsent()).granted, isFalse);
    appRouter.go('/revo');
    await tester.pumpAndSettle();
    await _compose(tester, 'And travel?');
    expect(_sheet, findsOneWidget);
  });

  for (final route in ['/home', '/cards', '/revo']) {
    for (final choice in [
      'ai-consent-cancel',
      'ai-consent-basic',
      'ai-consent-agree',
    ]) {
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
        expect(_sheet, findsOneWidget);
        expect(repository.permissions, isEmpty);
        await _choose(tester, choice);
        expect(repository.permissions, switch (choice) {
          'ai-consent-cancel' => <String?>[],
          'ai-consent-basic' => <String?>[null],
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

  group('chat streaming', () {
    Stream<String> lines(String text) => Stream.fromIterable(text.split('\n'));

    test('parses status, keep-alives, CRLF and done', () async {
      final events = await parseChatEvents(
        lines(
          'event: status\r\ndata: {"stage":"searching","label":"Searching the web…"}\r\n\r\n'
          ': keep-alive\n\n'
          'event: done\ndata: {"data":[{"id":"u","role":"user","content":"Q","created_at":"2026-11-06T00:00:00Z"},\n'
          'data: {"id":"a","role":"assistant","content":"A","mode":"ai","created_at":"2026-11-06T00:00:00Z"}]}\n\n',
        ).map((line) => line.replaceAll('\r', '')),
      ).toList();
      expect(events.first, isA<ChatStatusEvent>());
      expect((events.first as ChatStatusEvent).label, 'Searching the web…');
      final done = events.last as ChatDoneEvent;
      expect(done.user?.id, 'u');
      expect(done.reply.mode, 'ai');
    });

    test('error events and truncated streams fail', () async {
      await expectLater(
        parseChatEvents(
          lines(
            'event: error\ndata: {"error":{"code":"request_timeout","message":"slow"}}\n\n',
          ),
        ).toList(),
        throwsA(
          isA<ChatSendException>().having(
            (e) => e.code,
            'code',
            'request_timeout',
          ),
        ),
      );
      await expectLater(
        parseChatEvents(
          lines('event: status\ndata: {"stage":"thinking","label":"T"}\n\n'),
        ).toList(),
        throwsA(isA<ChatSendException>()),
      );
    });

    ApiAppRepository api(
      Future<http.StreamedResponse> Function(http.BaseRequest) handler,
    ) => ApiAppRepository(
      baseUrl: 'https://api.example.test',
      supabaseClient: null,
      accessTokenProvider: () => 'test-session',
      httpClient: MockClient.streaming((request, _) => handler(request)),
    );

    http.StreamedResponse respond(
      String body,
      int status, {
      String type = 'application/json',
    }) => http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      status,
      headers: {'content-type': type},
    );

    test('streams server-sent events with the consent version', () async {
      late http.BaseRequest sent;
      final repository = api((request) async {
        sent = request;
        return respond(
          'event: status\ndata: {"stage":"thinking","label":"Thinking…"}\n\n'
          'event: done\ndata: {"data":[{"id":"a","role":"assistant","content":"A","created_at":"2026-11-06T00:00:00Z"}]}\n\n',
          200,
          type: 'text/event-stream; charset=utf-8',
        );
      });
      final events = await repository
          .streamMessage('Explain', aiConsentVersion: _version)
          .toList();
      expect(sent.url.path, '/v1/chat/messages');
      expect(sent.headers['Accept'], contains('text/event-stream'));
      expect(
        jsonDecode((sent as http.Request).body)['ai_consent_version'],
        _version,
      );
      expect(events.whereType<ChatDoneEvent>().single.reply.id, 'a');
    });

    test('falls back to JSON and maps API errors to codes', () async {
      final json = api(
        (_) async => respond(
          '{"data":[{"id":"u","role":"user","content":"Q","created_at":"2026-11-06T00:00:00Z"},{"id":"a","role":"assistant","content":"A","mode":"basic","created_at":"2026-11-06T00:00:00Z"}]}',
          201,
        ),
      );
      final done = await json.streamMessage('Q').single as ChatDoneEvent;
      expect(done.reply.isBasic, isTrue);

      final limited = api(
        (_) async => respond(
          '{"error":{"code":"chat_daily_limit","message":"Limit reached."}}',
          429,
        ),
      );
      await expectLater(
        limited.streamMessage('Q').toList(),
        throwsA(
          isA<ChatSendException>().having(
            (e) => e.code,
            'code',
            'chat_daily_limit',
          ),
        ),
      );
    });

    test('consent, clear and feedback use the documented endpoints', () async {
      final calls = <String>[];
      final repository = api((request) async {
        calls.add('${request.method} ${request.url.path}');
        if (request.method == 'DELETE' ||
            request.url.path.endsWith('/feedback')) {
          return respond('', 204);
        }
        return respond('{"data":{"granted":true,"version":"$_version"}}', 200);
      });
      expect((await repository.grantChatConsent(_version)).granted, isTrue);
      expect((await repository.loadChatConsent()).version, _version);
      await repository.revokeChatConsent();
      await repository.clearChatHistory();
      await repository.sendChatFeedback('a1', rating: 'down', reason: 'Wrong');
      expect(calls, [
        'PUT /v1/chat/consent',
        'GET /v1/chat/consent',
        'DELETE /v1/chat/consent',
        'DELETE /v1/chat/messages',
        'POST /v1/chat/messages/a1/feedback',
      ]);
    });
  });

  test('chat errors read as plain language', () {
    expect(
      chatErrorMessage(const ChatSendException('account_required', '')),
      contains('Create an account'),
    );
    expect(
      chatErrorMessage(http.ClientException('SocketException: host')),
      isNot(contains('Socket')),
    );
    expect(
      chatErrorMessage(StateError('boom')),
      contains('REVO could not send'),
    );
  });
}
