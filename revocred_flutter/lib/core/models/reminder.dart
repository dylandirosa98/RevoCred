class ReminderItem {
  const ReminderItem({
    required this.key,
    required this.kind,
    required this.priority,
    required this.status,
    required this.title,
    required this.detail,
    required this.actionKind,
    required this.actionLabel,
    this.cardId = '',
    this.walletCardId = '',
    this.cardName = '',
    this.amountCents = 0,
    this.periodLabel = '',
    this.dueAt,
    this.snoozedUntil,
    this.route = '',
    this.sourceUrl = '',
    this.sourceVerifiedOn = '',
    this.conditions = '',
    this.canComplete = false,
  });

  factory ReminderItem.fromJson(Map<String, dynamic> json) => ReminderItem(
    key: (json['key'] ?? '').toString(),
    kind: (json['kind'] ?? '').toString(),
    priority: (json['priority'] ?? 'low').toString(),
    status: (json['status'] ?? 'active').toString(),
    title: (json['title'] ?? '').toString(),
    detail: (json['detail'] ?? '').toString(),
    cardId: (json['card_id'] ?? '').toString(),
    walletCardId: (json['wallet_card_id'] ?? '').toString(),
    cardName: (json['card_name'] ?? '').toString(),
    amountCents: (json['amount_cents'] as num?)?.round() ?? 0,
    periodLabel: (json['period_label'] ?? '').toString(),
    dueAt: json['due_at'] is String ? DateTime.tryParse(json['due_at']) : null,
    snoozedUntil: json['snoozed_until'] is String
        ? DateTime.tryParse(json['snoozed_until'])
        : null,
    actionKind: (json['action_kind'] ?? '').toString(),
    actionLabel: (json['action_label'] ?? '').toString(),
    route: (json['route'] ?? '').toString(),
    sourceUrl: (json['source_url'] ?? '').toString(),
    sourceVerifiedOn: (json['source_verified_on'] ?? '').toString(),
    conditions: (json['conditions'] ?? '').toString(),
    canComplete: json['can_complete'] == true,
  );

  final String key;
  final String kind;
  final String priority;
  final String status;
  final String title;
  final String detail;
  final String cardId;
  final String walletCardId;
  final String cardName;
  final int amountCents;
  final String periodLabel;
  final DateTime? dueAt;
  final DateTime? snoozedUntil;
  final String actionKind;
  final String actionLabel;
  final String route;
  final String sourceUrl;
  final String sourceVerifiedOn;
  final String conditions;
  final bool canComplete;

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get isDismissed => status == 'dismissed';
  bool get isSnoozed => status == 'snoozed';
  bool get isHighPriority => priority == 'high';

  String get formattedAmount {
    if (amountCents <= 0) return '';
    if (amountCents % 100 == 0) {
      return '\$${amountCents ~/ 100}';
    }
    return '\$${(amountCents / 100).toStringAsFixed(2)}';
  }

  ReminderItem copyWith({
    String? status,
    DateTime? snoozedUntil,
    bool clearSnoozedUntil = false,
  }) => ReminderItem(
    key: key,
    kind: kind,
    priority: priority,
    status: status ?? this.status,
    title: title,
    detail: detail,
    cardId: cardId,
    walletCardId: walletCardId,
    cardName: cardName,
    amountCents: amountCents,
    periodLabel: periodLabel,
    dueAt: dueAt,
    snoozedUntil: clearSnoozedUntil
        ? null
        : (snoozedUntil ?? this.snoozedUntil),
    actionKind: actionKind,
    actionLabel: actionLabel,
    route: route,
    sourceUrl: sourceUrl,
    sourceVerifiedOn: sourceVerifiedOn,
    conditions: conditions,
    canComplete: canComplete,
  );
}

class ReminderFeed {
  const ReminderFeed({
    required this.generatedAt,
    required this.activeCount,
    required this.reminders,
  });

  factory ReminderFeed.empty() => ReminderFeed(
    generatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    activeCount: 0,
    reminders: const [],
  );

  factory ReminderFeed.fromJson(Map<String, dynamic> json) {
    final items = (json['reminders'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => ReminderItem.fromJson(item.cast<String, dynamic>()))
        .toList();
    final active =
        (json['active_count'] as num?)?.round() ??
        items.where((item) => item.isActive).length;
    return ReminderFeed(
      generatedAt: json['generated_at'] is String
          ? (DateTime.tryParse(json['generated_at']) ?? DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      activeCount: active,
      reminders: items,
    );
  }

  final DateTime generatedAt;
  final int activeCount;
  final List<ReminderItem> reminders;

  List<ReminderItem> get activeReminders =>
      reminders.where((item) => item.isActive).toList();

  List<ReminderItem> get handledReminders =>
      reminders.where((item) => !item.isActive).toList();
}
