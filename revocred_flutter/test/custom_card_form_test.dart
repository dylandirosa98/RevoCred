import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/core/models/app_models.dart';
import 'package:revocred_flutter/core/theme/app_theme.dart';
import 'package:revocred_flutter/shared/widgets/custom_card_form.dart';

void main() {
  testWidgets('custom card form explains what is missing or invalid', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    CustomCardDraft? saved;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.decisionFlow,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async =>
                    saved = await showCustomCardSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final save = find.byKey(const ValueKey('custom-card-save'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Enter the card name.'), findsOneWidget);
    expect(find.text('Enter the issuer, like Chase.'), findsOneWidget);
    expect(saved, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('custom-card-name')),
      'Store card',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Issuer'),
      'Example Bank',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Dining'), '45');
    await tester.pump();
    expect(find.text('Enter the card name.'), findsNothing);
    expect(find.text('Use a rate from 0 to 20.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Dining'), '3');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(saved?.name, 'Store card');
    expect(saved?.rates['dining'], 3);
  });
}
