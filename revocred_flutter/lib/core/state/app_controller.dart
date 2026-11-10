import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../data/app_repository.dart';
import '../data/demo_seed.dart';
import '../data/onboarding_draft_store.dart';
import '../logic/demo_recommendation.dart';
import '../logic/playbook.dart';
import '../logic/friendly_error.dart';
import '../models/app_models.dart';
import '../models/chat_errors.dart';

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
    bool clearRecommendation = false,
    bool? passwordRecovery,
  }) => AppState(
    isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    isLoading: isLoading ?? this.isLoading,
    data: data ?? this.data,
    error: clearError ? null : error ?? this.error,
    actionMessage: clearActionMessage
        ? null
        : actionMessage ?? this.actionMessage,
    recommendation: clearRecommendation
        ? null
        : recommendation ?? this.recommendation,
    passwordRecovery: passwordRecovery ?? this.passwordRecovery,
  );
}

final appControllerProvider = NotifierProvider<AppController, AppState>(
  AppController.new,
);

class AppController extends Notifier<AppState> {
  Future<void>? _refreshing;
  int? _refreshGeneration;
  OnboardingDraftStore get draftStore => ref.read(onboardingDraftStoreProvider);
  int _sessionGeneration = 0;
  int get sessionGeneration => _sessionGeneration;
  AppRepository get _repository => ref.read(appRepositoryProvider);
  AppConfig get _config => ref.read(appConfigProvider);

