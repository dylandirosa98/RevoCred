import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/core/logic/playbook.dart';

void main() {
  test('S04 marks Freedom Unlimited as owned and Flex as next', () {
    final got = buildPlaybook(
      code: 'S04',
      walletNames: const ['Freedom Unlimited', 'Amex Gold'],
    );
    expect(got?.nextCard, 'Freedom Flex');
    expect(got?.steps.first.status, 'have');
    expect(got?.unused.single.name, 'Amex Gold');
    expect(got?.alternatives, isNotEmpty);
  });

  test('Savor substitutes for SavorOne', () {
    final got = buildPlaybook(code: 'S03', walletNames: const ['Savor']);
    expect(got?.steps.first.status, 'have');
    expect(got?.nextCard, 'Quicksilver');
  });
}
