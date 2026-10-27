import '../models/app_models.dart';

class StrategyDigest {
  const StrategyDigest({
    required this.title,
    required this.goal,
    required this.currentCards,
    required this.spending,
    required this.nextMove,
    required this.usage,
    required this.order,
    required this.annualValue,
  });

  final String title;
  final String goal;
  final List<String> currentCards;
  final List<(String, int)> spending;
  final String nextMove;
  final List<String> usage;
  final List<String> order;
  final int annualValue;
}

enum StrategySlotStatus { completed, substituted, next, later, unavailable }

String strategyTimingCaption(StrategyRoadmapSlot slot) => switch (slot.status) {
  StrategySlotStatus.completed => 'Already in your wallet',
  StrategySlotStatus.substituted => 'Covered by your current card',
  StrategySlotStatus.next =>
    slot.timing == 'Timing not available'
        ? 'Check eligibility first'
        : slot.timing,
  StrategySlotStatus.later =>
    slot.timing == 'Timing not available'
        ? 'Timing not yet known'
        : slot.timing ==
              'Wait approximately 3-6 months after the previous application'
        ? 'Approx. 3–6 months after prior card'
        : slot.timing,
  StrategySlotStatus.unavailable => 'No application recommended',
};

String strategyFeePreference(AppData data) =>
    switch (data.questionnaireAnswers?.feeTolerance) {
      'none' || '0' => 'No annual fee',
      'low' => 'Open to modest annual fees',
      'mid' => r'Open to annual fees up to $300',
      'high' => 'Open to premium annual fees',
      _ => '${data.strategyPlan?.feeLevel ?? 'Unknown'} fee preference',
    };

class StrategyRoadmapSlot {
  const StrategyRoadmapSlot({
    required this.targetName,
    required this.displayName,
    required this.use,
    required this.note,
    required this.status,
    this.timing = 'Timing not available',
    this.timingNote =
        'Verify account history and issuer rules before applying.',
  });

  final String targetName;
  final String displayName;
  final String use;
  final String note;
  final StrategySlotStatus status;
  final String timing;
  final String timingNote;

  bool get isCovered =>
      status == StrategySlotStatus.completed ||
      status == StrategySlotStatus.substituted;
}

/// Resolves the selected strategy into wallet-aware roles. Substitutes only
/// appear when the server/playbook has matched one of the member's owned cards;
/// this helper never advertises an unowned alternative.
List<StrategyRoadmapSlot> strategyRoadmapSlots(AppData data) {
  final playbook = data.playbook;
  if (playbook != null && playbook.steps.isNotEmpty) {
    final orderedSteps = [...playbook.steps];
    int rank(String status) => switch (status) {
      'have' => 0,
      'next' => 1,
      'later' => 2,
      _ => 3,
    };
    // Preserve server role order within each group; actionable next always
    // precedes conditional future applications, even if appended by the server.
    final indexed = orderedSteps.indexed.toList()
      ..sort((a, b) {
        final result = rank(a.$2.status).compareTo(rank(b.$2.status));
        return result == 0 ? a.$1.compareTo(b.$1) : result;
      });
    return indexed.map((entry) {
      final step = entry.$2;
      final coveredBy = step.coveredBy.trim();
      final substituted =
          step.status == 'have' &&
          coveredBy.isNotEmpty &&
          _normalizeCard(coveredBy) != _normalizeCard(step.name);
      return StrategyRoadmapSlot(
        targetName: step.name,
        displayName: coveredBy.isEmpty ? step.name : coveredBy,
        use: step.use,
        note: step.note.isEmpty ? step.use : step.note,
        timing: step.status == 'have'
            ? 'Already covered'
            : step.status == 'unavailable'
            ? 'Do not apply now'
            : step.timing.isEmpty
            ? 'Timing not available'
            : step.timing,
        timingNote: step.status == 'have'
            ? 'No new application needed.'
            : step.timingNote.isEmpty
            ? 'Opening dates and inquiry history were not collected. Verify issuer rules before applying.'
            : step.timingNote,
        status: substituted
            ? StrategySlotStatus.substituted
            : switch (step.status) {
                'have' => StrategySlotStatus.completed,
                'next' => StrategySlotStatus.next,
                'unavailable' => StrategySlotStatus.unavailable,
                _ => StrategySlotStatus.later,
              },
      );
    }).toList();
  }

  final slots = <StrategyRoadmapSlot>[];
  for (final target in data.strategyPlan?.cards ?? const <String>[]) {
    final owned = _walletCardFor(data, target);
    final step = _roadmapStepFor(data, target);
    final status = owned != null
        ? StrategySlotStatus.completed
        : switch (step?.stage.toLowerCase() ?? '') {
            final stage
                when stage.contains('unavailable') ||
                    stage.contains('not currently') =>
              StrategySlotStatus.unavailable,
            final stage when stage.contains('later') =>
              StrategySlotStatus.later,
            _ => StrategySlotStatus.next,
          };
    slots.add(
      StrategyRoadmapSlot(
        targetName: target,
        displayName: owned?.name ?? target,
        use: step?.note ?? '',
        note: step?.note ?? '',
        status: status,
      ),
    );
  }
  if (slots.isNotEmpty) return slots;

  return data.roadmap
      .map(
        (step) => StrategyRoadmapSlot(
          targetName: step.cardId,
          displayName: strategyCardFor(data, step.cardId)?.name ?? step.cardId,
          use: step.note,
          note: step.note,
          status: step.stage.toLowerCase().contains('unavailable')
              ? StrategySlotStatus.unavailable
              : StrategySlotStatus.next,
        ),
      )
      .toList();
}

