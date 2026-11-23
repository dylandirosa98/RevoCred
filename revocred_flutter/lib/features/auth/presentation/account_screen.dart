import '../../../core/logic/friendly_error.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/app_repository.dart';
import '../../../core/services/file_download.dart';
import '../../../core/state/app_controller.dart';
import 'email_notifications_setting.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({this.recovery = false, this.help = false, super.key});
  final bool recovery;
  final bool help;
  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final deletionPassword = TextEditingController();
  bool busy = false;
  bool obscurePassword = true;
  bool obscureDeletionPassword = true;
  String? message;

  String validatedEmail() {
    final value = email.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
      throw StateError('Enter a valid email address.');
    }
    return value;
  }

  Future<void> sendAccountEmail(Future<void> Function(String) send) async {
    final value = validatedEmail();
    try {
      await send(value);
    } on AuthException catch (error) {
      // Never reveal whether this email has an account. Operational failures
      // (offline, rate limited, mail delivery) still need actionable feedback.
      if (error.code != 'user_not_found') rethrow;
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    deletionPassword.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action, String? success) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action();
      if (mounted) setState(() => message = success);
    } catch (error) {
      if (mounted) {
        setState(
          () => message = switch (error) {
            AuthException() =>
              error.code == 'reauthentication_needed' ||
                      error.code == 'reauthentication_not_valid'
                  ? 'For your security, sign in again before changing your account.'
                  : friendlyError(error),
            SessionExpiredException() =>
              'Your session has expired. Please sign in again.',
            StateError() => error.message.toString(),
            _ =>
              'Unable to complete this request. Check your connection and try again.',
          },
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.read(appRepositoryProvider);
    final router = GoRouter.maybeOf(context);
    final canPop = Navigator.canPop(context);
    return Scaffold(
      appBar: AppBar(
        leading: !widget.recovery && !canPop && router != null
            ? BackButton(
                onPressed: busy
                    ? null
                    : () => router.go(widget.help ? '/welcome' : '/profile'),
              )
            : null,
        title: Text(
          widget.recovery
              ? 'Set a new password'
              : widget.help
              ? 'Account recovery'
              : 'Account settings',
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(24),
              children: [
                if (!widget.recovery) ...[
                  TextField(
                    controller: email,
                    enabled: !busy,
                    autocorrect: false,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (widget.help) ...[
                    FilledButton(
                      onPressed: busy
                          ? null
                          : () => run(
                              () => sendAccountEmail(
                                repository.requestPasswordReset,
                              ),
                              'If an account exists, a recovery email has been sent. Check your inbox.',
                            ),
                      child: const Text('Send password reset'),
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => run(
                              () => sendAccountEmail(
                                repository.resendVerification,
                              ),
                              'If confirmation is needed, check your inbox.',
                            ),
                      child: const Text('Resend account confirmation'),
                    ),
                    TextButton(
                      onPressed: busy ? null : () => context.go('/welcome'),
                      child: const Text('Back to sign in'),
                    ),
                  ] else
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => run(
                              () => repository.updateEmail(validatedEmail()),
                              'Check both inboxes to confirm your email change.',
                            ),
                      child: const Text('Change email'),
                    ),
                ],
                if (!widget.help) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: password,
                    enabled: !busy,
                    obscureText: obscurePassword,
                    autofillHints: widget.recovery
                        ? const [AutofillHints.newPassword]
                        : null,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: InputDecoration(
                      suffixIcon: IconButton(
                        onPressed: busy
                            ? null
                            : () => setState(
                                () => obscurePassword = !obscurePassword,
                              ),
                        tooltip: obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                      labelText: widget.recovery
                          ? 'New password (at least 12 characters)'
                          : 'New password (at least 12 characters)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () => run(() async {
                            if (password.text.length < 12) {
                              throw StateError(
                                'Use at least 12 characters for a new password.',
                              );
                            }
                            await ref
                                .read(appControllerProvider.notifier)
                                .finishPasswordRecovery(password.text);
                            if (!mounted) return;
                            password.clear();
                            if (context.mounted) context.go('/home');
                          }, 'Password updated.'),
                    child: const Text('Update password'),
                  ),
                  if (!widget.recovery) ...[
                    const Divider(height: 40),
                    Text(
                      'Email preferences',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    EmailNotificationsToggle(
                      toggleKey: const ValueKey('email-notifications-toggle'),
                      onStatusMessage: (text) {
                        if (mounted) setState(() => message = text);
                      },
                    ),
                    const Divider(height: 40),
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => run(
                              () async {
                                final json = await repository.exportAccount();
                                if (!context.mounted) return;
                                await showDialog<void>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text(
                                      'Your account data (JSON)',
                                    ),
                                    content: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: 560,
                                        maxHeight:
                                            MediaQuery.sizeOf(context).height *
                                            .55,
                                      ),
                                      child: SingleChildScrollView(
                                        child: SelectableText(json),
                                      ),
                                    ),
                                    actions: [
                                      if (canDownloadTextFile)
                                        TextButton(
                                          key: const ValueKey(
                                            'download-account-json',
                                          ),
                                          onPressed: () async {
                                            await downloadTextFile(
                                              json,
                                              'revocred-account-export.json',
                                            );
                                          },
                                          child: const Text('Download JSON'),
                                        ),
                                      TextButton(
                                        onPressed: () async {
                                          await Clipboard.setData(
                                            ClipboardData(text: json),
                                          );
                                          if (context.mounted) {
                                            Navigator.pop(context);
                                          }
                                        },
                                        child: const Text('Copy JSON'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Close'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              'Export ready. Keep it private; it contains your account information.',
                            ),
                      child: const Text('Export my data'),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Account deletion',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('account-delete-password'),
                      controller: deletionPassword,
                      enabled: !busy,
                      obscureText: obscureDeletionPassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Current password',
                        suffixIcon: IconButton(
                          onPressed: busy
                              ? null
                              : () => setState(
                                  () => obscureDeletionPassword =
                                      !obscureDeletionPassword,
                                ),
                          tooltip: obscureDeletionPassword
                              ? 'Show current password'
                              : 'Hide current password',
                          icon: Icon(
                            obscureDeletionPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Deleting your account permanently removes your profile, wallet, questionnaire answers, recommendations and chat from the live service. Backup copies expire under the operator’s backup policy.',
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                      ),
                      onPressed: busy
                          ? null
                          : () => run(() async {
                              if (deletionPassword.text.isEmpty) {
                                throw StateError(
                                  'Enter your current password to confirm deletion.',
                                );
                              }
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text(
                                    'Permanently delete your account?',
                                  ),
                                  content: const Text(
                                    'This permanently deletes your profile, questionnaire answers, wallet, plans, and chat history. This cannot be undone. Export your data first if you want a copy.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Delete account'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed != true || !mounted) return;
                              await repository.deleteAccount(
                                deletionPassword.text,
                              );
                              if (!mounted) return;
                              await ref
                                  .read(appControllerProvider.notifier)
                                  .signOut();
                              if (context.mounted) context.go('/welcome');
                            }, null),
                      child: const Text('Delete my account'),
                    ),
                  ],
                ],
                if (widget.recovery)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => run(() async {
                            await ref
                                .read(appControllerProvider.notifier)
                                .signOut();
                            if (context.mounted) context.go('/welcome');
                          }, 'Signed out.'),
                    child: const Text('Cancel recovery and sign out'),
                  ),
                if (busy) const LinearProgressIndicator(),
                if (message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Semantics(liveRegion: true, child: Text(message!)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
