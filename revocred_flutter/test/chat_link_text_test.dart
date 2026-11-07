import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/features/revo/presentation/chat_link_text.dart';

void main() {
  testWidgets('HTTPS links launch, shorten URLs and preserve punctuation', (
    tester,
  ) async {
    Uri? launched;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectionArea(
            child: ChatLinkText(
              '[Terms](https://chase.com/terms) https://chase.com/cards). [Unsafe](http://example.com)',
              accent: Colors.blue,
              style: const TextStyle(),
              launcher: (uri) async {
                launched = uri;
                return true;
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Terms'));
    expect(launched.toString(), 'https://chase.com/terms');
    await tester.tap(find.text('chase.com/…'));
    expect(launched.toString(), 'https://chase.com/cards');
    expect(
      find.textContaining('[Unsafe](http://example.com)', findRichText: true),
      findsOneWidget,
    );
  });
}