int strategyCoveredRoleCount(AppData data) =>
    strategyRoadmapSlots(data).where((slot) => slot.isCovered).length;

/// The first card the member can act on in the currently displayed roadmap.
///
/// UI surfaces must use this instead of [UserProfile.nextTarget]. The profile
/// field is persisted independently and can lag behind a newly generated
/// roadmap.
RoadmapStep? strategyNextActionStep(AppData data) {
  final playbook = data.playbook;
  if (playbook != null) {
    for (final step in playbook.steps) {
      if (step.status != 'next') continue;
      return RoadmapStep(
        id: '${playbook.code}-next',
        cardId: step.name,
        stage: 'Consider next',
        note: step.note.isEmpty ? step.use : step.note,
        estimatedValue: 0,
      );
    }
    return null;
  }
  for (final step in data.roadmap) {
    final stage = step.stage.toLowerCase();
    if (stage.contains('already') ||
        stage.contains('in wallet') ||
        stage.contains('unavailable') ||
        stage.contains('not currently')) {
      continue;
    }
    final card = strategyCardFor(data, step.cardId);
    if (card?.isActive == true || _walletContains(data, step.cardId)) continue;
    return step;
  }
  return null;
}

String? strategyNextCardName(AppData data) {
  final step = strategyNextActionStep(data);
  if (step == null) return null;
  return strategyCardFor(data, step.cardId)?.name ?? step.cardId;
}

/// Catalog cards ordered for the strategy screen rather than by seed order.
/// Roadmap cards lead, followed by the remaining cards for broader discovery.
List<CreditCard> strategyComparisonCards(AppData data, {int limit = 4}) {
  final cards = <CreditCard>[];
  void add(CreditCard? card) {
    if (card == null || card.isActive) return;
    if (cards.any((item) => item.id == card.id)) return;
    cards.add(card);
  }

  for (final slot in strategyRoadmapSlots(data)) {
    if (!slot.isCovered) add(strategyCardFor(data, slot.displayName));
  }
  for (final card in data.catalog) {
    add(card);
  }
  return cards.take(limit).toList();
}

