import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/core/models/chat_disclosure.dart';
import 'package:revocred_flutter/core/config/app_config.dart';
import 'package:revocred_flutter/features/profile/presentation/legal_screen.dart';

void main() {
  test('production rejects missing legal facts', () {
    expect(
      const AppConfig(
        useMocks: false,
        production: true,
        apiUrl: 'https://api.example.com',
        supabaseUrl: 'https://auth.example.com',
        supabaseAnonKey: 'sb_publishable_example',
      ).validate,
      throwsStateError,
    );
  });
  testWidgets('signed-out legal screen labels demo operator', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LegalScreen())),
    );
    expect(find.text('Privacy & Terms'), findsOneWidget);
    expect(find.textContaining('Demo: RevoCred'), findsOneWidget);
    expect(find.textContaining('pre-release'), findsNothing);
  });
  testWidgets('legal notice uses the current recipient', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          legalChatDisclosureProvider.overrideWith(
            (ref) async => const ChatDisclosure(
              version: 'test',
              recipient: 'OpenCode Go and DeepSeek (testing)',
              model: 'deepseek-test',
              dataUse: 'The question and relevant context are shared.',
            ),
          ),
        ],
        child: const MaterialApp(home: LegalScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('Current AI service:'),
      200,
    );
    expect(find.textContaining('OpenCode Go and DeepSeek'), findsOneWidget);
    expect(find.textContaining('OpenAI'), findsNothing);
    expect(
      find.textContaining('The question and relevant context'),
      findsOneWidget,
    );
  });
  testWidgets('unavailable sharing notice can be retried safely', (
    tester,
  ) async {
    var loads = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          legalChatDisclosureProvider.overrideWith((ref) async {
            loads++;
            if (loads == 1) throw StateError('offline');
            return const ChatDisclosure.basic();
          }),
        ],
        child: const MaterialApp(home: LegalScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Retry AI sharing notice'), 200);
    await tester.ensureVisible(find.text('Retry AI sharing notice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry AI sharing notice'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('currently uses basic replies'),
      -200,
    );
    expect(find.textContaining('currently uses basic replies'), findsOneWidget);
    expect(loads, 2);
  });
  testWidgets('invalid legal link reports an actionable failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          legalChatDisclosureProvider.overrideWith(
            (ref) async => const ChatDisclosure.basic(),
          ),
        ],
        child: const MaterialApp(
          home: LegalScreen(config: AppConfig(useMocks: false)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Full privacy policy'), 300);
    await tester.tap(find.text('Full privacy policy'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not open this link. Please try again later.'),
      findsOneWidget,
    );
  });
  for (final throwsError in [false, true]) {
    testWidgets(
      'legal launcher handles ${throwsError ? 'exception' : 'false'}',
      (tester) async {
        const channel = MethodChannel('plugins.flutter.io/url_launcher');
        var attempts = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              attempts++;
              if (throwsError) throw PlatformException(code: 'unavailable');
              return false;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              legalChatDisclosureProvider.overrideWith(
                (ref) async => const ChatDisclosure.basic(),
              ),
            ],
            child: const MaterialApp(
              home: LegalScreen(
                config: AppConfig(
                  useMocks: false,
                  privacyUrl: 'https://example.com/privacy',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Full privacy policy'), 300);
        await tester.tap(find.text('Full privacy policy'));
        await tester.pumpAndSettle();
        expect(attempts, greaterThan(0));
        expect(
          find.text('Could not open this link. Please try again later.'),
          findsOneWidget,
        );
      },
    );
  }
}
