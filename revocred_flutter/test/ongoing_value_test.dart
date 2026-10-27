import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:revocred_flutter/core/data/reviewed_benefits.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/core/models/app_models.dart';
import 'package:revocred_flutter/core/logic/ongoing_value.dart';

import 'package:revocred_flutter/features/home/presentation/ongoing_value_breakdown.dart';

void main() {
  test(
    'reviewed evidence is identical to server and Venture X mock matches API cents',
    () {
      expect(
        jsonDecode(reviewedBenefitsJson),
        jsonDecode(
          File(
            '../revocred-api/internal/valuation/benefits.json',
          ).readAsStringSync(),
        ),
      );
      final fixture =
          (jsonDecode(
                    File(
                      '../revocred-api/internal/valuation/testdata/catalog.json',
                    ).readAsStringSync(),
                  )
                  as List)
              .cast<Map<String, dynamic>>();
      final json = fixture.firstWhere((c) => c['slug'] == 'venture-x');
      final card = CreditCard.fromApiJson(json, isActive: true);
      final value = estimateOngoingValue(
        [card],
        {'everyday': 1000, 'travel': 200},
        'both',
      );
      expect(
        [
          value.rewardsCents,
          value.creditsCents,
          value.anniversaryCents,
          value.feesCents,
          value.totalCents,
        ],
        [28800, 21000, 10000, 39500, 20300],
      );
      expect(
        estimateOngoingValue(
          [card, card],
          {'everyday': 1000, 'travel': 200},
          'both',
        ).totalCents,
        20300,
      );
      expect(
        estimateOngoingValue(
          [card],
          {'everyday': 1000, 'travel': 200},
          'none',
        ).creditsCents,
        0,
      );
      expect(
        estimateOngoingValue(
          [card.copyWith(isActive: false)],
          {'everyday': 1000},
          'both',
        ).totalCents,
        0,
      );
      final missing = CreditCard.fromApiJson({
        ...json,
        'community_data': null,
      }, isActive: true);
      expect(
        estimateOngoingValue(
          [missing],
          {'everyday': 1000, 'travel': 200},
          'both',
        ).totalCents,
        -10700,
      );
    },
  );
  test(
    'mock ongoing valuation uses conservative rewards and fees, no inferred custom benefits',
    () {
      final card = CreditCard.fromApiJson({
        'id': 'custom',
        'name': 'Custom',
        'annual_fee_cents': 39500,
        'reward_rates': {'other': 2},
      }, isActive: true);
      final value = estimateOngoingValue(
        [card],
        {'everyday': 1000, 'travel': 200},
        'both',
      );
      expect(value.totalCents, -10700);
      expect(value.creditsCents, 0);
      expect(value.rewardsCents, 28800);
    },
  );
  testWidgets(
    'expands ongoing value with assumptions and evidence at mobile width',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final value = OngoingValue.fromJson({
        'rewards_cents': 28800,
        'credits_cents': 21000,
        'anniversary_cents': 10000,
        'fees_cents': 39500,
        'total_cents': 20300,
        'assumptions': ['Welcome bonuses excluded; conditional use.'],
        'benefits': [
          {
            'title': 'Travel credit',
            'card_name': 'Venture X',
            'estimated_cents': 21000,
            'frequency': 'annual',
            'conditions': 'Capital One Travel eligible bookings required.',
            'source_url': 'https://www.capitalone.com/credit-cards/venture-x/',
            'reviewed_on': '2026-10-26',
            'evidence_version': 'reviewed-v1',
            'status': 'conditional_70_percent',
          },
        ],
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OngoingValueBreakdown(value: value),
            ),
          ),
        ),
      );
      await tester.tap(find.text('How this is estimated'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Spending rewards'), findsOneWidget);
      expect(find.textContaining('Credits at 70%'), findsOneWidget);
      expect(find.textContaining('Anniversary rewards'), findsOneWidget);
      expect(find.textContaining('Annual fees'), findsOneWidget);
      expect(find.textContaining('Welcome bonuses excluded'), findsOneWidget);
      expect(
        find.textContaining('Capital One Travel eligible'),
        findsOneWidget,
      );
      expect(find.textContaining('2026-10-26'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