/// The complete target wallet for the selected strategy, including cards the
/// member already owns. This is distinct from the application roadmap, which
/// should contain only missing cards.
List<CreditCard> strategyTargetCards(AppData data) {
  final targets = <CreditCard>[];
  for (final slot in strategyRoadmapSlots(data)) {
    final card = strategyCardFor(data, slot.displayName);
    if (card != null && !targets.any((item) => item.id == card.id)) {
      targets.add(card);
    }
  }
  if (targets.isNotEmpty) return targets;
  for (final step in data.roadmap) {
    final card = strategyCardFor(data, step.cardId);
    if (card != null && !targets.any((item) => item.id == card.id)) {
      targets.add(card);
    }
  }
  return targets;
}

CreditCard? strategyCardFor(AppData data, String identity) {
  final needle = _normalizeCard(identity);
  for (final card in [...data.wallet, ...data.catalog]) {
    if (card.id == identity || _normalizeCard(card.name) == needle) return card;
  }
  for (final card in [...data.wallet, ...data.catalog]) {
    final name = _normalizeCard(card.name);
    if (needle.contains(name) || name.contains(needle)) return card;
  }
  return null;
}

StrategyDigest strategyDigest(AppData data) {
  final plan = data.strategyPlan;
  final nextStep = strategyNextActionStep(data);
  final nextCard = strategyNextCardName(data);
  final questionnaireName = data.questionnaireAnswers?.displayName.trim() ?? '';
  final spending =
      data.monthlySpend.entries.where((entry) => entry.value > 0).toList()
        ..sort((a, b) => b.value.compareTo(a.value));
  return StrategyDigest(
    title: _strategyTitle(
      questionnaireName.isNotEmpty ? questionnaireName : data.profile.name,
    ),
    goal:
        '${plan?.goal ?? 'Rewards'} • ${_walletSize(data)} ideal wallet • ${plan?.travelScope ?? 'your travel plans'}',
    currentCards: data.wallet
        .map(
          (card) => card.termsUnknown
              ? '${card.name} (terms not entered)'
              : card.name,
        )
        .toList(),
    spending: spending
        .take(5)
        .map((entry) => (entry.key, entry.value))
        .toList(),
    nextMove: nextStep == null || nextCard == null
        ? 'No new application is recommended right now. Keep using your current wallet.'
        : 'Consider next: $nextCard${nextStep.note.trim().isEmpty ? '' : ' — ${nextStep.note.trim()}'}',
    usage: data.wallet
        .map((card) => '${card.bestUse}: ${card.name}')
        .where((line) => !line.startsWith(':'))
        .toList(),
    order: data.roadmap.map((step) => '${step.stage}: ${step.cardId}').toList(),
    annualValue: data.projectedYearlyValue,
  );
}

bool _walletContains(AppData data, String identity) {
  final needle = _normalizeCard(identity);
  return data.wallet.any(
    (card) => card.id == identity || _normalizeCard(card.name) == needle,
  );
}

CreditCard? _walletCardFor(AppData data, String identity) {
  final needle = _normalizeCard(identity);
  for (final card in data.wallet) {
    if (card.id == identity || _normalizeCard(card.name) == needle) return card;
  }
  return null;
}

RoadmapStep? _roadmapStepFor(AppData data, String identity) {
  final needle = _normalizeCard(identity);
  for (final step in data.roadmap) {
    if (step.cardId == identity || _normalizeCard(step.cardId) == needle) {
      return step;
    }
    final card = strategyCardFor(data, step.cardId);
    if (card != null && _normalizeCard(card.name) == needle) return step;
  }
  return null;
}

String _normalizeCard(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

String _walletSize(AppData data) {
  final preference = data.questionnaireAnswers?.idealCardCount.trim() ?? '';
  if (preference.isNotEmpty) return '$preference cards';
  return '${data.wallet.length} active ${data.wallet.length == 1 ? 'card' : 'cards'}';
}

String _strategyTitle(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty || trimmed.toLowerCase() == 'member') {
    return 'Your Personalized Credit Card Strategy';
  }
  final firstName = trimmed.split(RegExp(r'\s+')).first;
  final possessive = firstName.toLowerCase().endsWith('s')
      ? "$firstName’"
      : "$firstName’s";
  return '$possessive Personalized Credit Card Strategy';
}
