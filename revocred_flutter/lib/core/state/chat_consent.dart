import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_disclosure.dart';
import '../theme/app_theme.dart';
import 'app_controller.dart';

class ChatConsentState {
  const ChatConsentState({required this.disclosure, required this.granted});
  final ChatDisclosure disclosure;

  /// True when REVO may share with the external AI named in [disclosure].
  final bool granted;

  bool get external => disclosure.external;
}

/// Guests have no stored permission; theirs lasts for this app session only.
class _GuestConsent {
  String version = '';
}

final _guestConsentProvider = Provider((ref) => _GuestConsent());

/// The current AI sharing notice and whether this account (or guest session)
/// has agreed to it. Rebuilt when the signed-in state changes, so permission
/// never carries across accounts.
final chatConsentProvider =
    AsyncNotifierProvider<ChatConsentController, ChatConsentState>(
      ChatConsentController.new,
    );

class ChatConsentController extends AsyncNotifier<ChatConsentState> {
  bool get _signedIn => ref.read(appControllerProvider).isAuthenticated;

  @override
  Future<ChatConsentState> build() async {
    ref.watch(appControllerProvider.select((state) => state.isAuthenticated));
    final repository = ref.read(appRepositoryProvider);
    final disclosure = await repository.loadChatDisclosure();
    if (!disclosure.external) {
      return ChatConsentState(disclosure: disclosure, granted: false);
    }
    if (!_signedIn) {
      return ChatConsentState(
        disclosure: disclosure,
        granted: ref.read(_guestConsentProvider).version == disclosure.version,
      );
    }
    final status = await repository.loadChatConsent();
    return ChatConsentState(
      disclosure: disclosure,
      granted: status.granted && status.version == disclosure.version,
    );
  }

  /// Saves agreement to the current notice.
  Future<void> grant() async {
    final current = await future;
    if (!current.external) return;
    var granted = true;
    if (_signedIn) {
      final status = await ref
          .read(appRepositoryProvider)
          .grantChatConsent(current.disclosure.version);
      granted = status.granted && status.version == current.disclosure.version;
    } else {
      ref.read(_guestConsentProvider).version = current.disclosure.version;
    }
    state = AsyncData(
      ChatConsentState(disclosure: current.disclosure, granted: granted),
    );
  }

  /// Turns AI answers off; later messages get basic answers until agreed again.
  Future<void> revoke() async {
    final current = await future;
    if (_signedIn) {
      await ref.read(appRepositoryProvider).revokeChatConsent();
    } else {
      ref.read(_guestConsentProvider).version = '';
    }
    state = AsyncData(
      ChatConsentState(disclosure: current.disclosure, granted: false),
    );
  }

  /// Reloads the notice and permission, e.g. after the server reports that
  /// the AI service changed.
  Future<ChatConsentState> reload() {
    ref.invalidateSelf();
    return future;
  }
}

/// Asks once whether REVO may use the external AI. Returns true to agree,
/// false for a basic answer this time, or null to cancel.
///
/// From settings ([forMessage] false) there is no message to answer, so the
/// basic-answer choice is hidden.
Future<bool?> showChatConsentSheet(
  BuildContext context,
  ChatDisclosure disclosure, {
  bool forMessage = true,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final product = context.product;
      final points = disclosure.dataUsePoints.isEmpty
          ? [disclosure.dataUse]
          : disclosure.dataUsePoints;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .85,
            maxWidth: 640,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Let REVO use AI?',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'AI answers go deeper and can look up current card terms. '
                  'Here is what is shared:',
                  style: TextStyle(color: product.muted),
                ),
                const SizedBox(height: 16),
                _Detail(label: 'AI service', value: disclosure.recipient),
                _Detail(label: 'Model', value: disclosure.model),
                if (disclosure.searchProvider.isNotEmpty)
                  _Detail(
                    label: 'Web search',
                    value: disclosure.searchProvider,
                  ),
                const SizedBox(height: 12),
                for (final point in points)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 7, right: 10),
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: product.action,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            point,
                            style: const TextStyle(height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  'You can turn this off anytime in Profile.',
                  style: TextStyle(color: product.muted, fontSize: 13),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  key: const ValueKey('ai-consent-agree'),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Agree and continue'),
                ),
                if (forMessage) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: const ValueKey('ai-consent-basic'),
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Basic answer instead'),
                  ),
                ],
                TextButton(
                  key: const ValueKey('ai-consent-cancel'),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: value),
        ],
      ),
    ),
  );
}
