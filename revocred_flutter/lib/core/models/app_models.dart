import '../logic/playbook.dart';
import 'ongoing_value.dart';
export 'ongoing_value.dart';
import 'purchase_guide.dart';
export 'purchase_guide.dart';

enum MessageRole { user, assistant }

/// Supplemental, attributed public product data. Never scoring inputs.
class CommunityCardData {
  const CommunityCardData({
    required this.id,
    required this.attribution,
    required this.sourceUrl,
    required this.licenseUrl,
    required this.issuerUrl,
    required this.lastVerified,
    required this.retrievedAt,
    required this.currencyLabel,
    required this.rewardRates,
    required this.benefits,
    required this.warning,
    this.welcomeOfferDescription = '',
    this.redemptionNotes = '',
    this.travelPerks = const [],
  });
  factory CommunityCardData.fromJson(Map<String, dynamic> json) =>
      CommunityCardData(
        id: (json['id'] ?? '').toString(),
        attribution: (json['attribution'] ?? '').toString(),
        sourceUrl: (json['source_url'] ?? '').toString(),
        licenseUrl: (json['license_url'] ?? '').toString(),
        issuerUrl: (json['issuer_url'] ?? '').toString(),
        lastVerified: (json['last_verified'] ?? '').toString(),
        retrievedAt: (json['retrieved_at'] ?? '').toString(),
        currencyLabel: (json['currency_label'] ?? '').toString(),
        rewardRates: _stringList(json['reward_rates']),
        benefits: _stringList(json['benefits']),
        travelPerks: _travelPerkLines(json['travel_perks']),
        warning:
            (json['warning'] ?? 'Community-maintained; verify issuer terms.')
                .toString(),
        welcomeOfferDescription: json['welcome_offer'] is Map
            ? ((json['welcome_offer'] as Map)['description'] ?? '').toString()
            : '',
        redemptionNotes: json['rewards'] is Map
            ? ((json['rewards'] as Map)['redemption_notes'] ?? '').toString()
            : '',
      );
  final String id, attribution, sourceUrl, licenseUrl, issuerUrl;
  final String lastVerified, retrievedAt, currencyLabel, warning;
  final String welcomeOfferDescription, redemptionNotes;
  final List<String> rewardRates, benefits;
  final List<String> travelPerks;
}

