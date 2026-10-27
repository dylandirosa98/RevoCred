import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/app_models.dart';
import '../../../core/models/affiliate_offer.dart';
import '../../../core/state/affiliate_providers.dart';
import '../../../shared/widgets/apply_offer_button.dart';
import '../../../core/services/strategy_report_export.dart';
import '../../../core/state/app_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/content_layout.dart';
import 'strategy_roadmap_view.dart';

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
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Strategy report'),
        actions: [
          TextButton(
            key: const ValueKey('continue-strategy-report'),
            onPressed: () => context.go(
              appState.isAuthenticated
                  ? '/home'
                  : '/welcome?save=true&from=report',
            ),
            child: Text(
              appState.isAuthenticated ? 'Continue' : 'Finish account',
            ),
          ),
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
          StrategyRoadmapView(data: data),
          SizedBox(height: product.sectionGap),
          if (!appState.isAuthenticated) ...[
            FilledButton.icon(
              key: const ValueKey('finish-account-bottom'),
              onPressed: () => context.go('/welcome?save=true&from=report'),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Finish creating my account'),
            ),
            const SizedBox(height: 16),
          ],
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
          const ApplyOfferButton(placement: ApplyPlacement.report),
        ],
      ),
    );
  }

  Future<void> _export(AppData data, {bool share = false}) async {
    setState(() => exporting = true);
    try {
      if (data.recommendedCardId != null &&
          !ref.read(appConfigProvider).useMocks &&
          (ref.read(appControllerProvider).isAuthenticated ||
              data.isPersonalPreview)) {
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
