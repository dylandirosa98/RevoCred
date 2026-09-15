import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../data/app_repository.dart';
import '../data/demo_seed.dart';
import '../logic/demo_recommendation.dart';
import '../models/app_models.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('AppConfig must be overridden.'),
);

final appRepositoryProvider = Provider<AppRepository>(
  (ref) => throw UnimplementedError('AppRepository must be overridden.'),
);

class AppState {
  const AppState({
    required this.isAuthenticated,
    required this.isLoading,
    this.data,
    this.error,
    this.actionMessage,
    this.recommendation,
  });

  final bool isAuthenticated;
  final bool isLoading;
  final AppData? data;
  final String? error;
  final String? actionMessage;
  final DemoRecommendation? recommendation;

  AppState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    AppData? data,
    String? error,
    bool clearError = false,
    String? actionMessage,
    bool clearActionMessage = false,
    DemoRecommendation? recommendation,
  }) => AppState(
    isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    isLoading: isLoading ?? this.isLoading,
    data: data ?? this.data,
    error: clearError ? null : error ?? this.error,
    actionMessage: clearActionMessage
        ? null
        : actionMessage ?? this.actionMessage,
    recommendation: recommendation ?? this.recommendation,
  );
}

final appControllerProvider = NotifierProvider<AppController, AppState>(
  AppController.new,
);

class AppController extends Notifier<AppState> {
  AppRepository get _repository => ref.read(appRepositoryProvider);
  AppConfig get _config => ref.read(appConfigProvider);

  @override
  AppState build() {
    final authenticated = _repository.isAuthenticated;
    return AppState(
      isAuthenticated: authenticated,
      isLoading: !_config.useMocks && authenticated,
      data: _config.useMocks ? createDemoAppData() : null,
    );
  }

  Future<void> initialize() async {
    if (!_repository.isAuthenticated) {
      state = state.copyWith(isLoading: false, isAuthenticated: false);
      return;
    }
    await refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _repository.loadAppData();
      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        data: data,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<AuthResult> signIn(String email, String password) async {
    final result = await _repository.signIn(email, password);
    if (result.success && _repository.isAuthenticated) await refresh();
    return result;
  }

  Future<AuthResult> signUp(String email, String password) async {
    final result = await _repository.signUp(email, password);
    if (result.success && _repository.isAuthenticated) await refresh();
    return result;
  }

  Future<void> signOut() async {
    await _repository.signOut();
    if (_config.useMocks) {
      state = AppState(
        isAuthenticated: true,
        isLoading: false,
        data: await _repository.loadAppData(),
        actionMessage: 'Demo session reset locally.',
      );
    } else {
      state = const AppState(isAuthenticated: false, isLoading: false);
    }
  }

  Future<bool> addCard(String cardId) async {
    try {
      await _repository.addCard(cardId);
      await refresh();
      state = state.copyWith(actionMessage: 'Card added to your wallet.');
      return true;
    } catch (error) {
      state = state.copyWith(error: 'Could not add card: $error');
      return false;
    }
  }

  Future<bool> removeCard(String walletCardId) async {
    try {
      await _repository.removeCard(walletCardId);
      await refresh();
      state = state.copyWith(actionMessage: 'Card removed from your wallet.');
      return true;
    } catch (error) {
      state = state.copyWith(error: 'Could not remove card: $error');
      return false;
    }
  }

  Future<void> sendMessage(String prompt) async {
    final data = state.data;
    if (data == null) return;
    final userMessage = ChatMessage(
      id: 'user-${DateTime.now().microsecondsSinceEpoch}',
      role: MessageRole.user,
      content: prompt,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(
      data: data.copyWith(messages: [...data.messages, userMessage]),
      clearError: true,
    );
    try {
      final reply = await _repository.sendMessage(prompt);
      final current = state.data;
      if (current != null) {
        state = state.copyWith(
          data: current.copyWith(messages: [...current.messages, reply]),
        );
      }
    } catch (error) {
      state = state.copyWith(error: 'REVO could not respond: $error');
      rethrow;
    }
  }

  Future<DemoRecommendation> completeQuestionnaire(
    QuestionnaireAnswers answers,
  ) async {
    final localRecommendation = computeDemoRecommendation(answers);
    final serverRecommendation = _config.useMocks
        ? null
        : await _repository.saveQuestionnaire(answers);
    if (!_config.useMocks) {
      await refresh();
      if (state.error != null) {
        throw StateError(state.error ?? 'Could not refresh app data.');
      }
    }
    final recommendation = serverRecommendation ?? localRecommendation;
    final current = state.data;
    state = state.copyWith(
      data: current?.copyWith(monthlySpend: answers.monthlySpend),
      recommendation: recommendation,
      actionMessage: _config.useMocks
          ? 'Demo recommendation calculated locally. Answers were not sent.'
          : 'Answers saved and recommendation calculated by the Go API.',
    );
    return recommendation;
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearActionMessage: true);
  }
}
