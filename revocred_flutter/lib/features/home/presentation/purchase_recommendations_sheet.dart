import 'package:flutter/material.dart';
import '../../../core/models/app_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/content_layout.dart';

class PurchaseRecommendationsSheet extends StatefulWidget {
  const PurchaseRecommendationsSheet({
    required this.categoryId,
    required this.categoryLabel,
    required this.wallet,
    required this.initialGuide,
    required this.load,
    super.key,
  });
  final String categoryId, categoryLabel;
  final List<CreditCard> wallet;
  final PurchaseGuide? initialGuide;
  final Future<PurchaseGuide> Function(String, bool) load;
  @override
  State<PurchaseRecommendationsSheet> createState() =>
      _PurchaseRecommendationsSheetState();
}

class _PurchaseRecommendationsSheetState
    extends State<PurchaseRecommendationsSheet> {
  PurchaseGuide? _guide;
  bool _loading = false;
  int _contextRevision = 0;
  String? _requestedMode;
  bool? _requestedCaps;
  String? _error;
  @override
  void initState() {
    super.initState();
    _guide = widget.initialGuide;
    if (_guide == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reload('general', true);
      });
    }
  }

  Future<void> _reload(String mode, bool caps) async {
    setState(() {
      _loading = true;
      _error = null;
      _requestedMode = mode;
      _requestedCaps = caps;
    });
    try {
      final result = await widget.load(mode, caps);
      if (mounted) setState(() => _guide = result);
    } catch (_) {
      if (mounted) {
        setState(() {
          _contextRevision++;
          _error =
              'Could not update the comparison. The previous purchase settings are still shown. Please retry.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    final g = _guide;
    final category = g
        ?.category(widget.categoryId)
        ?.forWallet(widget.wallet.map((c) => c.id).toSet());
    final options = category?.options ?? const <PurchaseOption>[];
    return FractionallySizedBox(
      heightFactor: .9,
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              key: const ValueKey('category-recommendations-list'),
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
              children: [
                Text(
                  'Best cards for ${widget.categoryLabel}',
                  key: const ValueKey('category-recommendations-title'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 7),
                Text(
                  'Compare cards already in your wallet—not cards to apply for.',
                  style: TextStyle(color: product.muted),
                ),
                const SizedBox(height: 12),
                if (widget.categoryId == 'travel' &&
                    g != null &&
                    g.travelModes.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                      'purchase-travel-mode-${g.travelMode}-$_contextRevision',
                    ),
                    initialValue: g.travelMode,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'How are you booking?',
                    ),
                    items: g.travelModes
                        .map(
                          (m) => DropdownMenuItem(
                            value: m.id,
                            child: Text(
                              m.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _loading
                        ? null
                        : (value) {
                            if (value != null) _reload(value, g.capsAvailable);
                          },
                  ),
                  const SizedBox(height: 10),
                ],
                CheckboxListTile(
                  key: const ValueKey('purchase-caps-available'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Spending caps still available',
                    style: TextStyle(fontSize: 13),
                  ),
                  subtitle: const Text(
                    'An assumption, not tracked spending. Turn off to exclude known capped bonus rules; unknown limits are not inferred.',
                    style: TextStyle(fontSize: 11),
                  ),
                  value: g?.capsAvailable ?? true,
                  onChanged: _loading
                      ? null
                      : (value) =>
                            _reload(g?.travelMode ?? 'general', value ?? false),
                ),
                if (_loading) const LinearProgressIndicator(),
                if (_error != null) ...[
                  Text(_error!, style: TextStyle(color: product.warning)),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => _reload(
                            _requestedMode ?? g?.travelMode ?? 'general',
                            _requestedCaps ?? g?.capsAvailable ?? true,
                          ),
                    child: const Text('Retry comparison'),
                  ),
                ],
                if (category != null) ...[
                  Text(
                    category.assumptions,
                    style: TextStyle(fontSize: 11, color: product.muted),
                  ),
                  const SizedBox(height: 12),
                  if (category.tied)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text('The highest known modeled return is tied.'),
                    ),
                ],
                if (options.isEmpty && !_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      'No supported earning rule is available for this purchase. We will not guess a card or assume that rent earns ordinary purchase rewards.',
                    ),
                  ),
                for (var i = 0; i < options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _tile(context, options[i], i + 1, false),
                  ),
                if (category?.conditional.isNotEmpty ?? false) ...[
                  const SizedBox(height: 12),
                  const SectionLabel('Conditional rates — not assumed'),
                  const SizedBox(height: 8),
                  const Text(
                    'These require a different booking channel, activation, selected category, promotion, timing or remaining cap. They are not the default recommendation.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  for (final o in category!.conditional)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _tile(context, o, null, true),
                    ),
                ],
                if (category?.unknown.isNotEmpty ?? false) ...[
                  const SizedBox(height: 10),
                  const SectionLabel('Unknown or unsupported terms'),
                  for (final unknown in category!.unknown)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        unknown,
                        style: TextStyle(fontSize: 12, color: product.muted),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    PurchaseOption option,
    int? rank,
    bool conditional,
  ) {
    final product = context.product;
    return Semantics(
      key: conditional ? null : ValueKey('category-card-${option.cardId}'),
      container: true,
      explicitChildNodes: true,
      label: '${rank == null ? 'Conditional' : '$rank.'} ${option.cardName}',
      child: AppPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${rank == null ? 'Conditional' : '$rank.'} ${option.cardName}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 5),
            Text(
              option.earnLabel,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: product.action,
              ),
            ),
            const SizedBox(height: 5),
            Text(option.reason, style: const TextStyle(fontSize: 12)),
            for (final condition in option.conditions)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(condition, style: const TextStyle(fontSize: 12)),
              ),
            if (option.source.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${option.source}${option.lastVerified.isEmpty ? '' : ' · source verified ${option.lastVerified}'}',
                  style: TextStyle(fontSize: 10, color: product.muted),
                ),
              ),
            if (!conditional)
              const Padding(
                padding: EdgeInsets.only(top: 7),
                child: Text(
                  'IN YOUR WALLET',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
