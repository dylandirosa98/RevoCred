import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logic/wallet_score.dart';
import '../../../core/models/app_models.dart';
import '../../../core/models/affiliate_offer.dart';
import '../../../core/state/affiliate_providers.dart';
import '../../../shared/widgets/apply_offer_button.dart';
import '../../../core/services/strategy_report_export.dart';
import '../../../core/state/app_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/content_layout.dart';

class StrategyReportScreen extends ConsumerStatefulWidget {
  const StrategyReportScreen({super.key});

  @override
  ConsumerState<StrategyReportScreen> createState() =>
      _StrategyReportScreenState();
}

class _StrategyReportScreenState extends ConsumerState<StrategyReportScreen> {
  bool exporting = false;

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appControllerProvider);
    final data = appState.data!;
    final plan = data.strategyPlan;
    if (plan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Strategy report')),
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/questionnaire'),
            child: const Text('Complete your questionnaire first'),
          ),
        ),
      );
    }
    final product = context.product;
    final value = strategyReportYearOneValue(data);
    final walletScore = displayWalletScore(
      useLocal:
          !appState.isAuthenticated || ref.watch(appConfigProvider).useMocks,
      storedScore: data.pointsValue,
      localScore: scoreWallet(walletCapabilities(data.wallet)),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to settings',
          onPressed: () => context.go('/profile'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Strategy report'),
        actions: [
          IconButton(
            key: const ValueKey('share-strategy-report'),
            tooltip: 'Share report',
            onPressed: exporting ? null : () => _export(data, share: true),
            icon: const Icon(Icons.ios_share_outlined),
          ),
        ],
      ),
      body: ContentLayout(
        key: const ValueKey('strategy-report'),
        maxWidth: 920,
        padding: EdgeInsets.fromLTRB(
          product.pagePadding,
          product.pagePadding,
          product.pagePadding,
          product.pagePadding * 2,
        ),
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusPill(label: '${plan.code} STRATEGY', color: product.action),
              StatusPill(
                label: '$walletScore WALLET SCORE',
                color: product.success,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Your Personalized Credit Card Strategy',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${data.profile.name}, this is your saved RevoCred plan. It turns your onboarding answers into an application order and wallet playbook.',
            style: TextStyle(color: product.muted, fontSize: 15, height: 1.45),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('download-strategy-report'),
                  onPressed: exporting ? null : () => _export(data),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Download PDF'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: exporting
                      ? null
                      : () => _export(data, share: true),
                  icon: const Icon(Icons.ios_share_outlined),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
          SizedBox(height: product.sectionGap),
          _ReportSection(
            title: 'Your credit profile',
            child: Column(
              children: [
                _FactRow(
                  label: 'Strategy',
                  value: '${plan.code} — ${plan.title}',
                ),
                _FactRow(label: 'Profile band', value: plan.userType),
                _FactRow(label: 'Primary goal', value: plan.goal),
                _FactRow(label: 'Fee comfort', value: plan.feeLevel),
                _FactRow(label: 'Travel focus', value: plan.travelScope),
              ],
            ),
          ),
          _ReportSection(
            title: 'Cards you already have',
            child: data.wallet.isEmpty
                ? Text(
                    'No active cards were added during onboarding. Your roadmap starts with a foundation card.',
                    style: TextStyle(color: product.muted),
                  )
                : Column(
                    children: [
                      for (final card in data.wallet)
                        _ListRow(
                          icon: Icons.credit_card,
                          title: card.name,
                          subtitle: card.bestUse,
                        ),
                    ],
                  ),
          ),
          _ReportSection(
            title: 'Recommended strategy',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Build around the ${plan.ecosystem} ecosystem, adding cards in sequence only when each one fits your normal spending and the benefits justify its cost.',
                  style: TextStyle(color: product.muted, height: 1.45),
                ),
                if (plan.debitCard.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ListRow(
                    icon: Icons.account_balance_outlined,
                    title: 'Optional banking foundation',
                    subtitle: plan.debitCard,
                  ),
                ],
              ],
            ),
          ),
          _ReportSection(
            title: 'How to use your wallet',
            child: Column(
              children: data.wallet.isEmpty
                  ? [
                      const _ListRow(
                        icon: Icons.check_circle_outline,
                        title: 'Start with the foundation card',
                        subtitle:
                            'Use it for normal budgeted purchases and pay every statement balance in full.',
                      ),
                    ]
                  : [
                      for (final card in data.wallet)
                        _ListRow(
                          icon: Icons.check_circle_outline,
                          title: card.name,
                          subtitle:
                              'Use for ${card.bestUse.toLowerCase()} when current issuer terms and merchant coding qualify.',
                        ),
                    ],
            ),
          ),
          _ReportSection(
            title: 'Application roadmap',
            child: Column(
              children: [
                for (final entry in data.roadmap.indexed)
                  _RoadmapRow(
                    number: entry.$1 + 1,
                    card: entry.$2.cardId,
                    note: '${entry.$2.stage}: ${entry.$2.note}',
                    last: entry.$1 == data.roadmap.length - 1,
                  ),
              ],
            ),
          ),
          const ApplyOfferButton(placement: ApplyPlacement.report),
          _ReportSection(
            title: 'Current wallet annual value',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\$$value',
                  style: TextStyle(
                    color: product.success,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Current wallet estimate after annual fees. One cent per point; excludes housing rewards, bonuses, conditional credits and conditional reward uplift. Not guaranteed value.',
                    style: TextStyle(color: product.muted, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          _ReportSection(
            title: 'Important notes',
            child: const Column(
              children: [
                _Note(
                  'Pay statement balances in full; interest can erase rewards value.',
                ),
                _Note(
                  'Verify current annual fees, benefits, offers, and issuer eligibility rules before applying.',
                ),
                _Note('Approval and redemption value are not guaranteed.'),
                _Note(
                  'This report is educational guidance, not financial, tax, legal, or approval advice.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export(AppData data, {bool share = false}) async {
    setState(() => exporting = true);
    try {
      if (data.recommendedCardId != null &&
          !ref.read(appConfigProvider).useMocks &&
          ref.read(appControllerProvider).isAuthenticated) {
        await ref.read(affiliateOffersProvider.future);
        if (!mounted) return;
      }
      final application = ref.read(
        recommendedApplicationProvider(ApplyPlacement.report),
      );
      if (share) {
        await shareStrategyReport(data, application: application);
      } else {
        await downloadStrategyReport(data, application: application);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export the report: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }
}

class _ReportSection extends StatelessWidget {
  const _ReportSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: context.product.sectionGap),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(title),
        const SizedBox(height: 10),
        AppPanel(child: child),
      ],
    ),
  );
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 118,
          child: Text(label, style: TextStyle(color: context.product.muted)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: context.product.action),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(subtitle, style: TextStyle(color: context.product.muted)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RoadmapRow extends StatelessWidget {
  const _RoadmapRow({
    required this.number,
    required this.card,
    required this.note,
    required this.last,
  });

  final int number;
  final String card;
  final String note;
  final bool last;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Column(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: context.product.action,
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (!last)
            Container(width: 2, height: 42, color: context.product.border),
        ],
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(card, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(note, style: TextStyle(color: context.product.muted)),
            ],
          ),
        ),
      ),
    ],
  );
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('•  '),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
