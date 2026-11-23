import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logic/friendly_error.dart';
import '../../../core/models/app_models.dart';
import '../../../core/state/app_controller.dart';
import '../../../core/theme/app_theme.dart';

const _monthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _monthShortNames = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

Future<void> showRemindersSheet(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.product.canvas,
    builder: (context) => const RemindersSheet(),
  );
}

class RemindersSheet extends ConsumerStatefulWidget {
  const RemindersSheet({super.key});

  @override
  ConsumerState<RemindersSheet> createState() => _RemindersSheetState();
}

class _RemindersSheetState extends ConsumerState<RemindersSheet> {
  String _filter = 'all';
  bool _loading = false;
  String? _busyKey;
  String? _error;
  bool _showHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh(silent: true);
    });
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      await ref.read(appControllerProvider.notifier).refreshReminders();
      if (mounted) {
        setState(() {
          _loading = false;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = friendlyError(error);
        });
      }
    }
  }

  Future<void> _setStatus(
    ReminderItem item,
    String status, {
    int? snoozeDays,
  }) async {
    if (_busyKey != null) return;
    setState(() {
      _busyKey = item.key;
      _error = null;
    });
    try {
      await ref
          .read(appControllerProvider.notifier)
          .updateReminderState(
            item.key,
            status: status,
            snoozeDays: snoozeDays,
          );
    } catch (error) {
      if (mounted) {
        setState(() => _error = friendlyError(error));
      }
    } finally {
      if (mounted) setState(() => _busyKey = null);
    }
  }

  Future<void> _pickRenewalMonth(ReminderItem item) async {
    if (_busyKey != null || item.walletCardId.isEmpty) return;
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => _RenewalMonthDialog(cardName: item.cardName),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _busyKey = item.key;
      _error = null;
    });
    try {
      await ref
          .read(appControllerProvider.notifier)
          .updateWalletRenewalMonth(item.walletCardId, selected);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saved ${_monthNames[selected - 1]} renewal for ${item.cardName}.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = friendlyError(error));
      }
    } finally {
      if (mounted) setState(() => _busyKey = null);
    }
  }

  void _navigateToRoute(String route) {
    if (route.isEmpty) return;
    Navigator.of(context).pop();
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    final feed =
        ref.watch(appControllerProvider).data?.reminders ??
        ReminderFeed.empty();
    final activeAll = feed.activeReminders;
    final handledAll = feed.handledReminders;

    final filteredActive = activeAll.where(_matchesFilter).toList();
    final filteredHandled = handledAll.where(_matchesFilter).toList();

    final availableFilters = <String, String>{
      'all': 'All (${activeAll.length})',
      if (feed.reminders.any((r) => r.kind == 'credit')) 'credit': 'Credits',
      if (feed.reminders.any((r) => r.kind == 'annual_fee'))
        'annual_fee': 'Annual fees',
      if (feed.reminders.any((r) => r.kind == 'wallet' || r.kind == 'strategy'))
        'plan': 'Wallet & plan',
    };

    final maxHeight = math.min(720.0, MediaQuery.sizeOf(context).height * 0.86);

    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 660, maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          child: Column(
            key: const ValueKey('reminders-sheet'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Card reminders',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          feed.activeCount == 0
                              ? 'All caught up'
                              : '${feed.activeCount} active ${feed.activeCount == 1 ? 'reminder' : 'reminders'}',
                          key: const ValueKey('reminders-active-subtitle'),
                          style: TextStyle(color: product.muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('reminders-refresh'),
                    tooltip: 'Refresh reminders',
                    onPressed: _loading ? null : () => _refresh(),
                    icon: const Icon(Icons.refresh, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Close reminders',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
              if (availableFilters.length > 2) ...[
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final entry in availableFilters.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            key: ValueKey('reminders-filter-${entry.key}'),
                            label: Text(entry.value),
                            selected: _filter == entry.key,
                            onSelected: (_) =>
                                setState(() => _filter = entry.key),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: LinearProgressIndicator(),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: product.danger.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(color: product.danger, fontSize: 13),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    if (filteredActive.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: product.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: product.border),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 32,
                              color: product.success,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'No active reminders',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Recurring card credits, upcoming annual fee check-ins, and wallet nudges will appear here automatically.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: product.muted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      for (final item in filteredActive) ...[
                        _ReminderCard(
                          item: item,
                          busy: _busyKey == item.key,
                          onPrimaryAction: () => _handlePrimary(item),
                          onSnooze: item.canComplete
                              ? () => _setStatus(item, 'snoozed', snoozeDays: 7)
                              : null,
                          onDismiss: () => _setStatus(item, 'dismissed'),
                          onOpenRoute: item.route.isNotEmpty
                              ? () => _navigateToRoute(item.route)
                              : null,
                        ),
                        const SizedBox(height: 10),
                      ],
                    if (filteredHandled.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      InkWell(
                        key: const ValueKey('reminders-handled-toggle'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: () =>
                            setState(() => _showHandled = !_showHandled),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'HANDLED (${filteredHandled.length})',
                                  style: TextStyle(
                                    color: product.muted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: .4,
                                  ),
                                ),
                              ),
                              Icon(
                                _showHandled
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 20,
                                color: product.muted,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_showHandled)
                        for (final item in filteredHandled) ...[
                          _HandledReminderTile(
                            item: item,
                            busy: _busyKey == item.key,
                            onRestore: () => _setStatus(item, 'active'),
                          ),
                          const SizedBox(height: 8),
                        ],
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Reminders are calculated from your saved wallet and reviewed issuer terms. Enrollment and eligibility rules may apply; verify current terms with your card issuer.',
                      style: TextStyle(color: product.muted, fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _matchesFilter(ReminderItem item) {
    if (_filter == 'all') return true;
    if (_filter == 'plan') {
      return item.kind == 'wallet' || item.kind == 'strategy';
    }
    return item.kind == _filter;
  }

  void _handlePrimary(ReminderItem item) {
    switch (item.actionKind) {
      case 'mark_used':
        _setStatus(item, 'completed');
      case 'set_renewal_month':
        _pickRenewalMonth(item);
      case 'review_card':
      case 'open_strategy':
        _navigateToRoute(item.route);
      default:
        if (item.canComplete) {
          _setStatus(item, 'completed');
        } else if (item.route.isNotEmpty) {
          _navigateToRoute(item.route);
        }
    }
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.item,
    required this.busy,
    required this.onPrimaryAction,
    required this.onDismiss,
    this.onSnooze,
    this.onOpenRoute,
  });

  final ReminderItem item;
  final bool busy;
  final VoidCallback onPrimaryAction;
  final VoidCallback? onSnooze;
  final VoidCallback onDismiss;
  final VoidCallback? onOpenRoute;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    final accent = _accentColor(product, item);
    final subtitleParts = <String>[
      if (item.cardName.isNotEmpty) item.cardName,
      if (item.periodLabel.isNotEmpty) item.periodLabel,
    ];
    return Container(
      key: ValueKey('reminder-card-${item.key}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: product.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isHighPriority
              ? accent.withValues(alpha: .45)
              : product.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_iconFor(item), size: 19, color: accent),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              color: product.ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (item.isHighPriority) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: .14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              item.kind == 'annual_fee'
                                  ? 'Upcoming'
                                  : 'Ending soon',
                              style: TextStyle(
                                color: accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (subtitleParts.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitleParts.join(' · '),
                        style: TextStyle(
                          color: product.action,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.detail,
            style: TextStyle(color: product.muted, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              FilledButton.tonal(
                key: ValueKey('reminder-primary-${item.key}'),
                onPressed: busy ? null : onPrimaryAction,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(
                  item.actionLabel.isEmpty ? 'Done' : item.actionLabel,
                ),
              ),
              if (onSnooze != null)
                OutlinedButton(
                  key: ValueKey('reminder-snooze-${item.key}'),
                  onPressed: busy ? null : onSnooze,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: const Text('Snooze 7d'),
                ),
              TextButton(
                key: ValueKey('reminder-dismiss-${item.key}'),
                onPressed: busy ? null : onDismiss,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  foregroundColor: product.muted,
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text('Dismiss'),
              ),
              if (onOpenRoute != null &&
                  item.actionKind != 'review_card' &&
                  item.actionKind != 'open_strategy')
                TextButton(
                  onPressed: busy ? null : onOpenRoute,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: const Text('Open card'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HandledReminderTile extends StatelessWidget {
  const _HandledReminderTile({
    required this.item,
    required this.busy,
    required this.onRestore,
  });

  final ReminderItem item;
  final bool busy;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    final statusLabel = switch (item.status) {
      'completed' => 'Used',
      'snoozed' => 'Snoozed',
      _ => 'Dismissed',
    };
    return Container(
      key: ValueKey('reminder-handled-${item.key}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: product.surface.withValues(alpha: .65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: product.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    color: product.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration: item.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    statusLabel,
                    if (item.cardName.isNotEmpty) item.cardName,
                    if (item.periodLabel.isNotEmpty) item.periodLabel,
                  ].join(' · '),
                  style: TextStyle(color: product.muted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          TextButton(
            key: ValueKey('reminder-restore-${item.key}'),
            onPressed: busy ? null : onRestore,
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }
}

class _RenewalMonthDialog extends StatelessWidget {
  const _RenewalMonthDialog({required this.cardName});

  final String cardName;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Renewal month for $cardName'),
    content: SizedBox(
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pick the month your annual fee posts so RevoCred can remind you 30 days ahead.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var m = 1; m <= 12; m++)
                SizedBox(
                  width: 72,
                  child: OutlinedButton(
                    key: ValueKey('renewal-month-option-$m'),
                    onPressed: () => Navigator.of(context).pop(m),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text(_monthShortNames[m - 1]),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
    ],
  );
}

IconData _iconFor(ReminderItem item) => switch (item.kind) {
  'credit' => Icons.redeem_outlined,
  'annual_fee' => Icons.event_repeat_outlined,
  'wallet' => Icons.credit_card_outlined,
  'strategy' => Icons.route_outlined,
  _ => Icons.notifications_none,
};

Color _accentColor(ProductTheme product, ReminderItem item) =>
    switch (item.kind) {
      'credit' => product.warning,
      'annual_fee' => product.action,
      'wallet' => product.danger,
      'strategy' => product.success,
      _ => product.action,
    };
