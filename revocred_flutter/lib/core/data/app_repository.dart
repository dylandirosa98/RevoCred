import '../models/app_models.dart';
import '../models/chat_disclosure.dart';
import '../models/explore_rewards.dart';
import 'chat_stream.dart';

export 'chat_stream.dart';

class AuthResult {
  const AuthResult({required this.success, this.message});
  final bool success;
  final String? message;
}

abstract interface class AppRepository {
  String? get accountEmail;
  Future<List<CreditCard>> loadCatalog();
  Future<AppData> previewQuestionnaire(QuestionnaireAnswers answers);
  Future<List<ReferenceCard>> searchCardIndex(String query);
  Stream<AccountSession> get sessionChanges;
  bool get isPasswordRecovery;
  Future<void> requestPasswordReset(String email);
  Future<void> resendVerification(String email);
  Future<void> updatePassword(String password);
  Future<void> updateEmail(String email);
  Future<String> exportAccount();
  Future<void> deleteAccount(String password);
  bool get isAuthenticated;
  Future<AuthResult> signIn(String email, String password);
  Future<AuthResult> signUp(
    String email,
    String password, {
    String displayName = '',
    bool notificationsOptIn = false,
    Map<String, dynamic>? pendingPlan,
  });

  /// A guest questionnaire saved with the account at sign-up, waiting to be
  /// imported on the first signed-in load.
  Map<String, dynamic>? get pendingPlan;
  Future<void> clearPendingPlan();
  Future<void> signOut();
  Future<AppData> loadAppData();
  Future<PurchaseGuide> loadPurchaseGuide({
    String travelMode = 'general',
    bool capsAvailable = true,
  });
  Future<void> addCard(String cardId);
  Future<void> addCustomCard(CustomCardDraft card);
  Future<void> removeCard(String walletCardId);
  Future<ChatDisclosure> loadChatDisclosure();

  /// Illustrative flight and hotel redemptions for Explore Rewards.
  Future<ExploreRewards> loadExploreRewards();
  Future<ChatMessage> sendMessage(String prompt, {String? aiConsentVersion});

  /// Sends a message and reports progress before the saved exchange. Closing
  /// the subscription cancels the request.
  Stream<ChatStreamEvent> streamMessage(
    String prompt, {
    String? aiConsentVersion,
  });

  /// The account's saved AI sharing permission.
  Future<ChatConsentStatus> loadChatConsent();
  Future<ChatConsentStatus> grantChatConsent(String version);
  Future<void> revokeChatConsent();
  Future<void> clearChatHistory();
  Future<void> sendChatFeedback(
    String messageId, {
    required String rating,
    String? reason,
  });
  Future<DemoRecommendation?> saveQuestionnaire(QuestionnaireAnswers answers);
  Future<void> switchStrategy(String code);
  Future<void> updateDisplayName(String name);
}

class AccountSession {
  const AccountSession({
    required this.authenticated,
    this.passwordRecovery = false,
    this.userId,
  });
  final bool authenticated;
  final bool passwordRecovery;
  final String? userId;
}

class SessionExpiredException implements Exception {
  const SessionExpiredException();
  @override
  String toString() => 'Your session has expired. Please sign in again.';
}
