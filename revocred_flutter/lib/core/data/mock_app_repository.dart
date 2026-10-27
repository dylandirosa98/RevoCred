import '../logic/playbook.dart';
import '../logic/demo_purchase_guide.dart';
import '../models/app_models.dart';
import '../models/chat_disclosure.dart';
import 'app_repository.dart';
import 'demo_seed.dart';

class MockAppRepository implements AppRepository {
  MockAppRepository({AppData? initialData})
    : _data = initialData ?? createDemoAppData();

  AppData _data;
  @override
  String? get accountEmail => null;
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

  @override
  bool get isAuthenticated => true;

  @override
  Future<AuthResult> signIn(String email, String password) async =>
      const AuthResult(
        success: true,
        message: 'Demo session is already active.',
      );

  @override
  Future<AuthResult> signUp(
    String email,
    String password, {
    String displayName = '',
    bool notificationsOptIn = false,
  }) async {
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
  }

  @override
  Future<AppData> loadAppData() async => _data.copyWith(
    purchaseGuide: _data.purchaseGuide ?? demoPurchaseGuide(_data.wallet),
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
      _data = _data.copyWith(
        wallet: [..._data.wallet, card.copyWith(isActive: true)],
      );
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
    _data = _data.copyWith(
      wallet: [..._data.wallet, created],
      playbook: buildPlaybook(
        code: _data.playbook?.code ?? _data.strategyPlan?.code,
        walletNames: [
          ..._data.wallet,
          created,
        ].map((item) => item.name).toList(),
      ),
    );
  }

  @override
  Future<void> removeCard(String walletCardId) async {
    _data = _data.copyWith(
      wallet: _data.wallet
          .where((card) => (card.walletCardId ?? card.id) != walletCardId)
          .toList(),
    );
  }

  @override
  Future<ChatDisclosure> loadChatDisclosure() async =>
      const ChatDisclosure.basic();

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
