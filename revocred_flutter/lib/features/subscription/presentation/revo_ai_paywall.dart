import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/ai_plan.dart';
import '../../../core/services/subscriptions.dart';
import '../../../core/state/ai_plan.dart';
import '../../../core/state/app_controller.dart';
import '../../../core/theme/app_theme.dart';

/// Opens the REVO AI plan sheet. [limitMessage] is the server's wording when
/// it opens because today's free AI answers are used up.
Future<void> showRevoAIPaywall(BuildContext context, {String? limitMessage}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => RevoAIPaywall(limitMessage: limitMessage),
    );

/// Formats a date as "Dec 11, 2026".
String formatPlanDate(DateTime value) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
  ];
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}

/// Opens Apple's subscription settings, where members cancel or change plans.
Future<void> openManageSubscriptions() =>
    launchUrl(appStoreSubscriptionsUrl, mode: LaunchMode.externalApplication);

/// The REVO AI subscription: what it adds, its price from the App Store,
/// Apple's required renewal terms, Restore Purchases, and the legal links.
/// A purchase is offered only when this build can sell (iOS with RevenueCat)
/// and the server accepts App Store subscription events; otherwise the
/// sheet explains the free allowance without a purchase button.
class RevoAIPaywall extends ConsumerStatefulWidget {
  const RevoAIPaywall({
    super.key,
    this.limitMessage,
    this.confirmDelay = const Duration(seconds: 2),
  });

  final String? limitMessage;

  /// Pause between checks while the server confirms a new purchase.
  final Duration confirmDelay;

  @override
  ConsumerState<RevoAIPaywall> createState() => _RevoAIPaywallState();
}

class _RevoAIPaywallState extends ConsumerState<RevoAIPaywall> {
  StoreOffer? offer;
  bool loadingOffer = false;
  bool busy = false;
  String? notice;

  SubscriptionService get _store => ref.read(subscriptionServiceProvider);

  @override
  void initState() {
    super.initState();
    if (_store.available) {
      loadingOffer = true;
      unawaited(_loadOffer());
    }
  }

