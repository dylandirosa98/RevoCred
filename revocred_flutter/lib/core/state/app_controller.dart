import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../data/app_repository.dart';
import '../data/demo_seed.dart';
import '../logic/demo_recommendation.dart';
import '../logic/playbook.dart';
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
    this.passwordRecovery = false,
  });

  final bool isAuthenticated;
  final bool isLoading;
  final AppData? data;
  final String? error;
  final String? actionMessage;
  final DemoRecommendation? recommendation;
  final bool passwordRecovery;

  AppState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    AppData? data,
    String? error,
    bool clearError = false,
    String? actionMessage,
    bool clearActionMessage = false,
    DemoRecommendation? recommendation,
    bool? passwordRecovery,
  }) => AppState(
    isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    isLoading: isLoading ?? this.isLoading,
    data: data ?? this.data,
    error: clearError ? null : error ?? this.error,
    actionMessage: clearActionMessage
        ? null
        : actionMessage ?? this.actionMessage,
    recommendation: recommendation ?? this.recommendation,
    passwordRecovery: passwordRecovery ?? this.passwordRecovery,
  );
}

final appControllerProvider = NotifierProvider<AppController, AppState>(
  AppController.new,
);

class AppController extends Notifier<AppState> {
  int _sessionGeneration = 0;
  AppRepository get _repository => ref.read(appRepositoryProvider);
  AppConfig get _config => ref.read(appConfigProvider);

  @override
  AppState build() {
    final authenticated = _repository.isAuthenticated;
    final subscription = _repository.sessionChanges.listen((session) {
      if (!session.authenticated) {
        _sessionGeneration++;
        state = AppState(
          isAuthenticated: false,
          isLoading: false,
          data: createDemoAppData(),
        );
      } else if (session.passwordRecovery) {
        state = state.copyWith(isAuthenticated: true, passwordRecovery: true);
      } else if (!state.isAuthenticated) {
        state = state.copyWith(isAuthenticated: true);
        unawaited(refresh());
      }
    });
    ref.onDispose(subscription.cancel);
    return AppState(
      isAuthenticated: authenticated,
      isLoading: !_config.useMocks && authenticated,
      data: authenticated && !_config.useMocks ? null : createDemoAppData(),
      passwordRecovery: _repository.isPasswordRecovery,
    );
  }

  Future<void> initialize() async {
    if (!_repository.isAuthenticated) {
      state = AppState(
        isAuthenticated: false,
        isLoading: false,
        data: createDemoAppData(),
      );
      return;
    }
    await refresh();
  }

  Future<void> refresh() async {
    final generation = _sessionGeneration;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _repository.loadAppData();
      if (generation != _sessionGeneration) return;
      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        data: data,
        clearError: true,
      );
    } catch (error) {
      if (generation != _sessionGeneration) return;
      if (error is SessionExpiredException) {
        state = AppState(
          isAuthenticated: false,
          isLoading: false,
          data: createDemoAppData(),
          error: error.toString(),
        );
        return;
      }
      state = AppState(
        isAuthenticated: state.isAuthenticated,
        isLoading: false,
        data: state.data ?? createDemoAppData(),
        error: error.toString(),
        passwordRecovery: state.passwordRecovery,
      );
    }
  }

  Future<AuthResult> signIn(String email, String password) async {
    final result = await _repository.signIn(email, password);
    if (result.success && _repository.isAuthenticated) {
      state = state.copyWith(isAuthenticated: true);
      await refresh();
    }
    return result;
  }

  Future<AuthResult> signUp(String email, String password) async {
    final result = await _repository.signUp(email, password);
    if (result.success && _repository.isAuthenticated) {
      state = state.copyWith(isAuthenticated: true);
      await refresh();
    }
    return result;
  }

  Future<void> signOut() async {
    _sessionGeneration++;
    await _repository.signOut();
    if (_config.useMocks) {
      state = AppState(
        isAuthenticated: true,
        isLoading: false,
        data: await _repository.loadAppData(),
        actionMessage: 'Demo session reset locally.',
      );
    } else {
      state = AppState(
        isAuthenticated: false,
        isLoading: false,
        data: createDemoAppData(),
        actionMessage: 'Signed out. Showing the demo profile.',
      );
    }
  }

  Future<void> finishPasswordRecovery(String password) async {
    await _repository.updatePassword(password);
    state = state.copyWith(passwordRecovery: false);
    await refresh();
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

  Future<bool> addCustomCard(CustomCardDraft card) async {
    try {
      await _repository.addCustomCard(card);
      await refresh();
      state = state.copyWith(
        actionMessage: '${card.name} added to your wallet.',
      );
      return true;
    } catch (error) {
      state = state.copyWith(error: 'Could not add custom card: $error');
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
    final generation = _sessionGeneration;
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
      if (generation != _sessionGeneration) return;
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
    final generation = _sessionGeneration;
    final recommendation = _config.useMocks
        ? computeDemoRecommendation(answers)
        : await _repository.saveQuestionnaire(answers);
    if (generation != _sessionGeneration) throw const SessionExpiredException();
    if (!_config.useMocks) {
      await refresh();
      if (state.error != null) {
        throw StateError(state.error ?? 'Could not refresh app data.');
      }
    }
    if (recommendation == null) {
      throw StateError(
        'Your answers were saved. No eligible card currently improves your wallet under these assumptions. Update your preferences or keep your existing cards.',
      );
    }
    final current = state.data;
    final recommendationJson = answers.toRecommendationJson();
    final plan = StrategyPlan.fromAnswers(answers);
    state = state.copyWith(
      data: current?.copyWith(
        monthlySpend: answers.monthlySpend,
        strategyPlan: _config.useMocks ? plan : current.strategyPlan,
        playbook: _config.useMocks
            ? buildPlaybook(
                code: plan.code,
                walletNames: current.wallet.map((card) => card.name).toList(),
              )
            : current.playbook,
        strategyPreferences: _config.useMocks
            ? StrategyPreferences.fromApiJson(recommendationJson)
            : current.strategyPreferences,
      ),
      recommendation: recommendation,
      actionMessage: _config.useMocks
          ? 'Demo recommendation calculated locally. Answers were not sent.'
          : 'Answers saved and recommendation calculated by the Go API.',
    );
    return recommendation;
  }

  Future<void> switchStrategy(String code) async {
    await _repository.switchStrategy(code);
    if (_config.useMocks) {
      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        data: await _repository.loadAppData(),
        actionMessage: 'Switched to $code.',
      );
      return;
    }
    await refresh();
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearActionMessage: true);
  }
}
