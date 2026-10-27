import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/core/models/app_models.dart';
import 'package:revocred_flutter/core/theme/app_theme.dart';
import 'package:revocred_flutter/shared/widgets/community_card_details.dart';

const community = <String, dynamic>{
  'id': 'us-chase-sapphire-reserve',
  'attribution': 'OpenCard DB · CC BY 4.0 · adapted for display',
  'source_url': 'https://github.com/thedavidweng/opencard-db',
  'license_url': 'https://creativecommons.org/licenses/by/4.0/',
  'issuer_url':
      'https://creditcards.chase.com/rewards-credit-cards/sapphire/reserve',
  'last_verified': '2026-07-23',
  'retrieved_at': '2026-10-25T23:00:00Z',
  'currency_label': 'Ultimate Rewards points',
  'source_annual_fee': 795,
  'reward_rates': ['8x — Travel through Chase Travel', '1x — Other purchases'],
  'benefits': [r'The Edit credit — Up to $500 annually; two-night minimum.'],
  'warning': 'Community-maintained snapshot; verify current issuer terms.',
};

void main() {
  test('community terms do not overwrite scoring or newer issuer benefits', () {
    final card = CreditCard.fromApiJson({
      'id': '20000000-0000-4000-8000-000000000013',
      'name': 'Sapphire Reserve',
      'reward_rates': {'other': 1, 'dining': 3},
      'annual_fee_cents': 79500,
      'benefits': ['Newer issuer snapshot benefit'],
      'community_data': community,
    });
    expect(card.pointMultipliers, ['1x other', '3x dining']);
    expect(card.benefits, ['Newer issuer snapshot benefit']);
    expect(card.communityData?.rewardRates.first, contains('8x'));
    expect(card.copyWith(isActive: true).communityData?.id, community['id']);
    expect(CreditCard.fromApiJson({'id': 'custom'}).communityData, isNull);
  });

  testWidgets(
    'community details show rewards, benefits, dates, attribution at mobile width',
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
              child: CommunityCardDetails(
                data: CommunityCardData.fromJson(community),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Ultimate Rewards points'), findsOneWidget);
      expect(find.textContaining('The Edit credit'), findsOneWidget);
      expect(find.textContaining('2026-07-23'), findsOneWidget);
      expect(find.textContaining('2026-10-25'), findsOneWidget);
      expect(find.textContaining('OpenCard DB'), findsOneWidget);
      expect(find.textContaining('CC BY 4.0'), findsOneWidget);
      expect(find.text('Issuer terms'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
