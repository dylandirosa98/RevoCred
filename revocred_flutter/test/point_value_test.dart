import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/core/models/app_models.dart';
import 'package:revocred_flutter/core/logic/ongoing_value.dart';
import 'package:revocred_flutter/core/logic/wallet_score.dart';
import 'package:revocred_flutter/core/logic/demo_purchase_guide.dart';

void main() {
  CreditCard card(String id, double dining, double base, {double? value}) =>
      CreditCard.fromApiJson({
        'id': id,
        'name': id,
        'reward_rates': {'other': base, 'dining': dining},
        'point_value_cents': value ?? 1,
      }, isActive: true);

  test(
    'hotel points keep earning labels but use cash value throughout mirrors',
    () {
      final hotel = card('hotel', 5, 3, value: .5).copyWith(isActive: true);
      final gold = card('gold', 4, 1);
      expect(hotel.pointValueCents, .5);
      expect(hotel.pointMultipliers, contains('5.0x dining'));
      expect(hotel.modeledRates['dining'], 5);
      expect(gold.pointValueCents, 1);
      expect(card('zero', 4, 1, value: 0).pointValueCents, 1);
      expect(walletCapabilities([hotel, gold]).dining, 4);
      expect(walletCapabilities([hotel]).dining, 2.5);
      expect(
        estimateOngoingValue(
          [hotel],
          {'dining': 100, 'everyday': 100},
          'none',
        ).rewardsCents,
        4800,
      );
      expect(
        estimateOngoingValue(
          [hotel, gold],
          {'dining': 100, 'everyday': 100},
          'none',
        ).totalCents,
        6600,
      );
      final dining = demoPurchaseGuide([hotel, gold]).categories.first;
      expect(dining.options.first.cardId, 'gold');
      expect(dining.options.last.rate, 5);
      expect(dining.options.last.earnLabel, '5x demo rate');
      expect(dining.options.last.comparisonRate, 2.5);
      expect(dining.tied, false);
      expect(
        demoPurchaseGuide([hotel, card('tie', 2.5, 1)]).categories.first.tied,
        true,
      );
    },
  );

  test('legacy card JSON also parses point valuation', () {
    final hotel = CreditCard.fromJson({
      'id': 'hotel',
      'name': 'Hilton',
      'point_value_cents': .5,
    });
    expect(hotel.pointValueCents, .5);
    expect(hotel.cashEquivalentRate(5), 2.5);
  });
}
