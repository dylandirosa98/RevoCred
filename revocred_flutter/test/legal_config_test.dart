import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    await tester.pumpWidget(const MaterialApp(home: LegalScreen()));
    expect(find.text('Privacy & Terms'), findsOneWidget);
    expect(find.textContaining('Demo: RevoCred'), findsOneWidget);
    expect(find.textContaining('pre-release'), findsNothing);
  });
}
