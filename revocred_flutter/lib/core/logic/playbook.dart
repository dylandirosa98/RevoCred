import '../models/app_models.dart';

class PlaybookAssignment {
  const PlaybookAssignment({
    required this.code,
    required this.title,
    required this.ecosystem,
    required this.steps,
    required this.unused,
    required this.alternatives,
    this.nextCard = '',
    this.debitCard = '',
  });

  factory PlaybookAssignment.fromJson(Map<String, dynamic> json) {
    return PlaybookAssignment(
      code: (json['code'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      ecosystem: (json['ecosystem'] ?? '').toString(),
      nextCard: (json['next_card'] ?? '').toString(),
      debitCard: (json['debit_card'] ?? '').toString(),
      steps: (json['steps'] as List? ?? const [])
          .map(
            (item) =>
                PlaybookStep.fromJson((item as Map).cast<String, dynamic>()),
          )
          .toList(),
      unused: (json['unused_cards'] as List? ?? const [])
          .map(
            (item) => UnusedPlaybookCard.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
          )
          .toList(),
      alternatives: (json['alternatives'] as List? ?? const [])
          .map(
            (item) => PlaybookAlternative.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
          )
          .toList(),
    );
  }

  final String code;
  final String title;
  final String ecosystem;
  final String nextCard;
  final String debitCard;
  final List<PlaybookStep> steps;
  final List<UnusedPlaybookCard> unused;
  final List<PlaybookAlternative> alternatives;
}

class PlaybookStep {
  const PlaybookStep({
    required this.name,
    required this.use,
    required this.status,
    this.note = '',
    this.coveredBy = '',
    this.timing = '',
    this.timingNote = '',
  });

  factory PlaybookStep.fromJson(Map<String, dynamic> json) => PlaybookStep(
    name: (json['name'] ?? '').toString(),
    use: (json['use'] ?? '').toString(),
    status: (json['status'] ?? '').toString(),
    note: (json['note'] ?? '').toString(),
    coveredBy: (json['covered_by'] ?? '').toString(),
    timing: (json['timing'] ?? '').toString(),
    timingNote: (json['timing_note'] ?? '').toString(),
  );

  final String name;
  final String use;
  final String status;
  final String note;
  final String coveredBy;
  final String timing;
  final String timingNote;
}

class UnusedPlaybookCard {
  const UnusedPlaybookCard({
    required this.name,
    required this.action,
    required this.note,
  });

  factory UnusedPlaybookCard.fromJson(Map<String, dynamic> json) =>
      UnusedPlaybookCard(
        name: (json['name'] ?? '').toString(),
        action: (json['action'] ?? '').toString(),
        note: (json['note'] ?? '').toString(),
      );

  final String name;
  final String action;
  final String note;
}

class PlaybookAlternative {
  const PlaybookAlternative({
    required this.code,
    required this.title,
    required this.reason,
  });

  factory PlaybookAlternative.fromJson(Map<String, dynamic> json) =>
      PlaybookAlternative(
        code: (json['code'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        reason: (json['reason'] ?? '').toString(),
      );

  final String code;
  final String title;
  final String reason;
}

PlaybookAssignment? buildPlaybook({
  required String? code,
  required List<String> walletNames,
}) {
  final plan = StrategyPlan.maybeForCode(code);
  if (plan == null) return null;
  final used = <String>{};
  final steps = <PlaybookStep>[];
  var foundNext = false;
  var nextCard = '';
  for (final name in plan.cards) {
    final match = _matchWallet(name, walletNames);
    if (match != null) {
      used.add(_normalize(match));
      final substituted = _normalize(match) != _normalize(name);
      steps.add(
        PlaybookStep(
          name: name,
          use: _cardUse[name] ?? 'Use this card as specified by the playbook.',
          status: 'have',
          coveredBy: match,
          note: !substituted
              ? ''
              : 'Keep your $match; it covers the $name role in this strategy.',
        ),
      );
      continue;
    }
    if (!foundNext) {
      foundNext = true;
      nextCard = name;
      steps.add(
        PlaybookStep(
          name: name,
          use: _cardUse[name] ?? 'Use this card as specified by the playbook.',
          status: 'next',
          timing: 'Consider now, after checks',
          timingNote:
              'Verify recent applications, account age, issuer rules and budget first. Eligibility timing is unknown without account history.',
        ),
      );
    } else {
      steps.add(
        PlaybookStep(
          name: name,
          use: _cardUse[name] ?? 'Use this card as specified by the playbook.',
          status: 'later',
          timing:
              'Wait approximately 3-6 months after the previous application',
          timingNote:
              'Planning estimate only. Re-run recommendations after the previous card; proceed only if it still adds value and issuer rules permit.',
        ),
      );
    }
  }
  final unused = [
    for (final held in walletNames)
      if (held.isNotEmpty && !used.contains(_normalize(held)))
        UnusedPlaybookCard(
          name: held,
          action: 'avoid_for_this_strategy',
          note:
              'Keep it if you want, but do not use it as a primary card in this playbook.',
        ),
  ];
  return PlaybookAssignment(
    code: plan.code,
    title: plan.title,
    ecosystem: plan.ecosystem,
    nextCard: nextCard,
    debitCard: plan.debitCard,
    steps: steps,
    unused: unused,
    alternatives: _alternatives(plan.code),
  );
}

const _cardUse = {
  'Savor for Students': 'Dining and groceries while you build credit.',
  'Quicksilver': 'Everyday catch-all cash back.',
  'Freedom Rise': 'Starter card to build Chase history.',
  'Freedom Flex': 'Rotating categories and dining.',
  'Sapphire Preferred': 'Travel portal and transfer partners.',
  'SavorOne': 'Dining, groceries, and entertainment.',
  'Freedom Unlimited': 'Everyday catch-all in the Chase ecosystem.',
  'Venture X': 'Premium travel catch-all and portal spend.',
  'Gold': 'Dining and groceries in the Amex ecosystem.',
  'Platinum': 'Travel credits, lounges, and premium benefits.',
  'Amex Gold': 'Dining and groceries alongside Capital One travel.',
  'Double Cash': 'Simple cash back while you enter Citi.',
  'Strata': 'Everyday Citi categories.',
  'Strata Elite': 'Domestic travel hub in Citi.',
  'Sapphire Reserve': 'Premium Chase travel hub.',
};

const _nearby = {
  'S01': ['S03', 'S02'],
  'S02': ['S04', 'S01'],
  'S03': ['S07', 'S01'],
  'S04': ['S09', 'S06'],
  'S05': ['S06', 'S09'],
  'S06': ['S05', 'S04'],
  'S07': ['S03', 'S09'],
  'S08': ['S09', 'S04'],
  'S09': ['S04', 'S05'],
};

List<PlaybookAlternative> _alternatives(String code) {
  final out = <PlaybookAlternative>[];
  for (final other in _nearby[code] ?? const <String>[]) {
    final plan = StrategyPlan.maybeForCode(other);
    if (plan == null) continue;
    out.add(
      PlaybookAlternative(
        code: plan.code,
        title: plan.title,
        reason: 'A nearby playbook you can switch to later.',
      ),
    );
  }
  return out;
}

String? _matchWallet(String target, List<String> held) {
  final want = _family(target);
  for (final name in held) {
    if (_family(name) == want && want.isNotEmpty) return name;
  }
  return null;
}

String _family(String name) {
  final key = _normalize(name);
  if (key.contains('savor')) return 'savor';
  if (key.contains('quicksilver')) return 'quicksilver';
  if (key.contains('freedomrise')) return 'freedomrise';
  if (key.contains('freedomflex')) return 'freedomflex';
  if (key.contains('freedomunlimited')) return 'freedomunlimited';
  if (key.contains('sapphirepreferred')) return 'sapphirepreferred';
  if (key.contains('sapphirereserve')) return 'sapphirereserve';
  if (key.contains('venturex')) return 'venturex';
  if (key.contains('platinum')) return 'platinum';
  if (key.contains('gold')) return 'gold';
  if (key.contains('doublecash')) return 'doublecash';
  if (key.contains('strataelite')) return 'strataelite';
  if (key.contains('strata')) return 'strata';
  return key;
}

String _normalize(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]'), '')
    .replaceFirst(RegExp(r'^(amex|chase)'), '');
