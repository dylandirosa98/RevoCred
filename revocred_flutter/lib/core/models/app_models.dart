import '../logic/playbook.dart';

enum MessageRole { user, assistant }

class CreditCard {
  const CreditCard({
    required this.id,
    required this.issuer,
    required this.brand,
    required this.name,
    required this.annualFee,
    required this.bestUse,
    required this.multiplier,
    required this.benefits,
    this.pointMultipliers = const [],
    this.transferablePoints = false,
    this.isActive = false,
    this.feeTier = '0',
    this.walletCardId,
    this.sourceDisclaimer =
        'Verify current terms with the issuer. Educational use only.',
  });

  factory CreditCard.fromJson(Map<String, dynamic> json) => CreditCard(
    id: json['id'] as String,
    issuer: (json['issuer'] ?? json['brand'] ?? '') as String,
    brand: (json['brand'] ?? '') as String,
    name: json['name'] as String,
    annualFee: (json['annualFee'] ?? json['annual_fee'] ?? r'$0') as String,
    bestUse: (json['bestUse'] ?? json['best_use'] ?? '') as String,
    multiplier: (json['multiplier'] ?? '1x') as String,
    benefits: _stringList(json['benefits']),
    pointMultipliers: _stringList(
      json['pointMultipliers'] ?? json['point_multipliers'],
    ),
    transferablePoints:
        (json['transferablePoints'] ?? json['transferable_points'] ?? false)
            as bool,
    isActive: (json['isActive'] ?? json['is_active'] ?? false) as bool,
    feeTier: (json['feeTier'] ?? json['annual_fee_tier'] ?? '0') as String,
    walletCardId: (json['walletCardId'] ?? json['wallet_card_id']) as String?,
  );

  factory CreditCard.fromApiJson(
    Map<String, dynamic> json, {
    bool isActive = false,
    String? walletCardId,
  }) {
    final rewardRates = (json['reward_rates'] as Map?)?.cast<String, dynamic>();
    final rates =
        rewardRates?.entries
            .map((entry) => '${entry.value}x ${entry.key.replaceAll('_', ' ')}')
            .toList() ??
        const <String>[];
    final annualFeeCents = (json['annual_fee_cents'] as num?)?.round() ?? 0;
    final strongestRate = rewardRates?.values.whereType<num>().fold<num>(
      0,
      (current, value) => value > current ? value : current,
    );
    return CreditCard(
      id: json['id'].toString(),
      issuer: (json['issuer'] ?? '').toString(),
      brand: (json['network'] ?? json['issuer'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      annualFee: annualFeeCents == 0
          ? r'$0'
          : '\$${(annualFeeCents / 100).toStringAsFixed(0)}',
      bestUse: (json['best_use'] ?? '').toString(),
      multiplier: strongestRate == null ? '1x' : '${strongestRate}x',
      benefits: _stringList(json['benefits']),
      pointMultipliers: rates,
      transferablePoints: json['transferable_points'] == true,
      isActive: isActive,
      walletCardId: walletCardId,
      feeTier: annualFeeCents == 0
          ? '0'
          : annualFeeCents <= 10000
          ? 'low'
          : annualFeeCents <= 30000
          ? 'mid'
          : 'high',
      sourceDisclaimer: () {
        final text = [json['source_disclaimer'], json['summary']]
            .where((item) => item != null && item.toString().trim().isNotEmpty)
            .join(' ')
            .trim();
        return text.isEmpty
            ? 'Verify current terms with the issuer. Educational use only.'
            : text;
      }(),
    );
  }

  final String id;
  final String issuer;
  final String brand;
  final String name;
  final String annualFee;
  final String bestUse;
  final String multiplier;
  final List<String> benefits;
  final List<String> pointMultipliers;
  final bool transferablePoints;
  final bool isActive;
  final String feeTier;
  final String? walletCardId;
  final String sourceDisclaimer;

  CreditCard copyWith({bool? isActive, String? walletCardId}) => CreditCard(
    id: id,
    issuer: issuer,
    brand: brand,
    name: name,
    annualFee: annualFee,
    bestUse: bestUse,
    multiplier: multiplier,
    benefits: benefits,
    pointMultipliers: pointMultipliers,
    transferablePoints: transferablePoints,
    isActive: isActive ?? this.isActive,
    feeTier: feeTier,
    walletCardId: walletCardId ?? this.walletCardId,
    sourceDisclaimer: sourceDisclaimer,
  );
}

class RoadmapStep {
  const RoadmapStep({
    required this.id,
    required this.cardId,
    required this.stage,
    required this.note,
    required this.estimatedValue,
  });

  factory RoadmapStep.fromJson(Map<String, dynamic> json) => RoadmapStep(
    id: json['id'] as String,
    cardId: (json['cardId'] ?? json['card_id']) as String,
    stage: (json['stage'] ?? json['monthLabel'] ?? '') as String,
    note: (json['note'] ?? '') as String,
    estimatedValue:
        (json['estimatedValue'] ?? json['estimated_value'] ?? 0) as int,
  );

  final String id;
  final String cardId;
  final String stage;
  final String note;
  final int estimatedValue;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'].toString(),
    role: json['role'] == 'user' ? MessageRole.user : MessageRole.assistant,
    content: json['content'] as String,
    createdAt:
        DateTime.tryParse(
          (json['createdAt'] ?? json['created_at'] ?? '').toString(),
        ) ??
        DateTime.now(),
  );

  final String id;
  final MessageRole role;
  final String content;
  final DateTime createdAt;
}

class UserProfile {
  const UserProfile({
    required this.name,
    required this.strategy,
    required this.goal,
    required this.topSpendCategories,
    required this.nextTarget,
    required this.email,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: _nonEmpty(json['name'] ?? json['display_name'], 'Member'),
    strategy: _nonEmpty(
      json['strategy'] ?? json['credit_card_strategy'],
      'Not assigned yet',
    ),
    goal: _nonEmpty(json['goal'], 'Complete the questionnaire'),
    topSpendCategories: _profileCategories(
      json['topSpendCategories'] ?? json['top_spend_categories'],
    ),
    nextTarget: _nonEmpty(
      json['nextTarget'] ?? json['next_application_target'],
      'No recommendation yet',
    ),
    email: (json['email'] ?? '') as String,
  );

  final String name;
  final String strategy;
  final String goal;
  final String topSpendCategories;
  final String nextTarget;
  final String email;
}

class StrategyPreferences {
  const StrategyPreferences({
    required this.creditTier,
    required this.rewardsGoal,
    required this.feeToleranceCents,
    required this.travelScope,
  });

