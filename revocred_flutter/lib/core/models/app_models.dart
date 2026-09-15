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
    return AppData(
      profile: UserProfile.fromJson({...profileJson, 'email': email}),
      wallet: wallet,
      catalog: catalog,
      roadmap: roadmap,
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

  AppData copyWith({
    List<CreditCard>? wallet,
    List<ChatMessage>? messages,
    UserProfile? profile,
    Map<String, int>? monthlySpend,
    int? projectedYearlyValue,
    int? pointsValue,
  }) => AppData(
    profile: profile ?? this.profile,
    wallet: wallet ?? this.wallet,
    catalog: catalog,
    roadmap: roadmap,
    messages: messages ?? this.messages,
    quickPrompts: quickPrompts,
    pointsValue: pointsValue ?? this.pointsValue,
    projectedYearlyValue: projectedYearlyValue ?? this.projectedYearlyValue,
    monthlySpend: monthlySpend ?? this.monthlySpend,
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
