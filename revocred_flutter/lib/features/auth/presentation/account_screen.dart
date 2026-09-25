import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/state/app_controller.dart';

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
  bool busy = false;
  String? message;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action, String success) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action();
      if (mounted) setState(() => message = success);
    } catch (error) {
      if (mounted) setState(() => message = error.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.read(appRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.recovery
              ? 'Set a new password'
              : widget.help
              ? 'Account recovery'
              : 'Account settings',
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (!widget.recovery) ...[
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email address'),
                ),
                const SizedBox(height: 16),
                if (widget.help) ...[
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () => run(
                            () async {
                              if (!email.text.contains('@')) {
                                throw StateError('Enter your email address.');
                              }
                              await repository.requestPasswordReset(
                                email.text.trim(),
                              );
                            },
                            'If an account exists, a recovery email has been sent. Check your inbox.',
                          ),
                    child: const Text('Send password reset'),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => run(
                            () => repository.resendVerification(
                              email.text.trim(),
                            ),
                            'If confirmation is needed, check your inbox.',
                          ),
                    child: const Text('Resend account confirmation'),
                  ),
                  TextButton(
                    onPressed: () => context.go('/welcome'),
                    child: const Text('Back to sign in'),
                  ),
                ] else
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => run(
                            () => repository.updateEmail(email.text.trim()),
                            'Check both inboxes to confirm your email change.',
                          ),
                    child: const Text('Change email'),
                  ),
              ],
              if (!widget.help) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: password,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: widget.recovery
                        ? 'New password (at least 12 characters)'
                        : 'Password (new for change; current for deletion)',
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
                          password.clear();
                          if (context.mounted) context.go('/home');
                        }, 'Password updated.'),
                  child: const Text('Update password'),
                ),
                if (!widget.recovery) ...[
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
                                  title: const Text('Your account data (JSON)'),
                                  content: SizedBox(
                                    width: 560,
                                    child: SingleChildScrollView(
                                      child: SelectableText(json),
                                    ),
                                  ),
                                  actions: [
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
                  const SizedBox(height: 16),
                  const Text(
                    'Deleting your account permanently removes your profile, wallet, questionnaire answers, recommendations and chat from the live service. Backup copies expire under the operator’s backup policy.',
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => run(() async {
                            if (password.text.isEmpty) {
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
                                  'This cannot be undone. Export your data first if you want a copy.',
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
                            if (confirmed != true) return;
                            await repository.deleteAccount(password.text);
                            await ref
                                .read(appControllerProvider.notifier)
                                .signOut();
                            if (context.mounted) context.go('/welcome');
                          }, 'Account deleted.'),
                    child: const Text('Delete my account'),
                  ),
                ],
              ],
              if (widget.recovery)
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          await ref
                              .read(appControllerProvider.notifier)
                              .signOut();
                          if (context.mounted) context.go('/welcome');
                        },
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
    );
  }
}