  factory StrategyPreferences.fromApiJson(Map<String, dynamic> json) =>
      StrategyPreferences(
        creditTier: (json['credit_tier'] ?? '').toString(),
        rewardsGoal: (json['rewards_goal'] ?? '').toString(),
        feeToleranceCents: (json['fee_tolerance_cents'] as num?)?.round() ?? 0,
        travelScope: (json['travel_scope'] ?? '').toString(),
      );

  final String creditTier;
  final String rewardsGoal;
  final int feeToleranceCents;
  final String travelScope;
}

class StrategyPlan {
  const StrategyPlan({
    required this.code,
    required this.title,
    required this.userType,
    required this.goal,
    required this.feeLevel,
    required this.travelScope,
    required this.ecosystem,
    required this.cards,
    this.debitCard = '',
  });

  final String code;
  final String title;
  final String userType;
  final String goal;
  final String feeLevel;
  final String travelScope;
  final String ecosystem;
  final String debitCard;
  final List<String> cards;

  static StrategyPlan? maybeForCode(String? code) => _definitions[code];

  static StrategyPlan fromAnswers(QuestionnaireAnswers answers) {
    final premium = answers.feeTolerance == 'high';
    final code = switch (answers.creditTier) {
      'building' => answers.rewardsGoal == 'travel' ? 'S02' : 'S01',
      'fair' => answers.rewardsGoal == 'travel' ? 'S04' : 'S03',
      'excellent'
          when answers.rewardsGoal == 'travel' &&
              premium &&
              answers.travelScope == 'both' =>
        'S09',
      _ when answers.rewardsGoal == 'cash_back' && premium => 'S07',
      _ when answers.rewardsGoal == 'cash_back' => 'S03',
      _ when premium && answers.travelScope == 'domestic' => 'S08',
      _ when premium && answers.travelScope == 'international' => 'S05',
      _ when premium && answers.travelScope == 'both' => 'S06',
      _ when answers.travelScope == 'international' => 'S06',
      _ => 'S04',
    };
    return _definitions[code]!;
  }

