import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/state/app_controller.dart';
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
      'Credit card strategy': profile.strategy,
      'Goal': profile.goal,
      'Setup': '${data.wallet.length} active cards',
      'Top spend categories': profile.topSpendCategories,
      'Next application target': profile.nextTarget,
    };
    return ContentLayout(
      maxWidth: 860,
      children: [
        const SectionLabel('Profile'),
        const SizedBox(height: 14),
        Text(profile.name, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          config.useMocks
              ? 'Demo session | Local fixture data'
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
        AppPanel(
          child: Column(
            children: [
              for (final row in rows.entries)
                _ProfileRow(label: row.key, value: row.value),
            ],
          ),
        ),
        const SizedBox(height: 14),
        InkWell(
          key: const ValueKey('questionnaire-launcher'),
          onTap: () => context.push('/questionnaire'),
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
        if (state.recommendation != null) ...[
          const SizedBox(height: 14),
          AppPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Latest local v1 result'),
                const SizedBox(height: 8),
                Text(
                  state.recommendation!.cardName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  'Demo annual value: \$${state.recommendation!.estimatedYearlyValue}',
                  style: TextStyle(color: product.success),
                ),
                const SizedBox(height: 7),
                Text(
                  state.recommendation!.formula,
                  style: TextStyle(color: product.muted),
                ),
              ],
            ),
          ),
        ],
        SizedBox(height: product.sectionGap),
        const SectionLabel('Legal and support'),
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
            if (context.mounted && config.useMocks) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Demo session reset locally.')),
              );
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
