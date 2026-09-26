import '../logic/playbook.dart';
import '../models/app_models.dart';
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
  Future<AuthResult> signUp(String email, String password) =>
      signIn(email, password);

  @override
  Future<void> signOut() async {
    _data = createDemoAppData();
  }

  @override
  Future<AppData> loadAppData() async => _data;

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
    final multipliers = card.rates.entries
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
      multiplier: '${card.rates['other'] ?? 1}x',
      benefits: const ['User-supplied terms'],
      pointMultipliers: multipliers,
      transferablePoints: card.transferablePoints,
      isActive: true,
      walletCardId: id,
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
  Future<ChatMessage> sendMessage(String prompt) async {
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