  static const _definitions = <String, StrategyPlan>{
    'S01': StrategyPlan(
      code: 'S01',
      title: 'Build credit with simple cash back',
      userType: 'Low or no credit',
      goal: 'Cash back',
      feeLevel: 'Low',
      travelScope: 'Not a priority',
      ecosystem: 'Capital One',
      debitCard: 'Capital One 360 Checking',
      cards: ['Savor for Students', 'Quicksilver'],
    ),
    'S02': StrategyPlan(
      code: 'S02',
      title: 'Build toward flexible travel',
      userType: 'Low or no credit',
      goal: 'Travel',
      feeLevel: 'Low',
      travelScope: 'Domestic and international',
      ecosystem: 'Chase',
      debitCard: 'Chase Student Checking',
      cards: ['Freedom Rise', 'Freedom Flex', 'Sapphire Preferred'],
    ),
    'S03': StrategyPlan(
      code: 'S03',
      title: 'Everyday cash-back foundation',
      userType: '650–720 credit score',
      goal: 'Cash back',
      feeLevel: 'Low',
      travelScope: 'Not a priority',
      ecosystem: 'Capital One',
      cards: ['SavorOne', 'Quicksilver'],
    ),
    'S04': StrategyPlan(
      code: 'S04',
      title: 'Flexible travel foundation',
      userType: '650–720 credit score',
      goal: 'Travel',
      feeLevel: 'Low',
      travelScope: 'Domestic and international',
      ecosystem: 'Chase',
      cards: ['Freedom Unlimited', 'Freedom Flex', 'Sapphire Preferred'],
    ),
    'S05': StrategyPlan(
      code: 'S05',
      title: 'Premium international travel',
      userType: '720+ credit score',
      goal: 'Travel',
      feeLevel: 'High',
      travelScope: 'International',
      ecosystem: 'Amex',
      cards: ['Venture X', 'Gold', 'Platinum'],
    ),
    'S06': StrategyPlan(
      code: 'S06',
      title: 'Flexible international travel',
      userType: '720+ credit score',
      goal: 'Travel',
      feeLevel: 'Low',
      travelScope: 'International',
      ecosystem: 'Capital One',
      cards: ['SavorOne', 'Venture X', 'Amex Gold'],
    ),
    'S07': StrategyPlan(
      code: 'S07',
      title: 'High-value cash back',
      userType: '720+ credit score',
      goal: 'Cash back',
      feeLevel: 'High',
      travelScope: 'Not a priority',
      ecosystem: 'Chase',
      cards: ['Freedom Unlimited', 'Freedom Flex'],
    ),
    'S08': StrategyPlan(
      code: 'S08',
      title: 'Domestic travel through Citi',
      userType: '720+ credit score',
      goal: 'Travel',
      feeLevel: 'High',
      travelScope: 'Domestic',
      ecosystem: 'Citi',
      cards: ['Double Cash', 'Strata', 'Strata Elite'],
    ),
    'S09': StrategyPlan(
      code: 'S09',
      title: 'Premium Chase travel',
      userType: '750+ credit score',
      goal: 'Travel',
      feeLevel: 'High',
      travelScope: 'Domestic and international',
      ecosystem: 'Chase',
      cards: ['Freedom Unlimited', 'Freedom Flex', 'Sapphire Reserve'],
    ),
  };
}

class AppData {
  const AppData({
    required this.profile,
    required this.wallet,
    required this.catalog,
    required this.roadmap,
    required this.messages,
    required this.quickPrompts,
    required this.pointsValue,
    required this.projectedYearlyValue,
    this.monthlySpend = const {},
    this.strategyPlan,
    this.strategyPreferences,
    this.playbook,
    this.chatMode = 'deterministic',
  });

  factory AppData.fromJson(Map<String, dynamic> json) {
    final metrics = (json['metrics'] as Map?)?.cast<String, dynamic>() ?? {};
    return AppData(
      profile: UserProfile.fromJson(
        (json['profile'] as Map).cast<String, dynamic>(),
      ),
      wallet: _mapList(
        json['wallet'] ?? json['walletCards'],
        CreditCard.fromJson,
      ),
      catalog: _mapList(
        json['catalog'] ?? json['cardSearchCatalog'],
        CreditCard.fromJson,
      ),
      roadmap: _mapList(
        json['roadmap'] ?? json['strategyTimeline'],
        RoadmapStep.fromJson,
      ),
      messages: _mapList(
        json['messages'] ?? json['chatMessages'],
        ChatMessage.fromJson,
      ),
      quickPrompts: _stringList(json['quickPrompts']),
      pointsValue: (json['pointsValue'] ?? metrics['pointsValue'] ?? 0) as int,
      projectedYearlyValue:
          (json['projectedYearlyValue'] ?? metrics['projectedYearlyValue'] ?? 0)
              as int,
      monthlySpend: _intMap(json['monthlySpend'] ?? json['monthly_spend']),
      strategyPlan: StrategyPlan.maybeForCode(
        (json['strategyCode'] ?? json['strategy_code'])?.toString(),
      ),
    );
  }

