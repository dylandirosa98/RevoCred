import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logic/card_search.dart';
import '../../../core/models/app_models.dart';
import '../../../core/state/app_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/card_terms_sheet.dart';
import '../../../shared/widgets/custom_card_form.dart';
import '../../../shared/widgets/issuer_mark.dart';

class QuestionnaireScreen extends ConsumerStatefulWidget {
  const QuestionnaireScreen({super.key});
  @override
  ConsumerState<QuestionnaireScreen> createState() =>
      _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends ConsumerState<QuestionnaireScreen> {
  int step = 0;
  String lifeStage = '';
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final existingCardIds = <String>[];
  Timer? _searchDebounce;
  String feeTolerance = '';
  String idealCardCount = '';
  String travelScope = '';
  String creditTier = '';
  String rewardsGoal = '';
  bool cardsConfirmed = false;
  bool catalogReady = false;
  String? loadError;
  String cardQuery = '';
  final addedFromIndex = <OnboardingCardDraft>[];
  List<ReferenceCard> indexResults = const [];
  bool indexSearching = false;
  String? indexError;
  final spendValues = <String, int>{
    'dining': 0,
    'groceries': 0,
    'gas': 0,
    'travel': 0,
    'streaming': 0,
    'other': 0,
  };
  bool saving = false;

  static const totalSteps = 7;
  static const stepNames = [
    'About you',
    'Your cards',
    'Wallet size',
    'Travel',
    'Credit',
    'Spending',
    'Your goal',
  ];
  final _scroll = ScrollController();

  // Each step starts at the top. Without this a long step, such as the card
  // list, leaves the next question scrolled out of view.
  void _goToStep(int value) {
    setState(() => step = value);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  // A signed-out visitor's wallet is demo data, not cards they own. Only a real
  // account or the visitor's own preview may prefill or extend the card list.
  bool hasOwnWallet(AppState state) =>
      state.isAuthenticated || state.data?.isPersonalPreview == true;

  @override
  void initState() {
    super.initState();
    firstName.addListener(_onNameChanged);
    lastName.addListener(_onNameChanged);
    Future.microtask(_load);
  }

  Future<void> _load() async {
    try {
      final controller = ref.read(appControllerProvider.notifier);
      await controller.prepareQuestionnaire();
      if (!mounted) return;
      final state = ref.read(appControllerProvider);
      final saved = state.isAuthenticated
          ? state.data?.questionnaireAnswers
          : controller.draftStore.answers;
      setState(() {
        catalogReady = true;
        loadError = null;
        if (saved != null) {
          lifeStage = saved.lifeStage;
          feeTolerance = saved.feeTolerance;
          idealCardCount = const ['2-3', '3-4'].contains(saved.idealCardCount)
              ? '2-4'
              : saved.idealCardCount;
          travelScope = saved.travelScope;
          creditTier = saved.creditTier;
          rewardsGoal = saved.rewardsGoal;
          for (final category in spendValues.keys) {
            spendValues[category] = saved.monthlySpend[category] ?? 0;
          }
          cardsConfirmed = true;
        }
        final displayName = saved?.displayName.trim().isNotEmpty == true
            ? saved!.displayName.trim()
            : state.data?.profile.name.trim() ?? '';
        if (displayName.isNotEmpty) {
          final parts = displayName.split(RegExp(r'\s+'));
          firstName.text = parts.first;
          lastName.text = parts.length > 1 ? parts.skip(1).join(' ') : '';
        }
        if (hasOwnWallet(state) || saved != null) {
          existingCardIds.addAll(
            hasOwnWallet(state)
                ? state.data!.wallet.map((card) => card.id)
                : saved!.existingCardIds,
          );
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => loadError =
              'Could not load the current card catalog. Please retry.',
        );
      }
    }
  }

  bool get canContinue => switch (step) {
    0 =>
      firstName.text.trim().isNotEmpty &&
          lastName.text.trim().isNotEmpty &&
          lifeStage.isNotEmpty,
    // A card added from search is an answer too, so it must satisfy this step.
    1 =>
      existingCardIds.isNotEmpty || addedFromIndex.isNotEmpty || cardsConfirmed,
    2 => idealCardCount.isNotEmpty,
    3 => travelScope.isNotEmpty,
    4 => creditTier.isNotEmpty,
    5 => true,
    _ => rewardsGoal.isNotEmpty,
  };

  void _onNameChanged() {
    if (mounted && step == 0) setState(() {});
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scroll.dispose();
    firstName.dispose();
    lastName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appControllerProvider).data!;
    if (!catalogReady) {
      return Scaffold(
        appBar: AppBar(title: const Text('Build your strategy')),
        body: Center(
          child: loadError == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(loadError!),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          MediaQuery.sizeOf(context).width < 360
              ? 'Your strategy'
              : 'Strategy questionnaire',
        ),
        backgroundColor: context.product.canvas,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Center(
              child: Text(
                'Step ${step + 1} of $totalSteps',
                style: TextStyle(color: context.product.muted),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: (step + 1) / totalSteps,
                  minHeight: 6,
                  backgroundColor: context.product.border,
                  color: context.product.action,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(22),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      reverseDuration: const Duration(milliseconds: 160),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      // A leaving step must not swallow a tap meant for the
                      // arriving one, or the answer is silently lost and the
                      // step stays blocked.
                      transitionBuilder: (child, animation) => IgnorePointer(
                        ignoring: animation.status == AnimationStatus.reverse,
                        child: FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(.025, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey('step-$step'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              stepNames[step].toUpperCase(),
                              style: TextStyle(
                                color: context.product.action,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _stepContent(data.catalog),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              decoration: BoxDecoration(
                color: context.product.surface,
                border: Border(top: BorderSide(color: context.product.border)),
              ),
              child: Row(
                children: [
                  if (step > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: saving ? null : () => _goToStep(step - 1),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  if (step > 0) const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      key: const ValueKey('questionnaire-next'),
                      onPressed: saving || !canContinue ? null : _next,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: Text(
                        saving
                            ? 'Calculating...'
                            : step == totalSteps - 1
                            ? 'Build my strategy'
                            : 'Next',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepContent(List<CreditCard> catalog) {
    return switch (step) {
      0 => _Question(
        key: const ValueKey('question-life-stage'),
        title: 'What adult life stage fits best?',
        hint: 'Tell us who the strategy is for, then choose the closest fit.',
        child: Column(
          children: [
            _nameInputs(),
            const SizedBox(height: 26),
            _choices(
              value: lifeStage,
              onChanged: (value) => setState(() => lifeStage = value),
              options: const {
                'adult-learning': '18+ and learning credit basics',
                'adult-building': 'Adult and building a foundation',
                'adult-established': 'Established and expanding rewards',
                'adult-optimizing': 'Experienced and optimizing',
              },
            ),
          ],
        ),
      ),
      1 => _Question(
        key: const ValueKey('question-existing-cards'),
        title: 'Which cards do you already have?',
        hint:
            'Search any card you already have, or confirm you have none. Cards you add from search can carry your own terms; we never recommend applying for a card you already hold.',
        child: _cardSelector(_ownedCardOptions(catalog)),
      ),
      2 => _Question(
        key: const ValueKey('question-fees'),
        title: 'How many cards would you like to ideally stay within?',
        hint:
            'Choose a comfortable long-term wallet size. This helps keep your roadmap focused and manageable.',
        child: _choices(
          value: idealCardCount,
          onChanged: (value) => setState(() => idealCardCount = value),
          options: const {
            '1-2': '1–2 cards',
            '2-4': '2–4 cards',
            '4+': '4+ cards',
          },
        ),
      ),
      3 => _Question(
        key: const ValueKey('question-travel'),
        title: 'Where do you plan to travel?',
        hint: 'Choose no travel focus if everyday value matters more.',
        child: _choices(
          value: travelScope,
          onChanged: (value) => setState(() => travelScope = value),
          options: const {
            'none': 'No travel focus',
            'domestic': 'Mostly domestic',
            'international': 'Mostly international',
            'both': 'Domestic and international',
          },
        ),
      ),
      4 => _Question(
        key: const ValueKey('question-credit'),
        title: 'Which self-reported credit tier is closest?',
        hint: 'This is not a credit check and does not predict approval.',
        child: _choices(
          value: creditTier,
          onChanged: (value) => setState(() => creditTier = value),
          options: const {
            'building': 'Building or rebuilding',
            'fair': 'Fair',
            'good': 'Good',
            'excellent': 'Excellent',
          },
        ),
      ),
      5 => _Question(
        key: const ValueKey('question-spend'),
        title: 'Estimate your monthly spending',
        hint:
            'Use your normal monthly budget, with each purchase in one category. Blank means zero. Housing is excluded from rewards estimates. Your answers are sent to the API to calculate a plan; in demo mode they stay on this device.',
        child: _spendInputs(),
      ),
      _ => _Question(
        key: const ValueKey('question-goal'),
        title: 'What is your primary rewards goal?',
        hint:
            'Choose how you want to use rewards. The server compares sourced card terms, values points conservatively at one cent, and subtracts annual fees. No credit check or guaranteed approval.',
        child: _choices(
          value: rewardsGoal,
          onChanged: (value) => setState(() => rewardsGoal = value),
          options: const {
            'travel': 'Flexible travel points',
            'cash_back': 'Simple cash back',
          },
        ),
      ),
    };
  }

  Widget _choices({
    required String value,
    required ValueChanged<String> onChanged,
    required Map<String, String> options,
  }) {
    final product = context.product;
    final choiceRadius = switch (product.panelTreatment) {
      PanelTreatment.flat => product.radius,
      PanelTreatment.paper => 2.0,
      PanelTreatment.technical => 0.0,
      PanelTreatment.wallet => 14.0,
      PanelTreatment.outlined => 15.0,
    };
    final strongSelection =
        product.panelTreatment == PanelTreatment.flat ||
        product.panelTreatment == PanelTreatment.wallet;
    return Column(
      children: [
        for (final option in options.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Semantics(
              button: true,
              selected: value == option.key,
              inMutuallyExclusiveGroup: true,
              label: option.value,
              child: InkWell(
                onTap: () => onChanged(option.key),
                borderRadius: BorderRadius.circular(choiceRadius),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    color: value == option.key
                        ? strongSelection
                              ? product.action
                              : product.subtle
                        : product.surface,
                    borderRadius: BorderRadius.circular(choiceRadius),
                    border: Border.all(
                      color: value == option.key
                          ? product.action
                          : product.border,
                      width: value == option.key ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        value == option.key
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: value == option.key
                            ? strongSelection
                                  ? product.actionInk
                                  : product.action
                            : product.muted,
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Text(
                          option.value,
                          style: TextStyle(
                            color: value == option.key && strongSelection
                                ? product.actionInk
                                : product.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // The catalog always wins a name collision so a selectable row always carries
  // a real catalog ID. A wallet adds only cards the catalog does not list (a
  // user's own custom card), and only for an account or preview that owns them.
  List<CreditCard> _ownedCardOptions(List<CreditCard> catalog) {
    final options = <CreditCard>[...catalog];
    final seen = <String>{
      for (final card in catalog) '${card.name}|${card.issuer}'.toLowerCase(),
    };
    if (!hasOwnWallet(ref.read(appControllerProvider))) return options;
    for (final card in ref.read(appControllerProvider).data!.wallet) {
      final key = '${card.name}|${card.issuer}'.toLowerCase();
      if (seen.add(key)) options.add(card);
    }
    return options;
  }

  Widget _cardSelector(List<CreditCard> catalog) {
    final product = context.product;
    final query = cardQuery.trim();
    final searching = query.isNotEmpty;
    final catalogMatches = searching
        ? searchCards(catalog, query).take(8).toList()
        : (catalog.toList()..sort((a, b) => a.name.compareTo(b.name)));
    // The index also lists every catalog card. Those resolve to the catalog
    // row so a card is never shown twice or entered with duplicate terms.
    String identity(String issuer, String name) =>
        '$issuer|$name'.toLowerCase();
    final catalogById = {for (final card in catalog) card.id: card};
    final catalogByIdentity = {
      for (final card in catalog) identity(card.issuer, card.name): card,
    };
    CreditCard? catalogFor(ReferenceCard card) {
      final id = card.catalogCardId;
      if (id != null && id.isNotEmpty && catalogById[id] != null) {
        return catalogById[id];
      }
      return catalogByIdentity[identity(card.issuer, card.name)];
    }

    final shownCatalog = {for (final card in catalogMatches) card.id};
    final extraCatalog = <CreditCard>[];
    final indexOnly = <ReferenceCard>[];
    if (query.length >= 2) {
      for (final card in indexResults) {
        final resolved = catalogFor(card);
        if (resolved == null) {
          indexOnly.add(card);
        } else if (shownCatalog.add(resolved.id)) {
          extraCatalog.add(resolved);
        }
      }
    }
    final catalogRows = [...catalogMatches, ...extraCatalog];
    final selectedCatalog = [
      for (final id in existingCardIds)
        catalogById[id] ??
            _ownedCardOptions(catalog).where((c) => c.id == id).firstOrNull,
    ].whereType<CreditCard>().toList();
    final selectedCount = selectedCatalog.length + addedFromIndex.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selectedCount > 0) ...[
          Text(
            selectedCount == 1 ? 'Your card' : 'Your cards ($selectedCount)',
            style: TextStyle(
              color: product.action,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          for (final card in selectedCatalog)
            _SelectedCardRow(
              key: ValueKey('selected-card-${card.id}'),
              issuer: card.issuer,
              name: card.name,
              detail: 'Earn rates on file',
              onRemove: () => setState(() => existingCardIds.remove(card.id)),
            ),
          for (final card in addedFromIndex)
            _SelectedCardRow(
              key: ValueKey('selected-index-${card.referenceId}'),
              issuer: card.issuer,
              name: card.cardName,
              detail: card.includeTerms
                  ? 'Using the terms you entered'
                  : 'No terms - not used in your score',
              onRemove: () => setState(() => addedFromIndex.remove(card)),
            ),
          if (addedFromIndex.any((card) => !card.includeTerms))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Cards added without terms are not used in your score, so your score may be less accurate than it could be.',
                style: TextStyle(fontSize: 12, color: product.muted),
              ),
            ),
          const SizedBox(height: 16),
        ],
        TextField(
          key: const ValueKey('questionnaire-card-search'),
          onChanged: (value) {
            setState(() => cardQuery = value);
            _searchDebounce?.cancel();
            _searchDebounce = Timer(
              const Duration(milliseconds: 300),
              _searchIndex,
            );
          },
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search by card or bank, e.g. Discover or Sapphire',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                searching ? 'Matching cards' : 'Popular cards',
                style: TextStyle(
                  color: product.action,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (indexSearching)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        if (!searching)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Not listed? Search above: the full list covers Chase, Capital One, Discover, Citi, Wells Fargo, U.S. Bank and more.',
              style: TextStyle(color: product.muted, fontSize: 12),
            ),
          ),
        const SizedBox(height: 4),
        for (final card in catalogRows)
          CheckboxListTile(
            key: ValueKey('existing-card-${card.id}'),
            value: existingCardIds.contains(card.id),
            onChanged: (_) => setState(() {
              cardsConfirmed = false;
              existingCardIds.contains(card.id)
                  ? existingCardIds.remove(card.id)
                  : existingCardIds.add(card.id);
            }),
            secondary: IssuerMark(issuer: card.issuer, size: 36),
            title: Text(card.name),
            subtitle: Text('${card.issuer} | ${card.annualFee}'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.trailing,
          ),
        for (final card in indexOnly)
          ListTile(
            key: ValueKey('index-result-${card.id}'),
            contentPadding: EdgeInsets.zero,
            leading: IssuerMark(issuer: card.issuer, size: 36),
            title: Text(card.label),
            subtitle: Text(
              card.hasTerms
                  ? 'Earn rates on file (checked ${card.sourceCapturedOn})'
                  : 'Identity only - you will enter the terms',
            ),
            trailing: addedFromIndex.any((item) => item.referenceId == card.id)
                ? Icon(Icons.check_circle, color: product.success)
                : TextButton(
                    onPressed: () => _addFromIndex(card),
                    child: const Text('Add'),
                  ),
          ),
        if (indexError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(indexError!, style: const TextStyle(fontSize: 12)),
          )
        else if (query.length >= 2 &&
            !indexSearching &&
            catalogRows.isEmpty &&
            indexOnly.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No card matches "$query". Try the bank name, like Discover or Citi, or a shorter part of the card name.',
              style: TextStyle(fontSize: 13, color: product.muted),
            ),
          ),
        const SizedBox(height: 10),
        if (ref.read(appControllerProvider).isAuthenticated)
          OutlinedButton.icon(
            key: const ValueKey('questionnaire-add-custom-card'),
            onPressed: () async {
              final draft = await showCustomCardSheet(context);
              if (draft == null || !mounted) return;
              final added = await ref
                  .read(appControllerProvider.notifier)
                  .addCustomCard(draft);
              if (!added || !mounted) return;
              final data = ref.read(appControllerProvider).data;
              final created = data?.wallet
                  .where((card) => card.name == draft.name)
                  .firstOrNull;
              if (created != null) {
                setState(() => existingCardIds.add(created.id));
              }
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Add a card that is not listed'),
          ),
        const Divider(height: 28),
        CheckboxListTile(
          key: const ValueKey('no-existing-cards'),
          title: const Text('I do not have any credit cards'),
          value: cardsConfirmed && selectedCount == 0,
          contentPadding: EdgeInsets.zero,
          onChanged: (value) => setState(() {
            cardsConfirmed = value == true;
            if (cardsConfirmed) {
              existingCardIds.clear();
              addedFromIndex.clear();
            }
          }),
        ),
      ],
    );
  }

  Widget _spendInputs() {
    final entries = spendValues.entries.toList();
    final total = spendValues.values.fold<int>(0, (sum, value) => sum + value);
    return Column(
      children: [
        for (var index = 0; index < entries.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: _SpendSlider(
              key: ValueKey('spend-${entries[index].key}'),
              label: _label(entries[index].key),
              value: entries[index].value,
              onChanged: (value) =>
                  setState(() => spendValues[entries[index].key] = value),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            total == 0
                ? 'Leave a category at \$0 if you do not spend there.'
                : 'About \$${_formatDollars(total)} a month, or \$${_formatDollars(total * 12)} a year.',
            style: TextStyle(
              color: context.product.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDollars(int value) => value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );

  Future<void> _searchIndex() async {
    final query = cardQuery.trim();
    if (query.length < 2) {
      setState(() {
        indexResults = const [];
        indexError = null;
        indexSearching = false;
      });
      return;
    }
    setState(() {
      indexSearching = true;
      indexError = null;
    });
    try {
      final results = await ref
          .read(appRepositoryProvider)
          .searchCardIndex(query);
      if (!mounted || cardQuery.trim() != query) return;
      setState(() {
        indexResults = results;
        indexSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        indexSearching = false;
        indexError =
            'Card search is unavailable. You can still add a card with your own terms.';
      });
    }
  }

  Future<void> _addFromIndex(ReferenceCard card) async {
    final choice = await showCardTermsSheet(context, card);
    if (choice == null || !mounted) return;
    setState(() {
      addedFromIndex.add(
        OnboardingCardDraft.fromReference(
          card,
          includeTerms: !choice.skipped,
          annualFeeCents: choice.annualFeeCents,
          rewardRates: choice.rewardRates,
        ),
      );
    });
  }

  Future<void> _next() async {
    if (!canContinue) return;
    if (step < totalSteps - 1) {
      _goToStep(step + 1);
      return;
    }
    setState(() => saving = true);
    final answers = QuestionnaireAnswers(
      lifeStage: lifeStage,
      existingCardIds: existingCardIds,
      // The current recommendation engine still requires a fee threshold. Use
      // a conservative default until fee preference is inferred from card
      // details instead of asking an extra onboarding question.
      feeTolerance: feeTolerance.isEmpty ? 'low' : feeTolerance,
      idealCardCount: idealCardCount,
      travelScope: travelScope,
      creditTier: creditTier,
      monthlySpend: Map.unmodifiable(spendValues),
      rewardsGoal: rewardsGoal,
      addedCards: addedFromIndex,
      displayName: '${firstName.text.trim()} ${lastName.text.trim()}'.trim(),
    );
    try {
      await ref
          .read(appControllerProvider.notifier)
          .completeQuestionnaire(answers);
      if (mounted) {
        context.go('/strategy-report');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save preferences: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  String _label(String value) => switch (value) {
    'dining' => 'Dining and takeout',
    'groceries' => 'Groceries',
    'gas' => 'Gas and fuel',
    'travel' => 'Travel',
    'streaming' => 'Streaming subscriptions',
    _ => 'Other everyday spend',
  };

  Widget _nameInputs() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: TextField(
          key: const ValueKey('onboarding-first-name'),
          controller: firstName,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.givenName],
          maxLength: 30,
          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          decoration: const InputDecoration(
            labelText: 'First name',
            counterText: '',
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: TextField(
          key: const ValueKey('onboarding-last-name'),
          controller: lastName,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.familyName],
          maxLength: 30,
          decoration: const InputDecoration(
            labelText: 'Last name',
            counterText: '',
          ),
        ),
      ),
    ],
  );
}

class _SpendSlider extends StatelessWidget {
  const _SpendSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  static const max = 5000;
  static const step = 50;
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    return Semantics(
      label: '$label monthly spending',
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          color: product.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: product.border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: product.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                AnimatedContainer(
                  key: const ValueKey('spend-value'),
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: product.subtle,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    value == max ? r'$5,000+' : '\$${_money(value)}',
                    style: TextStyle(
                      color: product.action,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: product.action,
                inactiveTrackColor: product.border,
                thumbColor: product.action,
                overlayColor: product.action.withValues(alpha: .14),
                trackHeight: 4,
                tickMarkShape: const RoundSliderTickMarkShape(
                  tickMarkRadius: 1.15,
                ),
                activeTickMarkColor: product.actionInk.withValues(alpha: .7),
                inactiveTickMarkColor: product.muted.withValues(alpha: .45),
                valueIndicatorColor: product.action,
                valueIndicatorTextStyle: TextStyle(
                  color: product.actionInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: Slider(
                value: value.toDouble(),
                min: 0,
                max: max.toDouble(),
                divisions: max ~/ step,
                label: value == max ? r'$5,000+' : '\$${_money(value)}',
                semanticFormatterCallback: (next) {
                  final snapped = (next / step).round() * step;
                  return snapped == max
                      ? r'$5,000 or more per month'
                      : '\$${_money(snapped)} per month';
                },
                onChanged: (next) => onChanged((next / step).round() * step),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  r'$0',
                  style: TextStyle(color: product.muted, fontSize: 11),
                ),
                Text(
                  r'$2,500',
                  style: TextStyle(color: product.muted, fontSize: 11),
                ),
                Text(
                  r'$5,000+',
                  style: TextStyle(color: product.muted, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _money(int amount) => amount.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
}

class _Question extends StatelessWidget {
  const _Question({
    required this.title,
    required this.hint,
    required this.child,
    super.key,
  });
  final String title;
  final String hint;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      Text(hint, style: TextStyle(color: context.product.muted, fontSize: 15)),
      const SizedBox(height: 25),
      child,
    ],
  );
}

class _SelectedCardRow extends StatelessWidget {
  const _SelectedCardRow({
    required this.issuer,
    required this.name,
    required this.detail,
    required this.onRemove,
    super.key,
  });

  final String issuer;
  final String name;
  final String detail;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    leading: IssuerMark(issuer: issuer, size: 32),
    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(detail),
    trailing: IconButton(
      tooltip: 'Remove $name',
      onPressed: onRemove,
      icon: const Icon(Icons.close, size: 18),
    ),
  );
}
