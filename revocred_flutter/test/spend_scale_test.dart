import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/core/logic/spend_scale.dart';

void main() {
  test('spend slider is finer for smaller amounts', () {
    expect(SpendScale.stops.first, 0);
    expect(SpendScale.stops.last, SpendScale.max);
    expect(SpendScale.stops.take(4), [0, 10, 20, 30]);
    expect(SpendScale.stops, containsAllInOrder([490, 500, 525, 1500, 1550]));
    expect(SpendScale.stops, containsAllInOrder([2950, 3000, 3100, 4900]));
    for (var i = 1; i < SpendScale.stops.length; i++) {
      expect(SpendScale.stops[i], greaterThan(SpendScale.stops[i - 1]));
    }
    // Half of the slider covers $0 to $1,000.
    expect(SpendScale.amountAt(SpendScale.divisions / 2), 1000);
  });

  test('every stop round-trips and off-grid amounts snap to the nearest', () {
    for (final amount in SpendScale.stops) {
      expect(SpendScale.amountAt(SpendScale.positionOf(amount)), amount);
    }
    expect(SpendScale.amountAt(SpendScale.positionOf(3050)), anyOf(3000, 3100));
    expect(SpendScale.amountAt(SpendScale.positionOf(99999)), SpendScale.max);
    expect(SpendScale.amountAt(-3), 0);
  });
}
