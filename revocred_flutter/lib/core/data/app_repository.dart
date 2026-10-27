import '../models/app_models.dart';
import '../models/chat_disclosure.dart';

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
  });
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
  Future<ChatMessage> sendMessage(String prompt, {String? aiConsentVersion});
  Future<DemoRecommendation?> saveQuestionnaire(QuestionnaireAnswers answers);
  Future<void> switchStrategy(String code);
  Future<void> updateDisplayName(String name);
}

class AccountSession {
  const AccountSession({
    required this.authenticated,
    this.passwordRecovery = false,
  });
  final bool authenticated;
  final bool passwordRecovery;
}

class SessionExpiredException implements Exception {
  const SessionExpiredException();
  @override
  String toString() => 'Your session has expired. Please sign in again.';
}
