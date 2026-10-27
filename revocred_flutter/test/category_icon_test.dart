import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/shared/widgets/category_icon.dart';

void main() {
  test('primary and more-category icons have explicit colorful designs', () {
    final colors = <Color>{};
    for (final category in [
      'Dining',
      'Groceries',
      'Travel',
      'Gas',
      'Transit',
      'Online shopping',
      'Rent',
      'Streaming',
      'Entertainment',
      'Drugstores',
      'Wholesale clubs',
      'Utilities',
      'Phone & internet',
      'Home improvement',
      'Office supplies',
      'General purchases',
    ]) {
      final (_, color) = CategoryIcon.designFor(category);
      expect(color, isNot(Colors.black));
      colors.add(color);
    }
    expect(colors.length, 16);
  });
}
