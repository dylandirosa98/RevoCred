import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/state/app_controller.dart';
import '../../../core/logic/strategy_digest.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/content_layout.dart';
import '../../../shared/widgets/theme_switcher.dart';

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
          !state.isAuthenticated || config.useMocks
              ? 'Demo profile | Sign in to use your live account'
              : 'Authenticated with Supabase',
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
                'Use the same Decision Flow interface in the appearance that fits your environment.',
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
          onTap: () => context.go('/questionnaire'),
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
    ).showSnackBar(SnackBar(content: Text('$error')));
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: context.product.muted, fontSize: 12),
              ),
              const SizedBox(height: 3),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 180,
              child: Text(
                label,
                style: TextStyle(color: context.product.muted),
              ),
            ),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    ),
  );
}
