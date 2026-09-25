import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/core/models/app_models.dart';

void main() {
  test('mock strategy selection covers the same S01-S09 matrix', () {
    final cases = [
      (
        code: 'S01',
        credit: 'building',
        goal: 'cash_back',
        fee: 'low',
        travel: 'domestic',
      ),
      (
        code: 'S02',
        credit: 'building',
        goal: 'travel',
        fee: 'low',
        travel: 'both',
      ),
      (
        code: 'S03',
        credit: 'fair',
        goal: 'cash_back',
        fee: 'low',
        travel: 'domestic',
      ),
      (code: 'S04', credit: 'fair', goal: 'travel', fee: 'low', travel: 'both'),
      (
        code: 'S05',
        credit: 'good',
        goal: 'travel',
        fee: 'high',
        travel: 'international',
      ),
      (
        code: 'S06',
        credit: 'good',
        goal: 'travel',
        fee: 'low',
        travel: 'international',
      ),
      (
        code: 'S06',
        credit: 'good',
        goal: 'travel',
        fee: 'high',
        travel: 'both',
      ),
      (
        code: 'S07',
        credit: 'good',
        goal: 'cash_back',
        fee: 'high',
        travel: 'both',
      ),
      (
        code: 'S08',
        credit: 'good',
        goal: 'travel',
        fee: 'high',
        travel: 'domestic',
      ),
      (
        code: 'S09',
        credit: 'excellent',
        goal: 'travel',
        fee: 'high',
        travel: 'both',
      ),
    ];

    for (final item in cases) {
      final plan = StrategyPlan.fromAnswers(
        QuestionnaireAnswers(
          lifeStage: 'adult-building',
          existingCardIds: const [],
          feeTolerance: item.fee,
          travelScope: item.travel,
          creditTier: item.credit,
          monthlySpend: const {'everyday': 100},
          rewardsGoal: item.goal,
        ),
      );
      expect(plan.code, item.code);
    }
  });
}
