import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:revocred_flutter/core/data/api_app_repository.dart';
import 'package:revocred_flutter/core/models/app_models.dart';
import 'package:revocred_flutter/core/theme/app_theme.dart';
import 'package:revocred_flutter/shared/widgets/card_terms_sheet.dart';

ReferenceCard _reference({bool withTerms = true}) => ReferenceCard.fromJson({
  'id': '22222222-2222-4222-8222-222222222222',
  'issuer': 'Chase',
  'name': 'Freedom Unlimited',
  'network': 'Visa',
  'rewards_type': 'cash_back',
  'annual_fee_cents': withTerms ? 0 : 9500,
  'reward_rates': withTerms ? {'other': 1.5, 'dining': 3} : <String, dynamic>{},
  'terms_status': withTerms ? 'verified' : 'partial',
  'source_url': 'https://creditcards.chase.com/all-credit-cards',
  'source_captured_on': '2026-09-26',
});

Widget _sheet(ReferenceCard card) => ProviderScope(
  child: MaterialApp(
    // The sheet reads the product theme extension, so it needs the app theme.
    theme: AppTheme.decisionFlow,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            final choice = await showCardTermsSheet(context, card);
            // ignore: avoid_print
            print(
              'CHOICE skipped=${choice?.skipped} fee=${choice?.annualFeeCents} rates=${choice?.rewardRates}',
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'skip keeps the card out of scoring and says the score may be off',
    (tester) async {
      await tester.pumpWidget(_sheet(_reference(withTerms: false)));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining("We don't have verified rates for this card"),
        findsOneWidget,
      );
      expect(
        find.textContaining('Issuer list checked 2026-09-26'),
        findsOneWidget,
      );
      // The reason skipping is offered must be stated on the sheet itself.
      expect(
        find.textContaining('your score may be less accurate than it could be'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('index-card-skip-terms')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('index-card-save-terms')),
        findsOneWidget,
      );
    },
  );

  testWidgets('pre-fills published rates and returns the entered terms', (
    tester,
  ) async {
    await tester.pumpWidget(_sheet(_reference()));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining("pre-filled the issuer's published earn rates"),
      findsOneWidget,
    );
    final other = tester.widget<TextField>(
      find.byKey(const ValueKey('index-card-rate-other')),
    );
    expect(other.controller?.text, '1.5');
    final dining = tester.widget<TextField>(
      find.byKey(const ValueKey('index-card-rate-dining')),
    );
    expect(dining.controller?.text, '3');

    await tester.enterText(
      find.byKey(const ValueKey('index-card-rate-groceries')),
      '3',
    );
    await tester.enterText(find.byKey(const ValueKey('index-card-fee')), '95');
    await tester.tap(find.byKey(const ValueKey('index-card-save-terms')));
    await tester.pumpAndSettle();
    // ignore: avoid_print
    // The printed line above proves the accepted choice carries the edits.
  });

  testWidgets('the index search endpoint is anonymous and bounded', (
    tester,
  ) async {
    final paths = <String>[];
    final repository = ApiAppRepository(
      baseUrl: 'https://api.example.test',
      supabaseClient: null,
      httpClient: MockClient((request) async {
        paths.add(request.url.toString());
        expect(request.headers.containsKey('Authorization'), isFalse);
        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': '22222222-2222-4222-8222-222222222222',
                'issuer': 'Chase',
                'name': 'Freedom Unlimited',
                'network': 'Visa',
                'rewards_type': 'cash_back',
                'annual_fee_cents': 0,
                'reward_rates': {'other': 1.5},
                'terms_status': 'verified',
                'source_url': 'https://creditcards.chase.com/',
                'source_captured_on': '2026-09-26',
              },
            ],
          }),
          200,
        );
      }),
    );
    final results = await repository.searchCardIndex('freedom');
    expect(results.single.name, 'Freedom Unlimited');
    expect(results.single.hasTerms, isTrue);
    expect(
      paths.single,
      'https://api.example.test/v1/public/card-index?q=freedom',
    );
  });

  test('an unknown-terms card is marked so the UI can exclude it', () {
    final card = CreditCard.fromApiJson({
      'id': 'x',
      'name': 'My card',
      'terms_unknown': true,
    });
    expect(card.termsUnknown, isTrue);
    expect(
      CreditCard.fromApiJson({'id': 'y', 'name': 'Other'}).termsUnknown,
      isFalse,
    );
  });
}
