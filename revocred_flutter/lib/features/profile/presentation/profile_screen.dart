import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/chat_errors.dart';
import '../../../core/state/app_controller.dart';
import '../../../core/state/chat_consent.dart';
import '../../../core/logic/strategy_digest.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/content_layout.dart';
import '../../../shared/widgets/theme_switcher.dart';
import '../../../core/logic/friendly_error.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final data = state.data!;
    final config = ref.watch(appConfigProvider);
    final profile = data.profile;
    final product = context.product;
    final rows = {
      'Email': profile.email,
      'Strategy number':
          data.strategyPlan?.code ?? data.playbook?.code ?? profile.strategy,
      'Goal': profile.goal,
      'Setup': '${data.wallet.length} active cards',
      'Top spend categories': profile.topSpendCategories,
      'Next application target':
          strategyNextCardName(data) ?? 'No application recommended',
    };
    return ContentLayout(
      maxWidth: 860,
      children: [
        const SectionLabel('Profile'),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                profile.name.isEmpty ? 'No name yet' : profile.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            TextButton.icon(
              key: const ValueKey('edit-display-name'),
              onPressed: () => _editName(context, ref, profile.name),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          config.useMocks
              ? 'Demo mode'
              : !state.isAuthenticated
              ? 'Guest preview · Sign in to save your plan'
              : 'Signed in',
          style: TextStyle(color: product.success, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: product.sectionGap),
        const SectionLabel('Appearance'),
        const SizedBox(height: 10),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Light or dark',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Match your phone, or always use light or dark.',
                style: TextStyle(color: product.muted),
              ),
              const SizedBox(height: 16),
              const ThemeSwitcher(),
            ],
          ),
        ),
        SizedBox(height: product.sectionGap),
        const SectionLabel('Account summary'),
        const SizedBox(height: 10),
        AppPanel(
          child: Column(
            children: [
              for (final row in rows.entries.indexed) ...[
                if (row.$1 > 0) Divider(height: 1, color: product.border),
                _ProfileRow(label: row.$2.key, value: row.$2.value),
              ],
            ],
          ),
        ),
        if (data.strategyPlan != null) ...[
          const SizedBox(height: 14),
          InkWell(
            key: const ValueKey('view-strategy-report'),
            onTap: () => context.go('/strategy-report'),
            borderRadius: BorderRadius.circular(product.radius),
            child: AppPanel(
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: product.success.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(product.radius * .6),
                    ),
                    child: Icon(
                      Icons.description_outlined,
                      color: product.success,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${data.strategyPlan!.code} strategy report',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'View, download, or share your saved personalized plan.',
                          style: TextStyle(color: product.muted),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        InkWell(
          key: const ValueKey('questionnaire-launcher'),
          // go, not push: the questionnaire is a full-screen route outside the
          // shell, so pushing it left the URL on /profile and stacked a screen
          // the back button would return to.
          onTap: () => context.go('/questionnaire?from=profile'),
          borderRadius: BorderRadius.circular(product.radius),
          child: AppPanel(
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: product.action.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(product.radius * .6),
                  ),
                  child: Icon(Icons.tune, color: product.action),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tune your recommendation',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Update wallet, fee, travel, spend, and reward preferences.',
                        style: TextStyle(color: product.muted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
        if (state.isAuthenticated) const _AiAnswersSetting(),
        SizedBox(height: product.sectionGap),
        const SectionLabel('Expert help'),
        const SizedBox(height: 10),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Talk to a credit card expert',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Want a human review of your setup? A credit card expert can answer questions your roadmap cannot.',
                textAlign: TextAlign.center,
                style: TextStyle(color: product.muted),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                key: const ValueKey('expert-link'),
                onPressed: () => launchUrl(
                  Uri.parse('https://thecreditcardstrategist.com'),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('thecreditcardstrategist.com'),
              ),
            ],
          ),
        ),
        SizedBox(height: product.sectionGap),
        const SectionLabel('Legal and support'),
        if (!config.useMocks)
          TextButton(
            onPressed: () => context.push('/account'),
            child: const Text('Account settings, export and deletion'),
          ),
        TextButton(
          onPressed: () => context.push('/legal'),
          child: const Text('Privacy and terms'),
        ),
        const SizedBox(height: 10),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Educational use only',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'REVO estimates are not financial, tax, or legal advice. Card terms, approval, and redemption value are not guaranteed.',
                style: TextStyle(color: product.muted),
              ),
              const Divider(height: 28),
              const Text(
                'Support',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              SelectableText(
                'support@revocred.app',
                style: TextStyle(color: product.action),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () async {
            await ref.read(appControllerProvider.notifier).signOut();
            if (!context.mounted) return;
            // Leaving a signed-in screen for a signed-out one must not strand
            // the visitor on an account page.
            if (config.useMocks) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Demo session reset locally.')),
              );
            } else {
              context.go('/welcome');
            }
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: product.danger,
            side: BorderSide(color: product.danger),
          ),
          icon: const Icon(Icons.logout),
          label: Text(config.useMocks ? 'Log out and reset demo' : 'Log out'),
        ),
      ],
    );
  }
}

Future<void> _editName(
  BuildContext context,
  WidgetRef ref,
  String current,
) async {
  final controller = TextEditingController(text: current);
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Your name'),
      content: TextField(
        key: const ValueKey('display-name-field'),
        controller: controller,
        autofocus: true,
        maxLength: 60,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('display-name-save'),
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (name == null || name.trim().isEmpty) return;
  try {
    await ref.read(appControllerProvider.notifier).updateDisplayName(name);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(friendlyError(error))));
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: context.product.compact ? 8 : 11),
    child: LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 500) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.product.muted, fontSize: 12),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.product.muted),
              ),
            ),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// Lets a signed-in member turn REVO's external AI answers on or off. Shown
/// only when the server has an external AI configured.
class _AiAnswersSetting extends ConsumerStatefulWidget {
  const _AiAnswersSetting();

  @override
  ConsumerState<_AiAnswersSetting> createState() => _AiAnswersSettingState();
}

class _AiAnswersSettingState extends ConsumerState<_AiAnswersSetting> {
  bool saving = false;

  @override
  Widget build(BuildContext context) {
    final consent = ref.watch(chatConsentProvider).value;
    if (consent == null || !consent.external) return const SizedBox.shrink();
    final product = context.product;
    return Padding(
      padding: EdgeInsets.only(top: product.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('REVO'),
          const SizedBox(height: 10),
          AppPanel(
            // Its own Material keeps the tile's ink visible on the panel.
            child: Material(
              type: MaterialType.transparency,
              child: SwitchListTile.adaptive(
                key: const ValueKey('ai-answers-toggle'),
                contentPadding: EdgeInsets.zero,
                value: consent.granted,
                onChanged: saving ? null : (on) => _change(on, consent),
                title: const Text('AI answers (REVO)'),
                subtitle: Text(
                  'Uses ${consent.disclosure.recipient} to answer in more depth. '
                  'Off = basic answers from your plan.',
                  style: TextStyle(color: product.muted),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _change(bool on, ChatConsentState consent) async {
    final notifier = ref.read(chatConsentProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    if (on) {
      final agreed = await showChatConsentSheet(
        context,
        consent.disclosure,
        forMessage: false,
      );
      if (agreed != true || !mounted) return;
    }
    setState(() => saving = true);
    try {
      on ? await notifier.grant() : await notifier.revoke();
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(chatErrorMessage(error))));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}
