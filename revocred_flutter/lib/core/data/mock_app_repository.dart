import '../models/ai_plan.dart';
import '../logic/playbook.dart';
import '../logic/demo_purchase_guide.dart';
import '../models/app_models.dart';
import '../models/chat_disclosure.dart';
import '../models/explore_rewards.dart';
import 'app_repository.dart';
import 'demo_seed.dart';
import 'explore_rewards_asset.dart';

class MockAppRepository implements AppRepository, AIPlanSource {
  MockAppRepository({AppData? initialData})
    : _data = initialData ?? createDemoAppData();

  AppData _data;
  bool _emailNotificationsOptIn = false;
  final Map<String, ({String status, DateTime? snoozedUntil})> _reminderStates =
      {};

  @override
  String? get accountEmail => null;
  @override
  bool get emailNotificationsOptIn => _emailNotificationsOptIn;
  @override
  Future<bool> updateEmailNotificationsOptIn(bool enabled) async {
    _emailNotificationsOptIn = enabled;
    return enabled;
  }

  @override
  Future<List<CreditCard>> loadCatalog() async => _data.catalog;
  @override
  Future<AppData> previewQuestionnaire(QuestionnaireAnswers answers) async =>
      _data;

  @override
  Future<List<ReferenceCard>> searchCardIndex(String query) async {
    final needle = query.trim().toLowerCase();
    return _data.catalog
        .where(
          (card) =>
              needle.isEmpty ||
              '${card.issuer} ${card.name}'.toLowerCase().contains(needle),
        )
        .take(20)
        .map(
          (card) => ReferenceCard(
            id: card.id,
            issuer: card.issuer,
            name: card.name,
            network: card.brand,
            rewardsType: 'cash_back',
            annualFeeCents: 0,
            rewardRates: const {'other': 1.5},
            termsStatus: 'verified',
            sourceUrl: '',
            sourceCapturedOn: '2026-01-01',
            catalogCardId: card.id,
          ),
        )
        .toList();
  }

  @override
  Stream<AccountSession> get sessionChanges => const Stream.empty();
  @override
  bool get isPasswordRecovery => false;
  @override
  Future<void> requestPasswordReset(String email) async =>
      throw StateError('Email recovery is available in real mode.');
  @override
  Future<void> resendVerification(String email) => requestPasswordReset(email);
  @override
  Future<void> updatePassword(String password) async =>
      throw StateError('Account changes are available in real mode.');
  @override
  Future<void> updateEmail(String email) => updatePassword(email);
  @override
  Future<String> exportAccount() async =>
      '{"mode":"demo","personal_data":false}';
  @override
  Future<void> deleteAccount(String password) => signOut();

  /// Demo data never sells a subscription.
  @override
  Future<AIPlan> loadAIPlan({bool refresh = false}) async =>
      const AIPlan(subscriber: false, used: 0, limit: 3);

  @override
  bool get isAuthenticated => true;

  @override
  Future<AuthResult> signIn(String email, String password) async =>
      const AuthResult(
        success: true,
        message: 'Demo session is already active.',
      );

  @override
  Map<String, dynamic>? get pendingPlan => null;

  @override
  Future<void> clearPendingPlan() async {}

  @override
  Future<AuthResult> signUp(
    String email,
    String password, {
    String displayName = '',
    bool notificationsOptIn = false,
    Map<String, dynamic>? pendingPlan,
  }) async {
    _emailNotificationsOptIn = notificationsOptIn;
    if (displayName.trim().isNotEmpty) {
      _data = _data.copyWith(
        profile: UserProfile(
          name: displayName.trim(),
          strategy: _data.profile.strategy,
          goal: _data.profile.goal,
          topSpendCategories: _data.profile.topSpendCategories,
          nextTarget: _data.profile.nextTarget,
          email: _data.profile.email,
        ),
      );
    }
    return signIn(email, password);
  }

  @override
  Future<void> signOut() async {
    _data = createDemoAppData();
    _emailNotificationsOptIn = false;
    _reminderStates.clear();
  }

  @override
  Future<AppData> loadAppData() async => _data.copyWith(
    purchaseGuide: _data.purchaseGuide ?? demoPurchaseGuide(_data.wallet),
    reminders: _buildDemoReminders(),
  );

  @override
  Future<PurchaseGuide> loadPurchaseGuide({
    String travelMode = 'general',
    bool capsAvailable = true,
  }) async =>
      _data.purchaseGuide ??
      demoPurchaseGuide(
        _data.wallet,
        travelMode: travelMode,
        capsAvailable: capsAvailable,
      );

  @override
  Future<void> addCard(String cardId) async {
    if (_data.wallet.any((card) => card.id == cardId)) return;
    final card = _data.catalog.where((item) => item.id == cardId).firstOrNull;
    if (card != null) {
      _updateWallet([..._data.wallet, card.copyWith(isActive: true)]);
    }
  }

