import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/core/data/demo_seed.dart';
import 'package:revocred_flutter/core/logic/card_search.dart';

void main() {
  test('search ranks exact card name and supports issuer tokens', () {
    final exact = searchCards(demoCatalog, 'Venture X');
    expect(exact.first.id, 'venture-x');

    final issuer = searchCards(demoCatalog, 'Chase freedom');
    expect(
      issuer.map((card) => card.id),
      containsAll(['freedom-unlimited', 'freedom-flex', 'freedom-rise']),
    );
  });

  test('empty and unrelated searches return no results', () {
    expect(searchCards(demoCatalog, '  '), isEmpty);
    expect(searchCards(demoCatalog, 'not-a-real-card'), isEmpty);
  });
}
