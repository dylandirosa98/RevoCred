import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logic/card_search.dart';
import '../../../core/models/app_models.dart';
import '../../../core/state/app_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/content_layout.dart';
import '../../../shared/widgets/credit_card_view.dart';
import '../../../shared/widgets/card_terms_sheet.dart';
import '../../../shared/widgets/issuer_mark.dart';
import '../../../shared/widgets/custom_card_form.dart';
import '../../../shared/widgets/send_revo_message.dart';

class CardsScreen extends ConsumerStatefulWidget {
  const CardsScreen({super.key});

  @override
  ConsumerState<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends ConsumerState<CardsScreen> {
  bool showPicker = false;
  bool _handledRouteSearch = false;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _searchDebounce;
  List<ReferenceCard> _indexResults = const [];
  bool _indexSearching = false;
  String? _indexError;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final data = state.data!;
    final product = context.product;
    final activeIds = data.wallet.map((card) => card.id).toSet();
    final available = data.catalog
        .where((card) => !activeIds.contains(card.id))
        .toList();
    final openSearch =
        GoRouterState.of(context).uri.queryParameters['search'] == '1';
    if (openSearch && !_handledRouteSearch) {
      _handledRouteSearch = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => showPicker = true);
        _searchFocus.requestFocus();
      });
    } else if (!openSearch) {
      _handledRouteSearch = false;
    }
    final query = _searchController.text.trim();
    final matches = query.isEmpty
        ? available.take(6).toList()
        : searchCards(available, query).take(12).toList();
    final catalogIds = data.catalog.map((card) => card.id).toSet();
    final catalogIdentities = data.catalog
        .map((card) => '${card.issuer}|${card.name}'.toLowerCase())
        .toSet();
    final indexOnly = query.length < 2
        ? const <ReferenceCard>[]
        : _indexResults
              .where((card) {
                final catalogID = card.catalogCardId;
                if (catalogID != null && catalogIds.contains(catalogID)) {
                  return false;
                }
                return !catalogIdentities.contains(
                  '${card.issuer}|${card.name}'.toLowerCase(),
                );
              })
              .take(12)
              .toList();
    return ContentLayout(
      children: [
        Row(
          children: [
            const Expanded(child: SectionLabel('Wallet')),
            StatusPill(
              label: '${data.wallet.length} ACTIVE',
              color: product.success,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Your card setup',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 7),
        Text(
          'Tap a partially visible card to make it preferred and see its best use.',
          style: TextStyle(color: product.muted),
        ),
        SizedBox(height: product.sectionGap),
        WalletCardStack(
          cards: data.wallet,
          onAskRevo: _askRevo,
          onRemove: _confirmRemove,
        ),
        SizedBox(height: product.sectionGap),
        OutlinedButton.icon(
          key: const ValueKey('add-card-button'),
          onPressed: () => setState(() => showPicker = !showPicker),
          icon: Icon(showPicker ? Icons.close : Icons.add),
          label: const Text('Add a card to wallet'),
        ),
        if (showPicker) ...[
          const SizedBox(height: 14),
          AppPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.search),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Find a card to add',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('wallet-card-search'),
                  controller: _searchController,
                  focusNode: _searchFocus,
                  textInputAction: TextInputAction.search,
                  onChanged: _searchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search by issuer or card name',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            key: const ValueKey('wallet-clear-search'),
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              _searchChanged('');
                              _searchFocus.requestFocus();
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                SectionLabel(
                  query.isEmpty ? 'Popular cards' : 'Matching cards',
                ),
                if (_indexSearching)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                const SizedBox(height: 8),
                if (available.isEmpty)
                  const Text('All catalog cards are already in your wallet.')
                else if (matches.isEmpty &&
                    indexOnly.isEmpty &&
                    !_indexSearching)
                  Text(
                    'No cards match “$query”. Check the spelling or add it manually.',
                    style: TextStyle(color: product.muted),
                  )
                else
                  for (final card in matches)
                    ListTile(
                      key: ValueKey('wallet-search-result-${card.id}'),
                      contentPadding: EdgeInsets.zero,
                      minVerticalPadding: 10,
                      leading: IssuerMark(issuer: card.issuer, size: 44),
                      title: Text(
                        card.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${card.issuer} | ${card.annualFee} | ${card.bestUse}',
                      ),
                      trailing: FilledButton(
                        onPressed: state.isLoading
                            ? null
                            : () async {
                                final added = await ref
                                    .read(appControllerProvider.notifier)
                                    .addCard(card.id);
                                if (!context.mounted) return;
                                if (added) {
                                  setState(() => showPicker = false);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ref.read(appControllerProvider).error ??
                                            'Could not add this card.',
                                      ),
                                    ),
                                  );
                                }
                              },
                        child: const Text('Add'),
                      ),
                    ),
                for (final card in indexOnly)
                  ListTile(
                    key: ValueKey('wallet-index-result-${card.id}'),
                    contentPadding: EdgeInsets.zero,
                    minVerticalPadding: 10,
                    leading: IssuerMark(issuer: card.issuer, size: 44),
                    title: Text(
                      card.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      card.hasTerms
                          ? '${card.issuer} | issuer terms on file'
                          : '${card.issuer} | add your card terms or skip scoring',
                    ),
                    trailing: FilledButton(
                      onPressed: state.isLoading
                          ? null
                          : () => _addReferenceCard(card),
                      child: const Text('Add'),
                    ),
                  ),
                if (_indexError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _indexError!,
                      style: TextStyle(color: product.muted, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('add-custom-card-button'),
                    onPressed: () async {
                      final draft = await showCustomCardSheet(context);
                      if (draft == null || !context.mounted) return;
                      final added = await ref
                          .read(appControllerProvider.notifier)
                          .addCustomCard(draft);
                      if (!context.mounted) return;
                      if (added) setState(() => showPicker = false);
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text("Can't find it? Add it manually"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmRemove(CreditCard card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove card?'),
        content: Text('Remove ${card.name} from this wallet?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final walletCardId = card.walletCardId ?? card.id;
    final removed = await ref
        .read(appControllerProvider.notifier)
        .removeCard(walletCardId);
    if (!mounted || removed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ref.read(appControllerProvider).error ??
              'Could not remove this card.',
        ),
      ),
    );
  }

  void _askRevo(String prompt) {
    sendRevoMessage(context, ref, prompt, openChat: true);
  }

  void _searchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _indexResults = const [];
        _indexSearching = false;
        _indexError = null;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), _searchIndex);
  }

  Future<void> _searchIndex() async {
    final query = _searchController.text.trim();
    if (query.length < 2) return;
    setState(() {
      _indexSearching = true;
      _indexError = null;
    });
    try {
      final results = await ref
          .read(appRepositoryProvider)
          .searchCardIndex(query);
      if (!mounted || _searchController.text.trim() != query) return;
      setState(() {
        _indexResults = results;
        _indexSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _indexSearching = false;
        _indexError =
            'The extended card list is unavailable. You can still add the card manually.';
      });
    }
  }

  Future<void> _addReferenceCard(ReferenceCard card) async {
    final choice = await showCardTermsSheet(context, card);
    if (choice == null || !mounted) return;
    final added = await ref
        .read(appControllerProvider.notifier)
        .addCustomCard(
          CustomCardDraft(
            name: card.name,
            issuer: card.issuer,
            network: _supportedNetwork(card.network),
            annualFeeDollars: choice.annualFeeCents ~/ 100,
            rates: choice.rewardRates,
            transferablePoints: choice.transferable,
            bestUse: choice.skipped
                ? 'Terms not supplied; excluded from scoring'
                : card.rewardsType,
            termsUnknown: choice.skipped,
          ),
        );
    if (!mounted) return;
    if (added) {
      setState(() => showPicker = false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(appControllerProvider).error ?? 'Could not add this card.',
          ),
        ),
      );
    }
  }

  String _supportedNetwork(String value) => switch (value.toLowerCase()) {
    'visa' => 'Visa',
    'mastercard' => 'Mastercard',
    'amex' || 'american express' => 'Amex',
    'discover' => 'Discover',
    _ => 'Other',
  };
}