  Future<void> _loadOffer() async {
    StoreOffer? loaded;
    try {
      loaded = await _store.loadOffer();
    } catch (_) {
      loaded = null;
    }
    if (!mounted) return;
    setState(() {
      offer = loaded;
      loadingOffer = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    final planState = ref.watch(aiPlanProvider);
    final plan = planState.value;
    final subscriber = plan?.subscriber ?? false;
    final canSell =
        _store.available &&
        plan != null &&
        plan.purchasesEnabled &&
        !subscriber;
    final price = offer?.price ?? r'$10';
    final title = Theme.of(context).textTheme.headlineSmall;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                subscriber ? 'You have REVO AI' : 'REVO AI — $price/month',
                key: const ValueKey('paywall-title'),
                style: title,
              ),
              if (widget.limitMessage != null && !subscriber) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: product.action.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(product.radius * .6),
                  ),
                  child: Text(widget.limitMessage!),
                ),
              ],
              const SizedBox(height: 16),
              if (plan != null) ...[
                Text(
                  plan.usage,
                  key: const ValueKey('paywall-usage'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (subscriber && plan.expiresAt != null)
                  Text(
                    plan.appStoreSubscription
                        ? 'Renews or ends ${formatPlanDate(plan.expiresAt!)}'
                        : 'Included until ${formatPlanDate(plan.expiresAt!)}',
                    style: TextStyle(color: product.muted),
                  ),
                if (subscriber && plan.source == 'manual')
                  Text(
                    'Included with your account.',
                    style: TextStyle(color: product.muted),
                  ),
                const SizedBox(height: 12),
              ],
              const _Benefit(
                Icons.bolt,
                '60 AI answers a day, instead of 3 on the free plan',
              ),
              const _Benefit(
                Icons.credit_card,
                'For card and money questions only',
              ),
              const _Benefit(
                Icons.event_repeat,
                'Monthly. Cancel anytime in Settings',
              ),
              const SizedBox(height: 16),
              if (subscriber) ...[
                if (plan!.appStoreSubscription)
                  FilledButton.tonalIcon(
                    key: const ValueKey('paywall-manage'),
                    onPressed: openManageSubscriptions,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Manage subscription'),
                  ),
              ] else if (canSell) ...[
                FilledButton(
                  key: const ValueKey('paywall-subscribe'),
                  onPressed: busy || offer == null ? null : _purchase,
                  child: busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('Subscribe for $price/month'),
                ),
                if (!loadingOffer && offer == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'The subscription could not be loaded from the App Store. Please try again later.',
                      style: TextStyle(color: product.muted),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  'Payment is charged to your Apple ID when you confirm. REVO AI '
                  'renews automatically each month at $price unless you cancel '
                  'at least 24 hours before the end of the current period; '
                  'renewal is charged within the 24 hours before it ends. '
                  'Manage or cancel anytime in Settings › your name › '
                  'Subscriptions.',
                  key: const ValueKey('paywall-terms'),
                  style: TextStyle(color: product.muted, fontSize: 12),
                ),
              ] else
                Text(
                  'AI answers reset within 24 hours. Basic answers from your plan are always available.',
                  key: const ValueKey('paywall-free-note'),
                  style: TextStyle(color: product.muted),
                ),
              if (_store.available && plan != null && plan.purchasesEnabled)
                TextButton(
                  key: const ValueKey('paywall-restore'),
                  onPressed: busy ? null : _restore,
                  child: const Text('Restore Purchases'),
                ),
              if (notice != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    notice!,
                    key: const ValueKey('paywall-notice'),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  TextButton(
                    key: const ValueKey('paywall-terms-link'),
                    onPressed: () => _openLegal(terms: true),
                    child: const Text('Terms of Use'),
                  ),
                  TextButton(
                    key: const ValueKey('paywall-privacy-link'),
                    onPressed: () => _openLegal(terms: false),
                    child: const Text('Privacy Policy'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openLegal({required bool terms}) {
    final config = ref.read(appConfigProvider);
    final url = terms ? config.termsUrl : config.privacyUrl;
    if (url.isNotEmpty) {
      unawaited(
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      );
      return;
    }
    // Demo builds have no hosted pages; show the in-app legal screen.
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push('/legal');
  }

  Future<void> _purchase() async {
    final current = offer;
    if (current == null) return;
    setState(() {
      busy = true;
      notice = null;
    });
    final outcome = await _store.purchase(current);
    await _finish(outcome);
  }

  Future<void> _restore() async {
    setState(() {
      busy = true;
      notice = null;
    });
    final outcome = await _store.restore();
    await _finish(outcome);
  }

  Future<void> _finish(PurchaseOutcome outcome) async {
    String? message;
    switch (outcome.status) {
      case PurchaseStatus.purchased || PurchaseStatus.restored:
        message = await _confirm()
            ? 'REVO AI is active. Enjoy 60 AI answers a day.'
            : 'Purchase received. REVO AI will unlock within a few minutes.';
      case PurchaseStatus.nothingToRestore:
        message = 'No REVO AI subscription was found for this Apple ID.';
      case PurchaseStatus.pending:
        message =
            'Your purchase is pending approval. REVO AI unlocks once it is approved.';
      case PurchaseStatus.cancelled:
        message = null;
      case PurchaseStatus.failed:
        message =
            outcome.message ??
            'The App Store could not complete this. Please try again.';
    }
    if (!mounted) return;
    setState(() {
      busy = false;
      notice = message;
    });
  }

  /// Asks the server to re-read the subscription until it shows as active;
  /// the store's webhook can take a few seconds.
  Future<bool> _confirm() async {
    final repository = ref.read(appRepositoryProvider);
    if (repository is! AIPlanSource) return false;
    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) await Future<void>.delayed(widget.confirmDelay);
      if (!mounted) return false;
      try {
        final plan = await (repository as AIPlanSource).loadAIPlan(
          refresh: true,
        );
        if (plan.subscriber) {
          if (mounted) ref.invalidate(aiPlanProvider);
          return true;
        }
      } catch (_) {
        // Keep trying; the webhook still unlocks the account.
      }
    }
    if (mounted) ref.invalidate(aiPlanProvider);
    return false;
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(icon, size: 20, color: context.product.action),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

/// Profile's "REVO AI plan" row: the plan and today's usage. Tapping opens
/// the plan sheet; App Store subscribers also get "Manage subscription".
class RevoAIPlanRow extends ConsumerWidget {
  const RevoAIPlanRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(aiPlanProvider).value;
    if (plan == null) return const SizedBox.shrink();
    final product = context.product;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              key: const ValueKey('revo-ai-plan-row'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.auto_awesome, color: product.action),
              title: const Text('REVO AI plan'),
              subtitle: Text(
                '${plan.label} · ${plan.usage}',
                style: TextStyle(color: product.muted),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showRevoAIPaywall(context),
            ),
            if (plan.appStoreSubscription)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const ValueKey('revo-ai-manage'),
                  onPressed: openManageSubscriptions,
                  child: const Text('Manage subscription'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
