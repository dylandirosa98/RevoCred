import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/core/data/demo_seed.dart';
import 'package:revocred_flutter/core/logic/demo_purchase_guide.dart';
import 'package:revocred_flutter/core/models/purchase_guide.dart';

void main() {
  test(
    'supported rent terms take priority and removed cards cannot survive fallback',
    () {
      final category = PurchaseCategory.fromJson({
        'id': 'rent',
        'label': 'Rent',
        'options': [
          {'card_id': 'rent', 'rate': 1},
        ],
        'fallback_options': [
          {'card_id': 'base', 'rate': 2},
        ],
      });
      expect(
        category.forWallet({'rent', 'base'}).displayOptions.first.cardId,
        'rent',
      );
      expect(category.forWallet({'rent', 'base'}).isFallback, isFalse);
      expect(category.forWallet({'base'}).displayOptions.first.cardId, 'base');
      expect(category.forWallet({'base'}).isFallback, isTrue);
      expect(category.forWallet({}).displayOptions, isEmpty);
      expect(category.forWallet({}).isFallback, isFalse);
    },
  );

  test(
    'offline rent mirrors conditional base fallback without inventing rent rewards',
    () {
      final rent = demoPurchaseGuide(
        createDemoAppData().wallet,
      ).category('rent')!;
      expect(rent.options, isEmpty);
      expect(rent.isFallback, isTrue);
      expect(rent.fallbackOptions.first.cardId, 'venture-x');
      expect(rent.fallbackOptions.first.rate, 2);
      expect(rent.fallbackOptions.first.conditions.join(' '), contains('fees'));
    },
  );

  test(
    'wallet filter recomputes ties and removes card-specific stale warnings',
    () {
      final category = PurchaseCategory.fromJson({
        'id': 'dining',
        'label': 'Dining',
        'tied': true,
        'options': [
          {
            'card_id': 'a',
            'card_name': 'A',
            'rate': 2,
            'earn_label': '2x',
            'reason': 'Known rate',
          },
          {
            'card_id': 'b',
            'card_name': 'B',
            'rate': 2,
            'earn_label': '2x',
            'reason': 'Known rate',
          },
        ],
        'unknown': ['A: extra terms pending', 'B: extra terms pending'],
        'unknown_card_ids': ['a', 'b'],
      });
      final filtered = category.forWallet({'a'});
      expect(filtered.options.length, 1);
      expect(filtered.tied, isFalse);
      expect(filtered.unknown, ['A: extra terms pending']);
    },
  );
}
