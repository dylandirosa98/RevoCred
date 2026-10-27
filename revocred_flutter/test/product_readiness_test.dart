import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/core/data/demo_seed.dart';
import 'package:revocred_flutter/core/logic/strategy_report_copy.dart';
import 'package:revocred_flutter/core/models/app_models.dart';
import 'package:revocred_flutter/core/theme/app_theme.dart';
import 'package:revocred_flutter/features/strategy/presentation/strategy_roadmap_view.dart';
import 'package:revocred_flutter/shared/widgets/community_card_details.dart';

void main() {
  test(
    'report value disclosure distinguishes modeled and unavailable benefits',
    () {
      final base = createDemoAppData();
      final modeled = AppData(
        profile: base.profile,
        wallet: base.wallet,
        catalog: base.catalog,
        roadmap: base.roadmap,
        messages: base.messages,
        quickPrompts: base.quickPrompts,
        pointsValue: base.pointsValue,
        projectedYearlyValue: base.projectedYearlyValue,
        ongoingValue: const OngoingValue(),
      );
      expect(strategyValueExplanation(modeled), contains('70%'));
      expect(
        strategyValueExplanation(modeled),
        contains('anniversary rewards - annual fees'),
      );
      expect(
        strategyValueExplanation(modeled),
        contains('Excludes welcome bonuses'),
      );
      expect(
        strategyValueExplanation(modeled),
        isNot(contains('excludes bonuses and conditional credits')),
      );
    },
  );
  test(
    'cached catalog travel perks survive parsing without scoring changes',
    () {
      final catalog =
          jsonDecode(
                File(
                  '../revocred-api/internal/valuation/testdata/catalog.json',
                ).readAsStringSync(),
              )
              as List;
      for (final raw in catalog) {
        final json = (raw as Map).cast<String, dynamic>();
        final card = CreditCard.fromApiJson(json);
        final community = (json['community_data'] as Map)
            .cast<String, dynamic>();
        final details = card.communityData!;
        final perks = community['travel_perks'];
        if (perks is Map && perks['hotel_status'] is String) {
          expect(
            details.travelPerks.join(' '),
            contains(perks['hotel_status']),
          );
        }
        expect(
          card.copyWith(isActive: true).communityData?.travelPerks,
          details.travelPerks,
        );
        final withoutCommunity = Map<String, dynamic>.from(json)
          ..remove('community_data');
        expect(
          card.pointMultipliers,
          CreditCard.fromApiJson(withoutCommunity).pointMultipliers,
        );
        expect(
          card.annualFee,
          CreditCard.fromApiJson(withoutCommunity).annualFee,
        );
      }
      for (final value in [
        null,
        {},
        [],
        {'hotel_status': null},
        {
          'other': ['', null],
        },
      ]) {
        expect(
          CommunityCardData.fromJson({'travel_perks': value}).travelPerks,
          isEmpty,
        );
      }
    },
  );
  testWidgets(
    'structured travel perks preserve all source facts and conditions',
    (tester) async {
      final data = CommunityCardData.fromJson({
        'last_verified': '2020-01-01',
        'attribution': 'OpenCard DB',
        'travel_perks': {
          'hotel_status': 'IHG One Rewards Platinum Elite through 2027-12-31',
          'lounge_access': {
            'program': 'Priority Pass',
            'visits_per_year': null,
            'notes': 'Enrollment required',
          },
          'global_entry_credit': {
            'amount': 120,
            'currency': 'USD',
            'period': 'every_4_years',
          },
          'free_checked_bags': false,
          'other': [
            'No foreign transaction fees',
            null,
            {'condition': 'Eligible purchases only'},
          ],
          'new_perk': {'limit': 0, 'enabled': true},
        },
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.decisionFlow,
          home: Scaffold(
            body: SingleChildScrollView(
              child: CommunityCardDetails(data: data),
            ),
          ),
        ),
      );
      expect(
        find.textContaining('IHG One Rewards Platinum Elite'),
        findsOneWidget,
      );
      expect(find.textContaining('Enrollment required'), findsOneWidget);
      expect(find.textContaining('every 4 years'), findsOneWidget);
      expect(find.textContaining('120'), findsOneWidget);
      expect(find.textContaining('Eligible purchases only'), findsOneWidget);
      expect(find.textContaining('Limit: 0'), findsOneWidget);
      expect(find.textContaining('over 90 days old'), findsOneWidget);
      expect(find.textContaining('null'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'actual report explains roles, eligibility and ongoing value once',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.decisionFlow,
          home: Scaffold(
            body: SingleChildScrollView(
              child: StrategyRoadmapView(data: createDemoAppData()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('not a shopping list'), findsOneWidget);
      expect(
        find.textContaining('Future roles may become eligible'),
        findsOneWidget,
      );
      expect(find.text('ESTIMATED ONGOING YEARLY VALUE'), findsOneWidget);
      expect(find.text('Current annual net rewards'), findsNothing);
      expect(
        find.textContaining('excludes bonuses and conditional credits'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
