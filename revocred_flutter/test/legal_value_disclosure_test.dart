import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/features/profile/presentation/legal_screen.dart';

void main() {
  testWidgets('legal notice distinguishes ongoing wallet and ranking models', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LegalScreen()));
    await tester.scrollUntilVisible(find.textContaining('70%'), 400);
    expect(find.textContaining('anniversary rewards'), findsOneWidget);
    expect(find.textContaining('Application rankings'), findsOneWidget);
    expect(find.textContaining('welcome bonuses'), findsOneWidget);
  });
}