  @override
  Future<void> addCustomCard(CustomCardDraft card) async {
    final id = 'custom-${card.name.toLowerCase().replaceAll(' ', '-')}';
    if (_data.wallet.any((item) => item.id == id)) return;
    final multipliers = card.termsUnknown
        ? <String>[]
        : card.rates.entries
              .where((entry) => entry.value > 0)
              .map((entry) => '${entry.value}x ${entry.key}')
              .toList();
    final created = CreditCard(
      id: id,
      issuer: card.issuer,
      brand: card.network,
      name: card.name,
      annualFee: '\$${card.annualFeeDollars}',
      bestUse: card.bestUse.isEmpty ? 'User-supplied card' : card.bestUse,
      multiplier: card.termsUnknown ? '—' : '${card.rates['other'] ?? 1}x',
      benefits: [
        card.termsUnknown
            ? 'Terms not supplied; excluded from scoring'
            : 'User-supplied terms',
      ],
      pointMultipliers: multipliers,
      transferablePoints: card.transferablePoints,
      isActive: true,
      walletCardId: id,
      termsUnknown: card.termsUnknown,
    );
    _updateWallet([..._data.wallet, created]);
  }

  void _updateWallet(List<CreditCard> wallet) {
    _data = _data.copyWith(
      wallet: wallet,
      playbook: buildPlaybook(
        code: _data.playbook?.code ?? _data.strategyPlan?.code,
        walletNames: wallet.map((item) => item.name).toList(),
      ),
    );
  }

  @override
  Future<void> removeCard(String walletCardId) async {
    _updateWallet(
      _data.wallet
          .where((card) => (card.walletCardId ?? card.id) != walletCardId)
          .toList(),
    );
  }

  @override
  Future<void> updateWalletRenewalMonth(
    String walletCardId,
    int? renewalMonth,
  ) async {
    _data = _data.copyWith(
      wallet: [
        for (final card in _data.wallet)
          if ((card.walletCardId ?? card.id) == walletCardId)
            card.copyWith(
              renewalMonth: renewalMonth,
              clearRenewalMonth: renewalMonth == null,
            )
          else
            card,
      ],
    );
  }

  @override
  Future<ReminderFeed> loadReminders() async => _buildDemoReminders();

  @override
  Future<ReminderFeed> updateReminderState(
    String key, {
    required String status,
    int? snoozeDays,
  }) async {
    if (status == 'active') {
      _reminderStates.remove(key);
    } else {
      final until = status == 'snoozed'
          ? DateTime.now().toUtc().add(Duration(days: snoozeDays ?? 7))
          : null;
      _reminderStates[key] = (status: status, snoozedUntil: until);
    }
    return _buildDemoReminders();
  }

