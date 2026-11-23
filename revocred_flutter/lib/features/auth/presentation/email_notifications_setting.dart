import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logic/friendly_error.dart';
import '../../../core/state/app_controller.dart';
import '../../../core/theme/app_theme.dart';

/// Shared state for the signed-in member's optional email updates opt-in
/// stored in Supabase user metadata (`email_notifications_opt_in`).
class EmailNotificationsController extends Notifier<bool> {
  @override
  bool build() {
    ref.watch(appControllerProvider.select((s) => s.isAuthenticated));
    return ref.read(appRepositoryProvider).emailNotificationsOptIn;
  }

  Future<bool> setEnabled(bool enabled) async {
    final saved = await ref
        .read(appControllerProvider.notifier)
        .updateEmailNotificationsOptIn(enabled);
    state = saved;
    return saved;
  }
}

final emailNotificationsProvider =
    NotifierProvider<EmailNotificationsController, bool>(
      EmailNotificationsController.new,
    );

/// Lets signed-in members opt in to or withdraw consent from optional
/// RevoCred update emails at any time, matching the Privacy Policy commitment.
class EmailNotificationsToggle extends ConsumerStatefulWidget {
  const EmailNotificationsToggle({
    this.toggleKey = const ValueKey('email-notifications-toggle'),
    this.onStatusMessage,
    super.key,
  });

  final Key toggleKey;
  final ValueChanged<String>? onStatusMessage;

  @override
  ConsumerState<EmailNotificationsToggle> createState() =>
      _EmailNotificationsToggleState();
}

class _EmailNotificationsToggleState
    extends ConsumerState<EmailNotificationsToggle> {
  bool _saving = false;

  Future<void> _onChanged(bool value) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final saved = await ref
          .read(emailNotificationsProvider.notifier)
          .setEnabled(value);
      if (!mounted) return;
      final note = saved
          ? 'Subscribed to RevoCred update emails.'
          : 'Unsubscribed from RevoCred update emails.';
      if (widget.onStatusMessage != null) {
        widget.onStatusMessage!(note);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(note)));
      }
    } catch (error) {
      if (!mounted) return;
      final note = friendlyError(error);
      if (widget.onStatusMessage != null) {
        widget.onStatusMessage!(note);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(note)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(emailNotificationsProvider);
    final product = context.product;
    return Material(
      type: MaterialType.transparency,
      child: SwitchListTile.adaptive(
        key: widget.toggleKey,
        contentPadding: EdgeInsets.zero,
        value: enabled,
        onChanged: _saving ? null : _onChanged,
        title: const Text('Email me RevoCred updates'),
        subtitle: Text(
          'Optional product updates and reminders. Turn off anytime to withdraw consent. Essential account and security emails are still sent.',
          style: TextStyle(color: product.muted),
        ),
      ),
    );
  }
}
