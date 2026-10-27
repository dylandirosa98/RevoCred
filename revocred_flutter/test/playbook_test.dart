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
    expect(got?.steps.first.coveredBy, 'Freedom Unlimited');
    expect(got?.unused.single.name, 'Amex Gold');
    expect(got?.alternatives, isNotEmpty);
  });

  test('Savor substitutes for SavorOne', () {
    final got = buildPlaybook(code: 'S03', walletNames: const ['Savor']);
    expect(got?.steps.first.status, 'have');
    expect(got?.steps.first.coveredBy, 'Savor');
    expect(got?.nextCard, 'Quicksilver');
  });

  test('does not mention a substitute the member does not own', () {
    final got = buildPlaybook(code: 'S03', walletNames: const []);
    expect(got?.steps.first.name, 'SavorOne');
    expect(got?.steps.first.status, 'next');
    expect(got?.steps.first.coveredBy, isEmpty);
    expect(got?.steps.first.note, isEmpty);
  });
}
