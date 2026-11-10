import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:revocred_flutter/app.dart';
import 'package:revocred_flutter/core/config/app_config.dart';
import 'package:revocred_flutter/core/data/chat_stream.dart';
import 'package:revocred_flutter/core/data/mock_app_repository.dart';
import 'package:revocred_flutter/core/models/app_models.dart';
import 'package:revocred_flutter/core/models/chat_disclosure.dart';
import 'package:revocred_flutter/core/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _replyId = '3f2b8c1e-9a4d-4e6f-8b7a-1c2d3e4f5a6b';

class _ChatRepository extends MockAppRepository {
  String mode = 'ai';
  bool hang = false;
  bool cleared = false;
  final ratings = <String>[];
  final _pending = <Completer<void>>[];

  @override
  Stream<ChatStreamEvent> streamMessage(
    String prompt, {
    String? aiConsentVersion,
  }) async* {
    yield const ChatStatusEvent('searching', 'Searching the web…');
    if (hang) {
      final wait = Completer<void>();
      _pending.add(wait);
      await wait.future;
    }
    yield ChatDoneEvent(
      reply: ChatMessage(
        id: _replyId,
        role: MessageRole.assistant,
        content: 'Use Amex Gold for groceries.',
        mode: mode,
        createdAt: DateTime(2026),
      ),
    );
  }

  @override
  Future<void> clearChatHistory() async {
    cleared = true;
    await super.clearChatHistory();
  }

  @override
  Future<void> sendChatFeedback(
    String messageId, {
    required String rating,
    String? reason,
  }) async {
    ratings.add('$messageId $rating ${reason ?? ''}'.trim());
  }
}

/// The AI sharing notice can't load on the first try, as when offline.
class _OfflineFirstRepository extends _ChatRepository {
  int disclosureLoads = 0;

  @override
  Future<ChatDisclosure> loadChatDisclosure() async {
    disclosureLoads++;
    if (disclosureLoads == 1) {
      throw http.ClientException('Failed host lookup');
    }
    return super.loadChatDisclosure();
  }
}

Future<void> _launch(WidgetTester tester, _ChatRepository repository) async {
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
  appRouter.go('/revo');
  await tester.pumpAndSettle();
}

Future<void> _send(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const ValueKey('revo-composer')), text);
  await tester.tap(find.byKey(const ValueKey('revo-send')));
}

void main() {
  testWidgets('stop cancels without an error and keeps the draft', (
    tester,
  ) async {
    final repository = _ChatRepository()..hang = true;
    await _launch(tester, repository);
    await _send(tester, 'Best grocery card?');
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Searching the web…'), findsOneWidget);
    await tester.tap(find.byTooltip('Stop'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Try again'), findsNothing);
    expect(find.byTooltip('Send message'), findsOneWidget);
    // Only the composer still holds the prompt.
    expect(find.text('Best grocery card?'), findsOneWidget);
    expect(find.text('Use Amex Gold for groceries.'), findsNothing);
  });

  testWidgets('a reply clears the composer and labels basic answers', (
    tester,
  ) async {
    final repository = _ChatRepository()..mode = 'basic';
    await _launch(tester, repository);
    await _send(tester, 'Best grocery card?');
    await tester.pumpAndSettle();
    expect(find.text('Use Amex Gold for groceries.'), findsOneWidget);
    expect(find.text('Basic answer (no AI)'), findsOneWidget);
    final composer = tester.widget<TextField>(
      find.byKey(const ValueKey('revo-composer')),
    );
    expect(composer.controller!.text, isEmpty);
  });

  testWidgets('feedback and report reach the server', (tester) async {
    final repository = _ChatRepository();
    await _launch(tester, repository);
    await _send(tester, 'Best grocery card?');
    await tester.pumpAndSettle();
    expect(find.text('Basic answer (no AI)'), findsNothing);

    await tester.ensureVisible(find.byTooltip('Helpful'));
    await tester.tap(find.byTooltip('Helpful'));
    await tester.pumpAndSettle();
    expect(repository.ratings, ['$_replyId up']);
    expect(find.text('Thanks for the feedback'), findsOneWidget);

    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Harmful or offensive'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit feedback'));
    await tester.pumpAndSettle();
    expect(repository.ratings.last, '$_replyId down Harmful or offensive');
  });

  testWidgets('clearing the conversation asks first, then shows the intro', (
    tester,
  ) async {
    final repository = _ChatRepository();
    await _launch(tester, repository);
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.cleared, isFalse);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear conversation'));
    await tester.pumpAndSettle();
    expect(repository.cleared, isTrue);
    expect(find.text('Meet your wallet guide'), findsOneWidget);
    expect(find.text('Clear'), findsNothing);
  });

  testWidgets('an offline send reports an error and the next send works', (
    tester,
  ) async {
    final repository = _OfflineFirstRepository();
    await _launch(tester, repository);
    await _send(tester, 'Which card for groceries?');
    await tester.pumpAndSettle();
    expect(find.textContaining('could not connect'), findsOneWidget);

    // Send must not stay disabled once the connection is back.
    await tester.tap(find.byKey(const ValueKey('revo-send')));
    await tester.pumpAndSettle();
    expect(find.text('Use Amex Gold for groceries.'), findsWidgets);
    expect(repository.disclosureLoads, 2);
  });
}
