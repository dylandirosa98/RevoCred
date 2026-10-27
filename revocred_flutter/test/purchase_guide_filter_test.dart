import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/core/models/purchase_guide.dart';

void main() {
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
