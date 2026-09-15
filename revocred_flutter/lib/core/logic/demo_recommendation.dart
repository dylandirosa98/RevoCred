import '../models/app_models.dart';

DemoRecommendation computeDemoRecommendation(QuestionnaireAnswers answers) {
  final sortedSpend = answers.monthlySpend.entries.toList()
    ..sort((a, b) {
      final amountOrder = b.value.compareTo(a.value);
      return amountOrder != 0 ? amountOrder : a.key.compareTo(b.key);
    });
  final topCategory = sortedSpend.firstOrNull?.key ?? 'everyday';
  final totalMonthly = answers.monthlySpend.values.fold<int>(
    0,
    (a, b) => a + b,
  );

  String cardId;
  String cardName;
  final reasons = <String>[];
  if (answers.creditTier == 'building') {
    cardId = 'freedom-rise';
    cardName = 'Freedom Rise';
    reasons.add('A credit-building path is prioritized over premium rewards.');
  } else if (topCategory == 'rent') {
    cardId = 'bilt';
    cardName = 'Bilt Mastercard';
    reasons.add('Rent is your largest entered monthly category.');
  } else if (answers.rewardsGoal == 'travel' &&
      answers.feeTolerance == 'high') {
    cardId = 'venture-x';
    cardName = 'Venture X';
    reasons.add('Premium travel matches your goal and stated fee tolerance.');
  } else if (answers.rewardsGoal == 'travel') {
    cardId = 'sapphire-preferred';
    cardName = 'Sapphire Preferred';
    reasons.add('Transferable travel points fit your selected rewards goal.');
  } else if (topCategory == 'food') {
    cardId = answers.feeTolerance == 'none' ? 'savor' : 'amex-gold';
    cardName = answers.feeTolerance == 'none' ? 'Savor' : 'Amex Gold';
    reasons.add('Food is your largest entered monthly category.');
  } else {
    cardId = 'freedom-unlimited';
    cardName = 'Freedom Unlimited';
    reasons.add('A simple catch-all card fits the entered spending mix.');
  }

  reasons.add(
    answers.travelScope == 'none'
        ? 'No travel focus was selected.'
        : '${_title(answers.travelScope)} travel was selected.',
  );
  if (answers.existingCardIds.contains(cardId)) {
    reasons.add(
      'You already listed this card, so optimize it before applying for another.',
    );
  }

  final rewardRate = answers.rewardsGoal == 'travel' ? 0.025 : 0.02;
  final estimatedValue = (totalMonthly * 12 * rewardRate).round();
  return DemoRecommendation(
    cardId: cardId,
    cardName: cardName,
    estimatedYearlyValue: estimatedValue,
    reasons: reasons,
    formula:
        'Entered monthly spend (\$$totalMonthly) x 12 x ${(rewardRate * 100).toStringAsFixed(1)}% demo value rate.',
  );
}

String _title(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
