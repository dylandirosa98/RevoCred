import '../models/app_models.dart';

class AuthResult {
  const AuthResult({required this.success, this.message});
  final bool success;
  final String? message;
}

abstract interface class AppRepository {
  bool get isAuthenticated;
  Future<AuthResult> signIn(String email, String password);
  Future<AuthResult> signUp(String email, String password);
  Future<void> signOut();
  Future<AppData> loadAppData();
  Future<void> addCard(String cardId);
  Future<void> removeCard(String walletCardId);
  Future<ChatMessage> sendMessage(String prompt);
  Future<DemoRecommendation?> saveQuestionnaire(QuestionnaireAnswers answers);
}
