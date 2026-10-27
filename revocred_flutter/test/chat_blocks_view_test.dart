import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/core/models/app_models.dart';
import 'package:revocred_flutter/features/revo/presentation/chat_blocks_view.dart';

Widget wrap(List<ChatBlock> blocks, {String fallback = 'plain text'}) =>
    MaterialApp(
      home: Scaffold(
        body: ChatBlocksView(
          blocks: blocks,
          fallbackText: fallback,
          ink: const Color(0xFF111111),
          muted: const Color(0xFF777777),
          accent: const Color(0xFF1B6B4A),
          surface: const Color(0xFFF4F4F2),
          bodySize: 14,
        ),
      ),
    );

ChatBlock chartBlock(String unit, List<Map<String, dynamic>> bars) =>
    ChatBlock.fromJson({
      'type': 'chart',
      'chart': {
        'title': 'Modeled value',
        'unit': unit,
        'note': 'From the server model.',
        'bars': bars,
      },
    });

void main() {
  testWidgets('renders a structured reply instead of literal markdown', (
    tester,
  ) async {
    final message = ChatMessage.fromJson({
      'id': 'm1',
      'role': 'assistant',
      'content': '### Your next move\n- Best modeled rate',
      'blocks': [
        {'type': 'heading', 'text': 'Your next move'},
        {
          'type': 'bullets',
          'items': ['Best modeled rate', 'No annual fee'],
        },
        {'type': 'note', 'text': 'Verify with the issuer.'},
      ],
      'created_at': '2026-01-01T00:00:00Z',
    });

    await tester.pumpWidget(wrap(message.blocks, fallback: message.content));

    expect(find.text('Your next move'), findsOneWidget);
    expect(find.text('Best modeled rate'), findsOneWidget);
    expect(find.text('No annual fee'), findsOneWidget);
    expect(find.text('Verify with the issuer.'), findsOneWidget);
    // The raw markdown source must not be shown anywhere.
    expect(find.textContaining('###'), findsNothing);
    expect(find.textContaining('- Best'), findsNothing);
  });

  testWidgets('draws a server chart with its values', (tester) async {
    await tester.pumpWidget(
      wrap([
        chartBlock('usd', [
          {'label': 'Groceries', 'value': 500, 'caption': 'per month'},
          {'label': 'Dining', 'value': 250, 'caption': 'per month'},
        ]),
      ]),
    );

    expect(find.text('Modeled value'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text(r'$500'), findsOneWidget);
    expect(find.text(r'$250'), findsOneWidget);
    // $500 is the top bar, so both bars render at full width.
    final bars = tester
        .widgetList<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        )
        .toList();
    expect(bars.length, 2);
    expect(bars.first.value, 1.0);
    expect(bars.last.value, closeTo(0.5, 0.01));
    // The largest bar carries the full theme colour; the rest recede.
    Color colorOf(LinearProgressIndicator bar) =>
        (bar.valueColor! as AlwaysStoppedAnimation<Color>).value;
    expect(colorOf(bars.first).a, closeTo(1, 0.01));
    expect(colorOf(bars.last).a, closeTo(0.45, 0.01));
  });

  testWidgets('labels a rate chart as a percentage', (tester) async {
    await tester.pumpWidget(
      wrap([
        chartBlock('percent', [
          {'label': 'Dining', 'value': 3, 'caption': 'Freedom Unlimited'},
        ]),
      ]),
    );

    expect(find.text('3% cash back'), findsOneWidget);
    expect(find.textContaining(r'$'), findsNothing);
  });

  testWidgets('uses the server reward label for points cards', (tester) async {
    final block = ChatBlock.fromJson({
      'type': 'chart',
      'chart': {
        'title': 'Grocery comparison',
        'unit': 'percent',
        'bars': [
          {
            'label': 'Groceries',
            'value': 4,
            'value_label': '4 points per dollar',
            'caption': 'Amex Gold',
          },
        ],
      },
    });

    await tester.pumpWidget(wrap([block]));

    expect(find.text('4 points per dollar'), findsOneWidget);
    expect(find.text('4% cash back'), findsNothing);
  });

  testWidgets('falls back to plain text for old messages', (tester) async {
    await tester.pumpWidget(wrap(const [], fallback: 'my saved reply'));

    expect(find.text('my saved reply'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('an unknown block type degrades to its text', (tester) async {
    await tester.pumpWidget(
      wrap([
        ChatBlock.fromJson({'type': 'table', 'text': 'future shape'}),
      ]),
    );

    expect(find.text('future shape'), findsOneWidget);
  });
}