// Display-only recursive formatting preserves unfamiliar structured fields.
// Missing/null fields are unknown, never inferred as absent or unlimited.
List<String> _travelPerkLines(dynamic value, [String label = '']) {
  String readable(String key) {
    final words = key.replaceAll('_', ' ');
    return words.isEmpty
        ? words
        : '${words[0].toUpperCase()}${words.substring(1)}';
  }

  if (value == null) return [];
  if (value is Map) {
    return [
      for (final entry in value.entries)
        ..._travelPerkLines(
          entry.value,
          label.isEmpty
              ? readable(entry.key.toString())
              : '$label · ${readable(entry.key.toString())}',
        ),
    ];
  }
  if (value is List) {
    return [for (final item in value) ..._travelPerkLines(item, label)];
  }
  if (value is! String && value is! num && value is! bool) return [];
  final text = value.toString().trim();
  if (text.isEmpty) return [];
  final display = label.endsWith('Period') ? text.replaceAll('_', ' ') : text;
  return [label.isEmpty ? display : '$label: $display'];
}

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
    this.termsUnknown = false,
    this.communityData,
    this.minimumCreditTier = '',
    this.modeledRates = const {},
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
    termsUnknown: json['termsUnknown'] == true || json['terms_unknown'] == true,
    communityData: json['community_data'] is Map
        ? CommunityCardData.fromJson(
            (json['community_data'] as Map).cast<String, dynamic>(),
          )
        : null,
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
      modeledRates:
          rewardRates?.map(
            (key, value) => MapEntry(key, (value as num).toDouble()),
          ) ??
          const {},
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
      termsUnknown: json['terms_unknown'] == true,
      sourceDisclaimer: () {
        final text = [json['source_disclaimer'], json['summary']]
            .where((item) => item != null && item.toString().trim().isNotEmpty)
            .join(' ')
            .trim();
        return text.isEmpty
            ? 'Verify current terms with the issuer. Educational use only.'
            : text;
      }(),
      communityData: json['community_data'] is Map
          ? CommunityCardData.fromJson(
              (json['community_data'] as Map).cast<String, dynamic>(),
            )
          : null,
      minimumCreditTier: (json['minimum_credit_tier'] ?? '').toString(),
    );
  }

  final String id;
  final String issuer;
  final String brand;
  final String name;
  final String annualFee;
  final Map<String, double> modeledRates;
  final String bestUse;
  final String multiplier;
  final List<String> benefits;
  final List<String> pointMultipliers;
  final bool transferablePoints;
  final bool isActive;
  final String feeTier;
  final String? walletCardId;
  final String sourceDisclaimer;
  final CommunityCardData? communityData;

  /// Minimum qualifying credit tier from the versioned catalog
  /// (building, fair, good, excellent). Empty when unknown.
  final String minimumCreditTier;
  // True when the cardholder chose not to supply terms. Such a card is listed
  // as owned but is left out of the score, because no known rate is not a
  // low rate.
  final bool termsUnknown;

  CreditCard copyWith({
    bool? isActive,
    String? walletCardId,
    bool? termsUnknown,
    String? minimumCreditTier,
  }) => CreditCard(
    id: id,
    issuer: issuer,
    brand: brand,
    name: name,
    annualFee: annualFee,
    bestUse: bestUse,
    multiplier: multiplier,
    benefits: benefits,
    pointMultipliers: pointMultipliers,
    modeledRates: modeledRates,
    transferablePoints: transferablePoints,
    isActive: isActive ?? this.isActive,
    feeTier: feeTier,
    walletCardId: walletCardId ?? this.walletCardId,
    sourceDisclaimer: sourceDisclaimer,
    termsUnknown: termsUnknown ?? this.termsUnknown,
    communityData: communityData,
    minimumCreditTier: minimumCreditTier ?? this.minimumCreditTier,
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

/// A structured REVO block. Only the shapes the API emits are modelled here;
/// an unknown type falls back to plain text so a newer server can never break
/// an older client.
class ChatBlock {
  const ChatBlock({
    required this.type,
    this.text = '',
    this.items = const [],
    this.chart,
  });

  factory ChatBlock.fromJson(Map<String, dynamic> json) => ChatBlock(
    type: (json['type'] ?? '').toString(),
    text: (json['text'] ?? '').toString(),
    items: ((json['items'] as List<dynamic>?) ?? const [])
        .map((item) => item.toString())
        .toList(growable: false),
    chart: json['chart'] is Map<String, dynamic>
        ? ChatChart.fromJson(json['chart'] as Map<String, dynamic>)
        : null,
  );

  final String type;
  final String text;
  final List<String> items;
  final ChatChart? chart;
}

class ChatChart {
  const ChatChart({
    required this.title,
    required this.unit,
    this.note = '',
    this.bars = const [],
  });

  factory ChatChart.fromJson(Map<String, dynamic> json) => ChatChart(
    title: (json['title'] ?? '').toString(),
    unit: (json['unit'] ?? 'usd').toString(),
    note: (json['note'] ?? '').toString(),
    bars: ((json['bars'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (bar) => ChatBar(
            label: (bar['label'] ?? '').toString(),
            value: (bar['value'] as num?)?.toDouble() ?? 0,
            valueLabel: (bar['value_label'] ?? '').toString(),
            caption: (bar['caption'] ?? '').toString(),
          ),
        )
        .toList(growable: false),
  );

  final String title;
  final String unit;
  final String note;
  final List<ChatBar> bars;
  bool get isPercent => unit == 'percent';
}

class ChatBar {
  const ChatBar({
    required this.label,
    required this.value,
    this.valueLabel = '',
    this.caption = '',
  });

  final String label;
  final double value;
  final String valueLabel;
  final String caption;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.blocks = const [],
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'].toString(),
    role: json['role'] == 'user' ? MessageRole.user : MessageRole.assistant,
    content: json['content'] as String,
    blocks: ((json['blocks'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ChatBlock.fromJson)
        .toList(growable: false),
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

  /// Empty for messages saved before structured replies existed.
  final List<ChatBlock> blocks;
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
  String get firstName => name.trim().split(RegExp(r'\s+')).first;
  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    // Runes keep the first letter correct for names outside the basic plane
    // without pulling in another dependency.
    String first(String word) =>
        String.fromCharCodes([word.runes.first]).toUpperCase();
    if (parts.length == 1) return first(parts.first);
    return first(parts.first) + first(parts.last);
  }

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
    this.recommendedCardId,
    this.isPersonalPreview = false,
    this.questionnaireAnswers,
    this.ongoingValue,
    this.nextCardReasons = const [],
    this.purchaseGuide,
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
      purchaseGuide: json['purchase_guide'] is Map
          ? PurchaseGuide.fromJson(
              (json['purchase_guide'] as Map).cast<String, dynamic>(),
            )
          : null,
    );
  }

  factory AppData.fromApiJson(
    Map<String, dynamic> json, {
    required List<dynamic> messages,
    required String email,
    String displayNameFallback = '',
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
    final playbookRoadmap = playbook?.steps
        .where((step) => step.status == 'next' || step.status == 'later')
        .toList()
        .asMap()
        .entries
        .map((entry) {
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
        })
        .toList();
    final savedDisplayName =
        profileJson['display_name']?.toString().trim() ?? '';
    return AppData(
      profile: UserProfile.fromJson({
        ...profileJson,
        if (savedDisplayName.isEmpty && displayNameFallback.trim().isNotEmpty)
          'display_name': displayNameFallback.trim(),
        'email': email,
      }),
      wallet: wallet,
      catalog: catalog,
      roadmap: playbookRoadmap ?? roadmap,
      messages: messages
          .map(
            (item) =>
                ChatMessage.fromJson((item as Map).cast<String, dynamic>()),
          )
          .toList(),
      quickPrompts: _stringList(json['quick_prompts']),
      pointsValue: (walletMetrics['score'] as num?)?.round() ?? 0,
      ongoingValue: walletMetrics['ongoing_value'] is Map
          ? OngoingValue.fromJson(
              (walletMetrics['ongoing_value'] as Map).cast<String, dynamic>(),
            )
          : null,
      projectedYearlyValue:
          (walletMetrics['yearly_value'] as num?)?.round() ?? 0,
      monthlySpend: _centsToDollars(
        latestQuestionnaire['monthly_category_spend'],
      ),
      strategyPlan: StrategyPlan.maybeForCode(strategyCode),
      strategyPreferences: latestQuestionnaire.isEmpty
          ? null
          : StrategyPreferences.fromApiJson(latestQuestionnaire),
      playbook: playbook,
      chatMode: (json['chat_mode'] ?? 'deterministic').toString(),
      recommendedCardId: topItem?['card_id']?.toString(),
      nextCardReasons: _stringList(topItem?['reasons']),
      purchaseGuide: json['purchase_guide'] is Map
          ? PurchaseGuide.fromJson(
              (json['purchase_guide'] as Map).cast<String, dynamic>(),
            )
          : null,
      questionnaireAnswers: latestQuestionnaire.isEmpty
          ? null
          : QuestionnaireAnswers.fromRecommendationJson(latestQuestionnaire),
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
  final OngoingValue? ongoingValue;
  final Map<String, int> monthlySpend;
  final StrategyPlan? strategyPlan;
  final StrategyPreferences? strategyPreferences;
  final PlaybookAssignment? playbook;
  final String chatMode;
  // Server-ranked identity, separate from display names and affiliate metadata.
  final String? recommendedCardId;
  final bool isPersonalPreview;
  final QuestionnaireAnswers? questionnaireAnswers;
  final List<String> nextCardReasons;
  final PurchaseGuide? purchaseGuide;

  AppData copyWith({
    List<CreditCard>? catalog,
    bool? isPersonalPreview,
    QuestionnaireAnswers? questionnaireAnswers,
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
    PurchaseGuide? purchaseGuide,
  }) => AppData(
    profile: profile ?? this.profile,
    wallet: wallet ?? this.wallet,
    catalog: catalog ?? this.catalog,
    roadmap: roadmap ?? this.roadmap,
    messages: messages ?? this.messages,
    quickPrompts: quickPrompts,
    pointsValue: pointsValue ?? this.pointsValue,
    projectedYearlyValue: projectedYearlyValue ?? this.projectedYearlyValue,
    ongoingValue: ongoingValue,
    monthlySpend: monthlySpend ?? this.monthlySpend,
    strategyPlan: strategyPlan ?? this.strategyPlan,
    strategyPreferences: strategyPreferences ?? this.strategyPreferences,
    playbook: playbook ?? this.playbook,
    chatMode: chatMode,
    recommendedCardId: recommendedCardId,
    isPersonalPreview: isPersonalPreview ?? this.isPersonalPreview,
    questionnaireAnswers: questionnaireAnswers ?? this.questionnaireAnswers,
    nextCardReasons: nextCardReasons,
    purchaseGuide: purchaseGuide ?? this.purchaseGuide,
  );
}

/// A card chosen from the search-only index during onboarding.
class OnboardingCardDraft {
  const OnboardingCardDraft({
    required this.referenceId,
    required this.cardName,
    this.includeTerms = false,
    this.annualFeeCents = 0,
    this.rewardRates = const {},
    this.transferable = false,
    this.bestUse = '',
    this.issuer = '',
  });

  factory OnboardingCardDraft.fromReference(
    ReferenceCard card, {
    bool includeTerms = false,
    int? annualFeeCents,
    Map<String, double>? rewardRates,
  }) => OnboardingCardDraft(
    referenceId: card.id,
    cardName: card.label,
    includeTerms: includeTerms,
    annualFeeCents: annualFeeCents ?? card.annualFeeCents,
    rewardRates: rewardRates ?? card.rewardRates,
    bestUse: card.rewardsType,
    issuer: card.issuer,
  );

  final String referenceId;
  final String cardName;
  final bool includeTerms;
  final int annualFeeCents;
  final Map<String, double> rewardRates;
  final bool transferable;
  final String bestUse;

  /// Display only, for the issuer mark; the API resolves the card by id.
  final String issuer;

  Map<String, dynamic> toJson() => {
    'reference_id': referenceId,
    'include_terms': includeTerms,
    'annual_fee_cents': annualFeeCents,
    'reward_rates': rewardRates,
    'transferable_points': transferable,
    'best_use': bestUse,
    'minimum_credit_tier': 'good',
  };
}

/// One search result from the card index. Identity is always present; terms are
/// only present when a source published them on the captured date.
class ReferenceCard {
  const ReferenceCard({
    required this.id,
    required this.issuer,
    required this.name,
    required this.network,
    required this.rewardsType,
    required this.annualFeeCents,
    required this.rewardRates,
    required this.termsStatus,
    required this.sourceUrl,
    required this.sourceCapturedOn,
    this.catalogCardId,
  });

  factory ReferenceCard.fromJson(Map<String, dynamic> json) => ReferenceCard(
    id: json['id'] as String,
    issuer: (json['issuer'] ?? '') as String,
    name: (json['name'] ?? '') as String,
    network: (json['network'] ?? 'Unknown') as String,
    rewardsType: (json['rewards_type'] ?? 'unknown') as String,
    annualFeeCents: (json['annual_fee_cents'] as num?)?.round() ?? 0,
    rewardRates: ((json['reward_rates'] as Map?) ?? const {}).map(
      (key, value) => MapEntry('$key', (value as num).toDouble()),
    ),
    termsStatus: (json['terms_status'] ?? 'partial') as String,
    sourceUrl: (json['source_url'] ?? '') as String,
    sourceCapturedOn: (json['source_captured_on'] ?? '') as String,
    catalogCardId: json['catalog_card_id'] as String?,
  );

  final String id;
  final String issuer;
  final String name;
  final String network;
  final String rewardsType;
  final int annualFeeCents;
  final Map<String, double> rewardRates;
  final String termsStatus;
  final String sourceUrl;
  final String sourceCapturedOn;
  final String? catalogCardId;

  bool get hasTerms => termsStatus == 'verified' && rewardRates.isNotEmpty;
  // "Discover it Miles" already names its issuer; prefixing it again would
  // read "Discover Discover it Miles".
  String get label => name.toLowerCase().startsWith(issuer.toLowerCase())
      ? name
      : '$issuer $name';
}

class QuestionnaireAnswers {
  /// [cardLabels] restores display names for cards added from search, keyed by
  /// reference id. The API payload carries only ids, so a device-local draft
  /// keeps the names alongside it.
  factory QuestionnaireAnswers.fromRecommendationJson(
    Map<String, dynamic> json, {
    Map<String, dynamic> cardLabels = const {},
  }) => QuestionnaireAnswers(
    lifeStage: (json['life_stage'] ?? '').toString(),
    existingCardIds: _stringList(json['existing_card_ids']),
    displayName: (json['display_name'] ?? '').toString(),
    addedCards: ((json['added_cards'] as List?) ?? const [])
        .map((item) => (item as Map).cast<String, dynamic>())
        .map(
          (item) => OnboardingCardDraft(
            referenceId: item['reference_id'].toString(),
            cardName:
                (cardLabels['${item['reference_id']}'] as Map?)?['name']
                    ?.toString() ??
                'Card from search',
            issuer:
                (cardLabels['${item['reference_id']}'] as Map?)?['issuer']
                    ?.toString() ??
                '',
            includeTerms: item['include_terms'] == true,
            annualFeeCents: (item['annual_fee_cents'] as num?)?.round() ?? 0,
            rewardRates: ((item['reward_rates'] as Map?) ?? const {}).map(
              (key, value) => MapEntry('$key', (value as num).toDouble()),
            ),
          ),
        )
        .toList(),
    feeTolerance: switch ((json['fee_tolerance_cents'] as num?)?.toInt() ?? 0) {
      0 => 'none',
      <= 10000 => 'low',
      <= 30000 => 'mid',
      _ => 'high',
    },
    idealCardCount: (json['ideal_card_count'] ?? '').toString(),
    travelScope: (json['travel_scope'] ?? '').toString(),
    creditTier: (json['credit_tier'] ?? '').toString(),
    rewardsGoal: (json['rewards_goal'] ?? '').toString(),
    monthlySpend: _centsToDollars(json['monthly_category_spend']),
  );
  const QuestionnaireAnswers({
    required this.lifeStage,
    required this.existingCardIds,
    required this.feeTolerance,
    required this.travelScope,
    required this.creditTier,
    required this.monthlySpend,
    required this.rewardsGoal,
    this.addedCards = const [],
    this.displayName = '',
    this.idealCardCount = '',
  });

  final String lifeStage;
  final List<String> existingCardIds;
  final String feeTolerance;
  final String travelScope;
  final String creditTier;
  final Map<String, int> monthlySpend;
  final String rewardsGoal;
  final List<OnboardingCardDraft> addedCards;
  final String displayName;
  final String idealCardCount;

  Map<String, dynamic> toJson() => {
    'life_stage': lifeStage,
    'existing_card_ids': existingCardIds,
    'fee_tolerance': feeTolerance,
    'ideal_card_count': idealCardCount,
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
    if (idealCardCount.isNotEmpty) 'ideal_card_count': idealCardCount,
    'travel_scope': travelScope,
    'rewards_goal': rewardsGoal,
    'credit_tier': creditTier,
    'existing_card_ids': existingCardIds,
    if (addedCards.isNotEmpty)
      'added_cards': addedCards.map((card) => card.toJson()).toList(),
    if (displayName.trim().isNotEmpty) 'display_name': displayName.trim(),
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
    this.termsUnknown = false,
  });

  final String name;
  final String issuer;
  final String network;
  final int annualFeeDollars;
  final Map<String, double> rates;
  final bool transferablePoints;
  final String bestUse;
  final bool termsUnknown;
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
