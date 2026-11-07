import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/chat_errors.dart';
import '../../core/state/app_controller.dart';
import '../../core/state/chat_consent.dart';

class _SendGate {
  bool busy = false;
}

final _sendGateProvider = Provider((ref) => _SendGate());

/// Every REVO entry point sends through here.
///
/// External AI needs agreement to the current sharing notice. A signed-in
/// member agrees once and the server keeps it until they turn it off in
/// Profile; a guest agrees once per app session. When the notice changes the
/// member is asked again. Declining sends a basic answer and saves nothing.
///
/// Returns true when the message was answered. Failures are reported as
/// friendly text through [onError], or a snackbar when it is null; a
/// cancelled send reports nothing.
Future<bool> sendRevoMessage(
  BuildContext context,
  WidgetRef ref,
  String value, {
  bool openChat = false,
  VoidCallback? onSending,
  ValueChanged<String>? onError,
  ValueChanged<String>? onStatus,
}) async {
  final prompt = value.trim();
  final gate = ref.read(_sendGateProvider);
  if (prompt.isEmpty || gate.busy) return false;
  gate.busy = true;
  final app = ref.read(appControllerProvider.notifier);
  final repository = ref.read(appRepositoryProvider);
  final session = app.sessionGeneration;
  final account = repository.accountEmail;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final state = ref.read(appControllerProvider);
    if (!state.isAuthenticated && state.data?.isPersonalPreview == true) {
      throw const ChatSendException(
        'account_required',
        'Create an account to let REVO discuss your personal plan.',
      );
    }
    // One retry covers a notice that changed between asking and sending.
    for (var attempt = 0; ; attempt++) {
      if (ref.read(chatConsentProvider).hasError || attempt > 0) {
        ref.invalidate(chatConsentProvider);
      }
      final consent = await ref.read(chatConsentProvider.future);
      if (!context.mounted) return false;
      var useAI = consent.granted;
      if (consent.external && !consent.granted) {
        final choice = await showChatConsentSheet(context, consent.disclosure);
        if (choice == null || !context.mounted) return false;
        if (choice) {
          if (app.sessionGeneration != session ||
              repository.accountEmail != account) {
            throw const ChatSendException(
              'account_changed',
              'Your account changed. Send again from the current account.',
            );
          }
          await ref.read(chatConsentProvider.notifier).grant();
          useAI = true;
        }
      }
      if (!context.mounted) return false;
      if (app.sessionGeneration != session ||
          repository.accountEmail != account) {
        throw const ChatSendException(
          'account_changed',
          'Your account changed. Send again from the current account.',
        );
      }
      if (openChat && attempt == 0) context.go('/revo');
      onSending?.call();
      try {
        // The explicit version makes the server refuse rather than silently
        // downgrade if the notice changed after it was shown.
        await app.sendMessage(
          prompt,
          aiConsentVersion: useAI ? consent.disclosure.version : null,
          expectedSessionGeneration: session,
          onStatus: onStatus,
        );
        return true;
      } on ChatSendException catch (error) {
        if (error.code != 'ai_consent_changed' || attempt > 0) rethrow;
      }
    }
  } on ChatCancelledException {
    return false;
  } catch (error) {
    final message = chatErrorMessage(error);
    if (onError != null) {
      onError(message);
    } else if (messenger.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
    return false;
  } finally {
    gate.busy = false;
  }
}