  @override
  AppState build() {
    final authenticated = _repository.isAuthenticated;
    var accountEmail = _repository.accountEmail;
    String? userId;
    final subscription = _repository.sessionChanges.listen(
      (session) {
        final changedAccount =
            session.authenticated &&
            state.isAuthenticated &&
            ((userId != null &&
                    session.userId != null &&
                    userId != session.userId) ||
                accountEmail != _repository.accountEmail);
        accountEmail = session.authenticated ? _repository.accountEmail : null;
        userId = session.userId;
        if (changedAccount ||
            (session.authenticated && !state.isAuthenticated)) {
          _sessionGeneration++;
          state = AppState(
            isAuthenticated: true,
            isLoading: true,
            passwordRecovery: session.passwordRecovery,
          );
          unawaited(refresh());
          return;
        }
        if (!session.authenticated) {
          _sessionGeneration++;
          if (state.isAuthenticated) unawaited(draftStore.clear());
          state = AppState(
            isAuthenticated: false,
            isLoading: false,
            data: createDemoAppData(),
          );
        } else if (state.passwordRecovery != session.passwordRecovery) {
          state = state.copyWith(passwordRecovery: session.passwordRecovery);
        }
      },
      onError: (Object error, StackTrace stack) {
        // GoTrue reports retryable refresh and rejected callback errors on this
        // stream. Only its signedOut event revokes an existing local session.
        state = state.copyWith(
          error: 'Could not update your session. Please try again.',
        );
      },
    );
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
      if (!_config.useMocks && draftStore.answers != null) {
        try {
          await completeQuestionnaire(draftStore.answers!);
        } catch (_) {
          /* A saved draft can be retried from onboarding. */
        }
      }
      return;
    }
    await refresh();
  }

  Future<void> refresh() {
    if (_refreshing != null && _refreshGeneration == _sessionGeneration) {
      return _refreshing!;
    }
    _refreshGeneration = _sessionGeneration;
    late final Future<void> pending;
    pending = _refresh().whenComplete(() {
      if (identical(_refreshing, pending)) _refreshing = null;
    });
    _refreshing = pending;
    return pending;
  }

  Future<void> _refresh() async {
    final generation = _sessionGeneration;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      var data = await _repository.loadAppData();
      if (generation != _sessionGeneration) return;
      final pending = draftStore.answers;
      if (!_config.useMocks &&
          pending != null &&
          data.questionnaireAnswers == null &&
          draftStore.email != null &&
          draftStore.email == _repository.accountEmail?.trim().toLowerCase()) {
        await _repository.saveQuestionnaire(pending);
        if (generation != _sessionGeneration) return;
        data = await _repository.loadAppData();
        if (generation != _sessionGeneration) return;
        await draftStore.clear();
      }
      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        data: data,
        clearError: true,
      );
    } catch (error) {
      if (generation != _sessionGeneration) return;
      if (error is SessionExpiredException && !_repository.isAuthenticated) {
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
        data: state.data,
        error: error.toString(),
        passwordRecovery: state.passwordRecovery,
      );
    }
  }

  Future<AuthResult> signIn(String email, String password) async {
    if (!state.isAuthenticated && state.data?.isPersonalPreview == true) {
      await draftStore.bind(email);
    }
    final result = await _repository.signIn(email, password);
    if (result.success && _repository.isAuthenticated) {
      state = state.copyWith(isAuthenticated: true);
      await refresh();
    }
    return result;
  }

  Future<AuthResult> signUp(
    String email,
    String password, {
    String displayName = '',
    bool notificationsOptIn = false,
  }) async {
    final trimmedName = displayName.trim();
    if (!state.isAuthenticated && state.data?.isPersonalPreview == true) {
      await draftStore.bind(email);
    }
    // The name is saved with the plan, so it also has to survive a reload
    // between signing up and confirming the email.
    if (trimmedName.isNotEmpty) await draftStore.saveName(trimmedName);
    final result = await _repository.signUp(
      email,
      password,
      displayName: trimmedName,
      notificationsOptIn: notificationsOptIn,
    );
    if (result.success && _repository.isAuthenticated) {
      state = state.copyWith(isAuthenticated: true);
      await refresh();
    }
    return result;
  }

  Future<void> signOut() async {
    final generation = ++_sessionGeneration;
    await _repository.signOut();
    if (generation != _sessionGeneration && state.isAuthenticated) return;
    await draftStore.clear();
    if (generation != _sessionGeneration && state.isAuthenticated) return;
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
        actionMessage: 'Signed out.',
      );
    }
  }

  Future<void> finishPasswordRecovery(String password) async {
    final generation = _sessionGeneration;
    await _repository.updatePassword(password);
    if (generation != _sessionGeneration) return;
    state = state.copyWith(passwordRecovery: false);
    await refresh();
  }

  Future<bool> addCard(String cardId) async {
    final generation = _sessionGeneration;
    try {
      await _repository.addCard(cardId);
      if (generation != _sessionGeneration) return false;
      await refresh();
      if (generation != _sessionGeneration) return false;
      state = state.copyWith(actionMessage: 'Card added to your wallet.');
      return true;
    } catch (error) {
      if (generation != _sessionGeneration) return false;
      state = state.copyWith(
        error: 'Could not add card. ${friendlyError(error)}',
      );
      return false;
    }
  }

  Future<bool> addCustomCard(CustomCardDraft card) async {
    final generation = _sessionGeneration;
    try {
      await _repository.addCustomCard(card);
      if (generation != _sessionGeneration) return false;
      await refresh();
      if (generation != _sessionGeneration) return false;
      state = state.copyWith(
        actionMessage: '${card.name} added to your wallet.',
      );
      return true;
    } catch (error) {
      if (generation != _sessionGeneration) return false;
      state = state.copyWith(
        error: 'Could not add custom card. ${friendlyError(error)}',
      );
      return false;
    }
  }

  /// Called once a confirmation has been shown, so the same message can show
  /// again for a later action.
  void clearActionMessage() {
    if (state.actionMessage != null) {
      state = state.copyWith(clearActionMessage: true);
    }
  }

  Future<bool> removeCard(String walletCardId) async {
    final generation = _sessionGeneration;
    try {
      await _repository.removeCard(walletCardId);
      if (generation != _sessionGeneration) return false;
      await refresh();
      if (generation != _sessionGeneration) return false;
      state = state.copyWith(actionMessage: 'Card removed from your wallet.');
      return true;
    } catch (error) {
      if (generation != _sessionGeneration) return false;
      state = state.copyWith(
        error: 'Could not remove card. ${friendlyError(error)}',
      );
      return false;
    }
  }

  VoidCallback? _cancelPendingMessage;

  /// Whether a REVO message is waiting for its reply.
  bool get isSendingMessage => _cancelPendingMessage != null;

  /// Aborts the in-flight REVO message; [sendMessage] then throws
  /// [ChatCancelledException] and nothing is kept.
  void cancelPendingMessage() => _cancelPendingMessage?.call();

  /// Sends a REVO message. The prompt shows immediately; on success it is
  /// replaced by the server's copy and followed by the reply. On any failure
  /// or cancel it is removed again, so a retry never duplicates it. Errors are
  /// rethrown for the caller to show; they never set the global [AppState.error].
  Future<void> sendMessage(
    String prompt, {
    String? aiConsentVersion,
    int? expectedSessionGeneration,
    ValueChanged<String>? onStatus,
  }) async {
    if (expectedSessionGeneration != null &&
        expectedSessionGeneration != _sessionGeneration) {
      throw const SessionExpiredException();
    }
    if (!state.isAuthenticated && state.data?.isPersonalPreview == true) {
      throw const ChatSendException(
        'account_required',
        'Create an account to let REVO discuss your personal plan.',
      );
    }
    if (isSendingMessage) {
      throw const ChatSendException(
        'busy',
        'REVO is still answering your last message.',
      );
    }
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
    );
    final done = Completer<ChatDoneEvent>();
    void fail(Object error, [StackTrace? stack]) {
      if (!done.isCompleted) done.completeError(error, stack);
    }

    final subscription = _repository
        .streamMessage(prompt, aiConsentVersion: aiConsentVersion)
        .listen(
          (event) {
            switch (event) {
              case ChatStatusEvent(:final label):
                if (!done.isCompleted) onStatus?.call(label);
              case ChatDoneEvent():
                if (!done.isCompleted) done.complete(event);
            }
          },
          onError: fail,
          onDone: () => fail(
            const ChatSendException(
              'incomplete_response',
              'REVO stopped before finishing. Please try again.',
            ),
          ),
          cancelOnError: true,
        );
    _cancelPendingMessage = () => fail(const ChatCancelledException());
    try {
      final result = await done.future;
      if (generation != _sessionGeneration) return;
      final current = state.data;
      if (current != null) {
        state = state.copyWith(
          data: current.copyWith(
            messages: [
              for (final message in current.messages)
                if (message.id == userMessage.id)
                  result.user ?? message
                else
                  message,
              result.reply,
            ],
          ),
        );
      }
    } catch (_) {
      if (generation == _sessionGeneration) {
        final current = state.data;
        if (current != null) {
          state = state.copyWith(
            data: current.copyWith(
              messages: current.messages
                  .where((message) => message.id != userMessage.id)
                  .toList(),
            ),
          );
        }
      }
      rethrow;
    } finally {
      _cancelPendingMessage = null;
      // Cancelling also aborts a request that is still running.
      unawaited(subscription.cancel());
    }
  }

  /// Deletes the conversation on the server, then locally.
  Future<void> clearChat() async {
    final generation = _sessionGeneration;
    await _repository.clearChatHistory();
    if (generation != _sessionGeneration) return;
    final data = state.data;
    if (data != null) {
      state = state.copyWith(data: data.copyWith(messages: const []));
    }
  }

  /// Records thumbs up/down (with an optional reason) on a REVO reply.
  Future<void> rateMessage(String messageId, String rating, {String? reason}) =>
      _repository.sendChatFeedback(messageId, rating: rating, reason: reason);

  Future<void> prepareQuestionnaire() async {
    if (_config.useMocks) return;
    final generation = _sessionGeneration;
    final catalog = await _repository.loadCatalog();
    if (generation != _sessionGeneration) return;
    state = state.copyWith(data: state.data?.copyWith(catalog: catalog));
  }

  Future<void> clearGuestPreview() async {
    if (state.isAuthenticated) return;
    _sessionGeneration++;
    await draftStore.clear();
    state = AppState(
      isAuthenticated: false,
      isLoading: false,
      data: createDemoAppData(),
    );
  }

  Future<DemoRecommendation?> completeQuestionnaire(
    QuestionnaireAnswers answers,
  ) async {
    final generation = _sessionGeneration;
    if (!_config.useMocks && !state.isAuthenticated) {
      final preview = await _repository.previewQuestionnaire(answers);
      if (generation != _sessionGeneration) {
        throw const SessionExpiredException();
      }
      await draftStore.save(answers, email: draftStore.email);
      state = state.copyWith(
        data: preview,
        clearError: true,
        clearRecommendation: true,
        actionMessage:
            'Your personal preview is ready. Create an account to save it.',
      );
      return null;
    }
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
    if (generation != _sessionGeneration) throw const SessionExpiredException();
    final current = state.data;
    final recommendationJson = answers.toRecommendationJson();
    final plan = StrategyPlan.fromAnswers(answers);
    state = state.copyWith(
      data: current?.copyWith(
        questionnaireAnswers: answers,
        wallet: _config.useMocks
            ? current.catalog
                  .where((card) => answers.existingCardIds.contains(card.id))
                  .map((card) => card.copyWith(isActive: true))
                  .toList()
            : current.wallet,
        monthlySpend: answers.monthlySpend,
        strategyPlan: _config.useMocks ? plan : current.strategyPlan,
        playbook: _config.useMocks
            ? buildPlaybook(
                code: plan.code,
                walletNames: current.catalog
                    .where((card) => answers.existingCardIds.contains(card.id))
                    .map((card) => card.name)
                    .toList(),
              )
            : current.playbook,
        strategyPreferences: _config.useMocks
            ? StrategyPreferences.fromApiJson(recommendationJson)
            : current.strategyPreferences,
      ),
      recommendation: recommendation,
      clearRecommendation: recommendation == null,
      actionMessage: _config.useMocks
          ? 'Demo recommendation calculated locally. Answers were not sent.'
          : 'Your plan is updated.',
    );
    return recommendation;
  }

  Future<void> updateDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw StateError('Enter a name.');
    final generation = _sessionGeneration;
    try {
      await _repository.updateDisplayName(trimmed);
      if (generation != _sessionGeneration) return;
      // Load directly instead of refresh(): refresh() joins an in-flight
      // refresh, which would silently drop this change during startup.
      final data = await _repository.loadAppData();
      if (generation != _sessionGeneration) return;
      state = state.copyWith(
        data: data,
        isLoading: false,
        clearError: true,
        actionMessage: 'Name updated.',
      );
    } catch (error) {
      if (generation != _sessionGeneration) rethrow;
      state = state.copyWith(
        error: 'Could not update your name. ${friendlyError(error)}',
      );
      rethrow;
    }
  }

  Future<void> switchStrategy(String code) async {
    final generation = _sessionGeneration;
    await _repository.switchStrategy(code);
    if (generation != _sessionGeneration) return;
    if (_config.useMocks) {
      final data = await _repository.loadAppData();
      if (generation != _sessionGeneration) return;
      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        data: data,
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
