import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/core/data/demo_seed.dart';
import 'package:revocred_flutter/core/logic/card_search.dart';
import 'package:revocred_flutter/core/models/app_models.dart';

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

  test('issuer search puts popular issuer-owned cards before partners', () {
    final cards = [
      _searchCard('costco', 'Citi', 'Costco Anywhere Visa'),
      _searchCard('custom-cash', 'Citi', 'Custom Cash'),
      _searchCard('aadvantage', 'Citi', 'AAdvantage Platinum Select'),
      _searchCard('double-cash', 'Citi', 'Double Cash'),
    ];

    expect(searchCards(cards, 'citibank').map((card) => card.id), [
      'custom-cash',
      'double-cash',
      'aadvantage',
      'costco',
    ]);
    // A specific partner-card search must still surface the exact card first.
    expect(searchCards(cards, 'Costco Anywhere Visa').first.id, 'costco');
  });

  test('search recognizes Bilt and Atmos card names', () {
    final cards = [
      _searchCard('bilt', 'Bilt', 'Bilt Mastercard'),
      _searchCard(
        'atmos-ascent',
        'Bank of America',
        'Atmos Rewards Ascent Visa Signature',
      ),
    ];

    expect(searchCards(cards, 'Bilt').single.id, 'bilt');
    expect(searchCards(cards, 'Atmos').single.id, 'atmos-ascent');
  });
}

const _emptyBenefits = <String>[];

CreditCard _searchCard(String id, String issuer, String name) => CreditCard(
  id: id,
  issuer: issuer,
  brand: 'Visa',
  name: name,
  annualFee: r'$0',
  bestUse: '',
  multiplier: '1x',
  benefits: _emptyBenefits,
);