  factory AppData.fromApiJson(
    Map<String, dynamic> json, {
    required List<dynamic> messages,
    required String email,
  }) {
    final profileJson =
        (json['profile'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final catalog = (json['catalog'] as List? ?? const [])
        .map(
          (item) =>
              CreditCard.fromApiJson((item as Map).cast<String, dynamic>()),
        )
        .toList();
    final wallet = (json['wallet'] as List? ?? const [])
        .where((item) => (item as Map)['status'] == 'active')
        .map((item) {
          final walletJson = (item as Map).cast<String, dynamic>();
          final cardJson = (walletJson['card'] as Map).cast<String, dynamic>();
          return CreditCard.fromApiJson(
            cardJson,
            isActive: true,
            walletCardId: walletJson['id']?.toString(),
          );
        })
        .toList();
    final recommendation = (json['latest_recommendations'] as Map?)
        ?.cast<String, dynamic>();
    final recommendationItems = recommendation?['items'] as List? ?? const [];
    final roadmap = recommendationItems.asMap().entries.map((entry) {
      final item = (entry.value as Map).cast<String, dynamic>();
      return RoadmapStep(
        id: '${recommendation?['run_id'] ?? 'recommendation'}-${entry.key}',
        cardId: item['card_id'].toString(),
        stage: entry.key == 0 ? 'Top match' : 'Option ${entry.key + 1}',
        note:
            _stringList(item['reasons']).firstOrNull ??
            'Calculated by the deterministic recommendation engine.',
        estimatedValue:
            ((item['first_year_estimate_cents'] as num?)?.round() ?? 0) ~/ 100,
      );
    }).toList();
    final topItem = recommendationItems.firstOrNull as Map?;
    final firstYearCents =
        (topItem?['first_year_estimate_cents'] as num?)?.round() ?? 0;
    final walletMetrics =
        (json['wallet_metrics'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final latestQuestionnaire =
        (json['latest_questionnaire'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final strategyCode =
        profileJson['credit_card_strategy']?.toString() ??
        recommendation?['strategy_code']?.toString();
    final playbookJson = (json['playbook'] as Map?)?.cast<String, dynamic>();
    final playbook = playbookJson != null
        ? PlaybookAssignment.fromJson(playbookJson)
        : null;
    final playbookRoadmap = playbook?.steps.asMap().entries.map((entry) {
      final step = entry.value;
      return RoadmapStep(
        id: '${playbook.code}-${entry.key}',
        cardId: step.name,
        stage: switch (step.status) {
          'have' => 'Already in wallet',
          'next' => 'Consider next',
          'unavailable' => 'Not currently recommended',
          _ => 'Later',
        },
        note: step.note.isEmpty ? step.use : step.note,
        estimatedValue: 0,
      );
    }).toList();
    return AppData(
      profile: UserProfile.fromJson({...profileJson, 'email': email}),
      wallet: wallet,
      catalog: catalog,
      roadmap: (playbookRoadmap != null && playbookRoadmap.isNotEmpty)
          ? playbookRoadmap
          : roadmap,
      messages: messages
          .map(
            (item) =>
                ChatMessage.fromJson((item as Map).cast<String, dynamic>()),
          )
          .toList(),
      quickPrompts: _stringList(json['quick_prompts']),
      pointsValue: (walletMetrics['score'] as num?)?.round() ?? 0,
      projectedYearlyValue:
          (walletMetrics['yearly_value'] as num?)?.round() ??
          firstYearCents ~/ 100,
      monthlySpend: _centsToDollars(
        latestQuestionnaire['monthly_category_spend'],
      ),
      strategyPlan: StrategyPlan.maybeForCode(strategyCode),
      strategyPreferences: latestQuestionnaire.isEmpty
          ? null
          : StrategyPreferences.fromApiJson(latestQuestionnaire),
      playbook: playbook,
      chatMode: (json['chat_mode'] ?? 'deterministic').toString(),
    );
  }

  final UserProfile profile;
  final List<CreditCard> wallet;
  final List<CreditCard> catalog;
  final List<RoadmapStep> roadmap;
  final List<ChatMessage> messages;
  final List<String> quickPrompts;
  final int pointsValue;
  final int projectedYearlyValue;
  final Map<String, int> monthlySpend;
  final StrategyPlan? strategyPlan;
  final StrategyPreferences? strategyPreferences;
  final PlaybookAssignment? playbook;
  final String chatMode;

  AppData copyWith({
    List<CreditCard>? wallet,
    List<ChatMessage>? messages,
    UserProfile? profile,
    Map<String, int>? monthlySpend,
    int? projectedYearlyValue,
    int? pointsValue,
    StrategyPlan? strategyPlan,
    StrategyPreferences? strategyPreferences,
    PlaybookAssignment? playbook,
    List<RoadmapStep>? roadmap,
  }) => AppData(
    profile: profile ?? this.profile,
    wallet: wallet ?? this.wallet,
    catalog: catalog,
    roadmap: roadmap ?? this.roadmap,
    messages: messages ?? this.messages,
    quickPrompts: quickPrompts,
    pointsValue: pointsValue ?? this.pointsValue,
    projectedYearlyValue: projectedYearlyValue ?? this.projectedYearlyValue,
    monthlySpend: monthlySpend ?? this.monthlySpend,
    strategyPlan: strategyPlan ?? this.strategyPlan,
    strategyPreferences: strategyPreferences ?? this.strategyPreferences,
    playbook: playbook ?? this.playbook,
    chatMode: chatMode,
  );
}

class QuestionnaireAnswers {
  const QuestionnaireAnswers({
    required this.lifeStage,
    required this.existingCardIds,
    required this.feeTolerance,
    required this.travelScope,
    required this.creditTier,
    required this.monthlySpend,
    required this.rewardsGoal,
  });

  final String lifeStage;
  final List<String> existingCardIds;
  final String feeTolerance;
  final String travelScope;
  final String creditTier;
  final Map<String, int> monthlySpend;
  final String rewardsGoal;

  Map<String, dynamic> toJson() => {
    'life_stage': lifeStage,
    'existing_card_ids': existingCardIds,
    'fee_tolerance': feeTolerance,
    'travel_scope': travelScope,
    'credit_tier': creditTier,
    'monthly_spend': monthlySpend,
    'rewards_goal': rewardsGoal,
  };

  Map<String, dynamic> toRecommendationJson() => {
    'life_stage': lifeStage,
    'monthly_category_spend': monthlySpend.map(
      (category, dollars) => MapEntry(category, dollars * 100),
    ),
    'fee_tolerance_cents': switch (feeTolerance) {
      '0' => 0,
      'low' => 10000,
      'mid' => 30000,
      'high' => 100000,
      _ => 0,
    },
    'travel_scope': travelScope,
    'rewards_goal': rewardsGoal,
    'credit_tier': creditTier,
    'existing_card_ids': existingCardIds,
  };
}

class CustomCardDraft {
  const CustomCardDraft({
    required this.name,
    required this.issuer,
    required this.network,
    required this.annualFeeDollars,
    required this.rates,
    required this.transferablePoints,
    required this.bestUse,
  });

  final String name;
  final String issuer;
  final String network;
  final int annualFeeDollars;
  final Map<String, double> rates;
  final bool transferablePoints;
  final String bestUse;
}

class DemoRecommendation {
  const DemoRecommendation({
    required this.cardId,
    required this.cardName,
    required this.estimatedYearlyValue,
    required this.reasons,
    required this.formula,
  });

  final String cardId;
  final String cardName;
  final int estimatedYearlyValue;
  final List<String> reasons;
  final String formula;
}

List<String> _stringList(dynamic value) =>
    (value as List? ?? const []).map((item) => item.toString()).toList();

String _profileCategories(dynamic value) => value is List
    ? value.map((item) => item.toString()).join(', ')
    : (value ?? '').toString();

List<T> _mapList<T>(dynamic value, T Function(Map<String, dynamic>) mapper) =>
    (value as List? ?? const [])
        .map((item) => mapper((item as Map).cast<String, dynamic>()))
        .toList();

String _nonEmpty(dynamic value, String fallback) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

Map<String, int> _centsToDollars(dynamic value) {
  if (value is! Map) return const {};
  return value.map(
    (key, amount) => MapEntry(key.toString(), ((amount as num) / 100).round()),
  );
}

Map<String, int> _intMap(dynamic value) {
  if (value is! Map) return const {};
  return value.map(
    (key, amount) => MapEntry(key.toString(), (amount as num).round()),
  );
}