  ReminderFeed _buildDemoReminders() {
    final now = DateTime.now().toUtc();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final items = <ReminderItem>[];
    for (final card in _data.wallet) {
      final wid = card.walletCardId ?? card.id;
      final lower = card.name.toLowerCase();
      if (lower.contains('gold')) {
        items.add(
          ReminderItem(
            key: 'credit.${card.id}.dining.$monthKey',
            kind: 'credit',
            priority: 'medium',
            status: 'active',
            title: r'Use $10 Dining credit',
            detail:
                'Monthly credit · Enrollment required; participating dining partners only.',
            cardId: card.id,
            walletCardId: wid,
            cardName: card.name,
            amountCents: 1000,
            periodLabel: monthKey,
            actionKind: 'mark_used',
            actionLabel: 'Mark used',
            route: '/cards',
            canComplete: true,
          ),
        );
      }
      final feeDollars =
          int.tryParse(card.annualFee.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (feeDollars > 0 && card.renewalMonth == null) {
        items.add(
          ReminderItem(
            key: 'renewal-month.$wid',
            kind: 'annual_fee',
            priority: 'low',
            status: 'active',
            title: 'Set renewal month for ${card.name}',
            detail:
                '\$$feeDollars/yr annual fee. Add your renewal month so RevoCred reminds you 30 days before renewal.',
            cardId: card.id,
            walletCardId: wid,
            cardName: card.name,
            amountCents: feeDollars * 100,
            actionKind: 'set_renewal_month',
            actionLabel: 'Set month',
            route: '/cards',
            canComplete: false,
          ),
        );
      }
      if (card.termsUnknown) {
        items.add(
          ReminderItem(
            key: 'wallet-terms.$wid',
            kind: 'wallet',
            priority: 'low',
            status: 'active',
            title: 'Add terms for ${card.name}',
            detail:
                'This card is excluded from your wallet score and purchase guide because its rates are missing.',
            cardId: card.id,
            walletCardId: wid,
            cardName: card.name,
            actionKind: 'review_card',
            actionLabel: 'Open wallet',
            route: '/cards',
            canComplete: false,
          ),
        );
      }
    }
    final nextCard = _data.playbook?.nextCard ?? '';
    if (nextCard.isNotEmpty) {
      final code = _data.playbook?.code ?? 'plan';
      items.add(
        ReminderItem(
          key:
              'strategy-next.${code.toLowerCase()}.${nextCard.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}',
          kind: 'strategy',
          priority: 'low',
          status: 'active',
          title: 'Next strategy step: $nextCard',
          detail:
              'Your $code roadmap highlights $nextCard when you are ready for your next card.',
          cardName: nextCard,
          actionKind: 'open_strategy',
          actionLabel: 'View strategy',
          route: '/strategy',
          canComplete: false,
        ),
      );
    }
    final resolved = [
      for (final item in items)
        () {
          final saved = _reminderStates[item.key];
          if (saved == null) return item;
          if (saved.status == 'snoozed' &&
              (saved.snoozedUntil == null ||
                  !saved.snoozedUntil!.isAfter(now))) {
            return item;
          }
          return item.copyWith(
            status: saved.status,
            snoozedUntil: saved.snoozedUntil,
          );
        }(),
    ];
    return ReminderFeed(
      generatedAt: now,
      activeCount: resolved.where((item) => item.isActive).length,
      reminders: resolved,
    );
  }

  @override
  Future<ChatDisclosure> loadChatDisclosure() async =>
      const ChatDisclosure.basic();

  @override
  Future<ExploreRewards> loadExploreRewards() => loadBundledExploreRewards();

  @override
  Future<ChatMessage> sendMessage(
    String prompt, {
    String? aiConsentVersion,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final lower = prompt.toLowerCase();
    final response = lower.contains('grocer')
        ? 'For this demo wallet, Amex Gold earns 4x at U.S. supermarkets. Check merchant coding and compare the annual fee against credits you naturally use.'
        : lower.contains('next') || lower.contains('apply')
        ? 'The local roadmap places Sapphire Preferred first. Space applications, verify current terms, and only apply when the welcome-bonus spend fits your normal budget.'
        : lower.contains('travel')
        ? 'Start with transferable points, use portal credits only when pricing is competitive, and never carry interest for rewards.'
        : 'Based on the demo wallet, compare category earn, annual fee, and benefits you will actually use. This is educational guidance, not a guarantee of approval or value.';
    final message = ChatMessage(
      id: 'assistant-${DateTime.now().microsecondsSinceEpoch}',
      role: MessageRole.assistant,
      content: response,
      createdAt: DateTime.now(),
    );
    _data = _data.copyWith(messages: [..._data.messages, message]);
    return message;
  }

  String _chatConsentVersion = '';

  /// Demo progress, then the reply from [sendMessage] so test doubles that
  /// override it keep working.
  @override
  Stream<ChatStreamEvent> streamMessage(
    String prompt, {
    String? aiConsentVersion,
  }) async* {
    yield const ChatStatusEvent('thinking', 'Thinking…');
    final reply = await sendMessage(prompt, aiConsentVersion: aiConsentVersion);
    yield const ChatStatusEvent('writing', 'Writing your answer…');
    yield ChatDoneEvent(reply: reply);
  }

  @override
  Future<ChatConsentStatus> loadChatConsent() async => ChatConsentStatus(
    granted: _chatConsentVersion.isNotEmpty,
    version: _chatConsentVersion,
  );

  @override
  Future<ChatConsentStatus> grantChatConsent(String version) async {
    _chatConsentVersion = version;
    return loadChatConsent();
  }

  @override
  Future<void> revokeChatConsent() async => _chatConsentVersion = '';

  @override
  Future<void> clearChatHistory() async {
    _data = _data.copyWith(messages: const []);
  }

  @override
  Future<void> sendChatFeedback(
    String messageId, {
    required String rating,
    String? reason,
  }) async {}

  @override
  Future<DemoRecommendation?> saveQuestionnaire(
    QuestionnaireAnswers answers,
  ) async => null;

  @override
  Future<void> updateDisplayName(String name) async {
    _data = _data.copyWith(
      profile: UserProfile(
        name: name.trim(),
        strategy: _data.profile.strategy,
        goal: _data.profile.goal,
        topSpendCategories: _data.profile.topSpendCategories,
        nextTarget: _data.profile.nextTarget,
        email: _data.profile.email,
      ),
    );
  }

  @override
  Future<void> switchStrategy(String code) async {
    final playbook = buildPlaybook(
      code: code,
      walletNames: _data.wallet.map((card) => card.name).toList(),
    );
    _data = _data.copyWith(
      strategyPlan: StrategyPlan.maybeForCode(code),
      playbook: playbook,
      profile: UserProfile(
        name: _data.profile.name,
        strategy: code,
        goal: _data.profile.goal,
        topSpendCategories: _data.profile.topSpendCategories,
        nextTarget: playbook?.nextCard ?? _data.profile.nextTarget,
        email: _data.profile.email,
      ),
    );
  }
}
