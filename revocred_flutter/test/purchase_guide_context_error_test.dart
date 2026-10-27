import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/core/models/app_models.dart';
import 'package:revocred_flutter/core/theme/app_theme.dart';
import 'package:revocred_flutter/features/home/presentation/purchase_recommendations_sheet.dart';

void main() {
  testWidgets(
    'failed travel context update restores the previous visible booking choice',
    (tester) async {
      final requested = <String>[];
      final guide = PurchaseGuide.fromJson({
        'settings': {'travel_mode': 'general', 'caps_available': true},
        'travel_modes': [
          {'id': 'general', 'label': 'General travel'},
          {'id': 'chase-portal', 'label': 'Purchases through Chase Travel'},
        ],
        'categories': [
          {'id': 'travel', 'label': 'Travel', 'options': []},
        ],
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.decisionFlow,
          home: Scaffold(
            body: PurchaseRecommendationsSheet(
              categoryId: 'travel',
              categoryLabel: 'Travel',
              wallet: const [],
              initialGuide: guide,
              load: (mode, caps) async {
                requested.add(mode);
                throw StateError('simulated provider timeout');
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Purchases through Chase Travel').last);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Could not update the comparison'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(DropdownButtonFormField<String>),
          matching: find.text('General travel'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(DropdownButtonFormField<String>),
          matching: find.text('Purchases through Chase Travel'),
        ),
        findsNothing,
      );
      await tester.tap(find.text('Retry comparison'));
      await tester.pumpAndSettle();
      expect(requested, ['chase-portal', 'chase-portal']);
    },
  );
}
