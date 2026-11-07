import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/core/logic/card_detail_text.dart';
import 'package:revocred_flutter/core/models/app_models.dart';

void main() {
  test('quarterly cap is readable spending, not a raw JSON blob', () {
    const raw =
        '5% — Rotating categories (activation required) · cap: '
        '{"amount":1500,"period":"quarter","currency":"USD"}';
    expect(
      cardDetailText(raw),
      r'5% — Rotating categories (activation required) · Spending limit: $1,500 per quarter',
    );
  });

  test('annual and introductory caps retain their actual periods', () {
    expect(
      cardDetailText(
        '4x — U.S. supermarkets · cap: '
        '{"amount":25000,"currency":"USD","period":"calendar_year"}',
      ),
      r'4x — U.S. supermarkets · Spending limit: $25,000 per calendar year',
    );
    expect(
      cardDetailText(
        '3% — Dining for new cardmembers · cap: '
        '{"amount":6000,"currency":"USD","period":"first_6_months"}',
      ),
      r'3% — Dining for new cardmembers · Spending limit: $6,000 in the first 6 months',
    );
  });

  test('malformed or incomplete caps stay unknown rather than unlimited', () {
    for (final cap in [
      '{"amount":null,"currency":"USD","period":"quarter"}',
      '{"amount":1500,"currency":"USD"}',
      '{invalid}',
      'null',
    ]) {
      final display = cardDetailText('5% — Activation required · cap: $cap');
      expect(display, contains('Activation required'));
      expect(display, contains('Spending limit: see issuer terms'));
      expect(display, isNot(contains('{')));
      expect(display, isNot(contains('unlimited')));
    }
    expect(
      cardDetailText('No foreign transaction fee'),
      'No foreign transaction fee',
    );
    expect(
      cardDetailText('Hotel credit — Enrollment required; two-night minimum.'),
      'Hotel credit — Enrollment required; two-night minimum.',
    );
  });

  test('travel credit fields form one readable benefit with real cadence', () {
    final lines = cardTravelPerkText([
      'Global entry credit · Amount: 120',
      'Global entry credit · Currency: USD',
      'Global entry credit · Period: every 4 years',
      'Lounge access · Program: Priority Pass',
      'Lounge access · Notes: Enrollment required; two guests',
      'Hotel status: IHG Platinum through 2027-12-31',
      'Other: No foreign transaction fees',
    ]);
    expect(lines, contains(r'Global entry credit — $120 every 4 years'));
    expect(
      lines,
      contains(
        'Lounge access — Priority Pass · Enrollment required; two guests',
      ),
    );
    expect(lines, contains('Hotel status — IHG Platinum through 2027-12-31'));
    expect(lines, contains('No foreign transaction fees'));
    expect(lines, hasLength(4));
  });

  test('unknown travel limits, zero values and source conditions survive', () {
    final lines = cardTravelPerkText([
      'Global entry credit · Currency: USD',
      'Global entry credit · Period: see_issuer_terms',
      'New perk · Limit: 0',
      'New perk · Enabled: true',
      'Free checked bags: false',
    ]);
    expect(lines, contains('Global entry credit — See issuer terms'));
    expect(lines, contains('New perk — Limit: 0 · Enabled: Yes'));
    expect(lines, contains('Free checked bags — Not included'));
    expect(lines.join(' '), isNot(contains('unlimited')));
    expect(lines.join(' '), isNot(contains('true')));
    expect(lines.join(' '), isNot(contains('false')));
  });

  test(
    'all current catalog display text is code-free without changing evidence',
    () {
      final cards =
          jsonDecode(
                File(
                  '../revocred-api/internal/valuation/testdata/catalog.json',
                ).readAsStringSync(),
              )
              as List;
      expect(cards, hasLength(15));
      final code = RegExp(
        r'[{}]|map\[|\b(?:null|true|false)\b|"(?:amount|currency|period)"',
      );
      for (final raw in cards.cast<Map<String, dynamic>>()) {
        final data = CreditCard.fromApiJson(raw).communityData;
        expect(data, isNotNull, reason: raw['name'] as String);
        final original = [
          ...data!.rewardRates,
          ...data.benefits,
          ...data.travelPerks,
        ];
        final display = [
          ...data.rewardRates.map(cardDetailText),
          ...data.benefits.map(cardDetailText),
          ...cardTravelPerkText(data.travelPerks),
        ];
        for (final line in display) {
          expect(code.hasMatch(line), isFalse, reason: '${raw['name']}: $line');
        }
        expect([
          ...data.rewardRates,
          ...data.benefits,
          ...data.travelPerks,
        ], original);
      }
    },
  );
}
