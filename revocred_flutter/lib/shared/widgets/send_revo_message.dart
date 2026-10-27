import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/state/app_controller.dart';

class _SendGate {
  bool busy = false;
}

final _sendGateProvider = Provider((ref) => _SendGate());

/// One explicit choice per message: no saved permission can cross accounts,
/// provider changes or a later chat. All product chat entry points use this gate.
Future<bool> sendRevoMessage(
  BuildContext context,
  WidgetRef ref,
  String value, {
  bool openChat = false,
  VoidCallback? onSending,
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
      throw StateError('Create an account to discuss your personal plan.');
    }
    final disclosure = await repository.loadChatDisclosure();
    if (!context.mounted) return false;
    String? consent;
    if (disclosure.external) {
      final external = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Share this message with AI?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI service: ${disclosure.recipient}'),
                const SizedBox(height: 8),
                Text('Model: ${disclosure.model}'),
                const SizedBox(height: 16),
                Text(disclosure.dataUse),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Use basic reply'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Agree and send'),
            ),
          ],
        ),
      );
      if (external == null) return false;
      if (external) consent = disclosure.version;
    }
    if (!context.mounted) return false;
    if (app.sessionGeneration != session ||
        repository.accountEmail != account) {
      throw StateError(
        'Your account changed. Send again from the current account.',
      );
    }
    if (openChat) context.go('/revo');
    onSending?.call();
    await app.sendMessage(
      prompt,
      aiConsentVersion: consent,
      expectedSessionGeneration: session,
    );
    return true;
  } catch (_) {
    if (messenger.mounted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'REVO could not send. Check your account and connection, then try again. Your plan and wallet are still available.',
          ),
        ),
      );
    }
    return false;
  } finally {
    gate.busy = false;
  }
}
