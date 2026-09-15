import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/core/logic/demo_recommendation.dart';
import 'package:revocred_flutter/core/models/app_models.dart';

void main() {
  test('same questionnaire answers always produce same transparent result', () {
    const answers = QuestionnaireAnswers(
      lifeStage: 'adult-building',
      existingCardIds: [],
      feeTolerance: 'low',
      travelScope: 'both',
      creditTier: 'good',
      monthlySpend: {'rent': 1000, 'food': 500, 'travel': 100, 'everyday': 200},
      rewardsGoal: 'travel',
    );

    final first = computeDemoRecommendation(answers);
    final second = computeDemoRecommendation(answers);

    expect(first.cardId, 'bilt');
    expect(first.cardId, second.cardId);
    expect(first.estimatedYearlyValue, 540);
    expect(
      first.formula,
      contains(r'Entered monthly spend ($1800) x 12 x 2.5%'),
    );
  });

  test('building credit takes precedence over reward category', () {
    const answers = QuestionnaireAnswers(
      lifeStage: 'adult-learning',
      existingCardIds: [],
      feeTolerance: 'high',
      travelScope: 'international',
      creditTier: 'building',
      monthlySpend: {'rent': 0, 'food': 100, 'travel': 2000, 'everyday': 0},
      rewardsGoal: 'travel',
    );

    expect(computeDemoRecommendation(answers).cardId, 'freedom-rise');
  });
}
