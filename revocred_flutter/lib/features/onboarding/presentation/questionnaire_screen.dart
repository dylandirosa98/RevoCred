import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logic/card_search.dart';
import '../../../core/models/app_models.dart';
import '../../../core/state/app_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/card_terms_sheet.dart';
import '../../../shared/widgets/custom_card_form.dart';

class QuestionnaireScreen extends ConsumerStatefulWidget {
  const QuestionnaireScreen({super.key});
  @override
  ConsumerState<QuestionnaireScreen> createState() =>
      _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends ConsumerState<QuestionnaireScreen> {
  int step = 0;
  String lifeStage = '';
  final existingCardIds = <String>[];
  Timer? _searchDebounce;
  String feeTolerance = '';
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
  final spendControllers = {
    'dining': TextEditingController(),
    'groceries': TextEditingController(),
    'gas': TextEditingController(),
    'travel': TextEditingController(),
    'streaming': TextEditingController(),
    'other': TextEditingController(),
  };
  bool saving = false;

  static const totalSteps = 7;

  // A signed-out visitor's wallet is demo data, not cards they own. Only a real
  // account or the visitor's own preview may prefill or extend the card list.
  bool hasOwnWallet(AppState state) =>
      state.isAuthenticated || state.data?.isPersonalPreview == true;

  @override
  void initState() {
    super.initState();
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
          travelScope = saved.travelScope;
          creditTier = saved.creditTier;
          rewardsGoal = saved.rewardsGoal;
          for (final entry in spendControllers.entries) {
            final amount = saved.monthlySpend[entry.key];
            entry.value.text = amount?.toString() ?? '';
          }
          cardsConfirmed = true;
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
    0 => lifeStage.isNotEmpty,
    // A card added from search is an answer too, so it must satisfy this step.
    1 =>
      existingCardIds.isNotEmpty || addedFromIndex.isNotEmpty || cardsConfirmed,
    2 => feeTolerance.isNotEmpty,
    3 => travelScope.isNotEmpty,
    4 => creditTier.isNotEmpty,
    5 => true,
    _ => rewardsGoal.isNotEmpty,
  };

  @override
  void dispose() {
    _searchDebounce?.cancel();
    for (final controller in spendControllers.values) {
      controller.dispose();
    }
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
                '${step + 1}/$totalSteps',
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
                      child: _stepContent(data.catalog),
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
                        onPressed: saving ? null : () => setState(() => step--),
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
        hint:
            'All choices are for adults age 18 or older. Student cards require confirmed student status; issuer approval is never guaranteed.',
        child: _choices(
          value: lifeStage,
          onChanged: (value) => setState(() => lifeStage = value),
          options: const {
            'student': '18+ and currently a student',
            'adult-learning': '18+ and learning credit basics',
            'adult-building': 'Adult and building a foundation',
            'adult-established': 'Established and expanding rewards',
            'adult-optimizing': 'Experienced and optimizing',
          },
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
        title: 'What annual fee feels reasonable?',
        hint:
            'Select the highest tier you would consider when benefits justify it.',
        child: _choices(
          value: feeTolerance,
          onChanged: (value) => setState(() => feeTolerance = value),
          options: const {
            'none': r'$0 only',
            'low': r'Up to $100 per card',
            'mid': r'Up to $300 per card',
            'high': r'Up to $1,000 per card',
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
    // searchCards returns nothing for an empty query, so an unsearched list
    // must be built from the catalog itself or the step looks empty.
    final results = cardQuery.trim().isEmpty
        ? (catalog.toList()..sort((a, b) => a.name.compareTo(b.name)))
        : searchCards(catalog, cardQuery).take(8).toList();
    final searching = cardQuery.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          key: const ValueKey('no-existing-cards'),
          title: const Text('I do not have any credit cards'),
          value: cardsConfirmed && existingCardIds.isEmpty,
          onChanged: (value) => setState(() {
            cardsConfirmed = value == true;
            if (cardsConfirmed) existingCardIds.clear();
          }),
        ),
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
        const SizedBox(height: 14),
        if (existingCardIds.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: context.product.border),
                bottom: BorderSide(color: context.product.border),
              ),
            ),
            child: Column(
              children: existingCardIds.map((id) {
                final card = catalog.where((item) => item.id == id).firstOrNull;
                if (card == null) {
                  return ListTile(
                    dense: true,
                    title: Text(id),
                    trailing: IconButton(
                      onPressed: () =>
                          setState(() => existingCardIds.remove(id)),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  );
                }
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    card.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: IconButton(
                    tooltip: 'Remove ${card.name}',
                    onPressed: () => setState(() => existingCardIds.remove(id)),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                );
              }).toList(),
            ),
          ),
        if (existingCardIds.isNotEmpty) const SizedBox(height: 14),
        TextField(
          key: const ValueKey('questionnaire-card-search'),
          onChanged: (value) {
            setState(() => cardQuery = value);
            _searchDebounce?.cancel();
            _searchDebounce = Timer(
              const Duration(milliseconds: 350),
              _searchIndex,
            );
          },
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search cards or issuers',
          ),
        ),
        if (addedFromIndex.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Cards you added from search',
            style: TextStyle(
              color: context.product.action,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          for (final card in addedFromIndex)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                card.cardName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                card.includeTerms
                    ? 'Using the terms you entered'
                    : 'No terms - not used in your score',
              ),
              trailing: IconButton(
                tooltip: 'Remove ${card.cardName}',
                onPressed: () => setState(() => addedFromIndex.remove(card)),
                icon: const Icon(Icons.close, size: 18),
              ),
            ),
          const Text(
            'Cards added without terms are not used in your score, so your score may be less accurate than it could be.',
            style: TextStyle(fontSize: 12),
          ),
        ],
        if (cardQuery.trim().length >= 2) ...[
          const SizedBox(height: 12),
          Text(
            'Search all cards',
            style: TextStyle(
              color: context.product.action,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          if (indexSearching)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else if (indexError != null)
            Text(indexError!, style: const TextStyle(fontSize: 12))
          else if (indexResults.isEmpty)
            const Text(
              'No match in the card list. Use the search above to pick it, or add it with your own terms.',
              style: TextStyle(fontSize: 12),
            ),
          for (final card in indexResults)
            ListTile(
              key: ValueKey('index-result-${card.id}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(card.label),
              subtitle: Text(
                card.hasTerms
                    ? 'Earn rates on file (checked ${card.sourceCapturedOn})'
                    : 'Identity only - you will enter the terms',
              ),
              trailing: TextButton(
                onPressed:
                    addedFromIndex.any((item) => item.referenceId == card.id)
                    ? null
                    : () => _addFromIndex(card),
                child: const Text('Add'),
              ),
            ),
        ],
        const SizedBox(height: 12),
        if (!searching)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Showing every card. Search to narrow the list.',
              style: TextStyle(color: context.product.muted, fontSize: 12),
            ),
          ),
        for (final card in results)
          CheckboxListTile(
            key: ValueKey('existing-card-${card.id}'),
            value: existingCardIds.contains(card.id),
            onChanged: (_) => setState(
              () => existingCardIds.contains(card.id)
                  ? existingCardIds.remove(card.id)
                  : existingCardIds.add(card.id),
            ),
            title: Text(card.name),
            subtitle: Text('${card.issuer} | ${card.annualFee}'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.trailing,
          ),
      ],
    );
  }

  Widget _spendInputs() {
    final entries = spendControllers.entries.toList();
    return Column(
      children: [
        for (var index = 0; index < entries.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              key: ValueKey('spend-${entries[index].key}'),
              controller: entries[index].value,
              keyboardType: TextInputType.number,
              textInputAction: index == entries.length - 1
                  ? TextInputAction.done
                  : TextInputAction.next,
              onSubmitted: (_) => index == entries.length - 1
                  ? FocusScope.of(context).unfocus()
                  : FocusScope.of(context).nextFocus(),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 7,
              decoration: InputDecoration(
                labelText: _label(entries[index].key),
                prefixText: r'$ ',
              ),
            ),
          ),
      ],
    );
  }

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
    if (step == 5 &&
        spendControllers.values.any(
          (c) => (int.tryParse(c.text) ?? 0) > 1000000,
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(r'Enter at most $1,000,000 per monthly category.'),
        ),
      );
      return;
    }
    if (step < totalSteps - 1) {
      setState(() => step++);
      return;
    }
    setState(() => saving = true);
    final answers = QuestionnaireAnswers(
      lifeStage: lifeStage,
      existingCardIds: existingCardIds,
      feeTolerance: feeTolerance,
      travelScope: travelScope,
      creditTier: creditTier,
      monthlySpend: spendControllers.map(
        (key, value) => MapEntry(key, int.tryParse(value.text) ?? 0),
      ),
      rewardsGoal: rewardsGoal,
      addedCards: addedFromIndex,
    );
    try {
      await ref
          .read(appControllerProvider.notifier)
          .completeQuestionnaire(answers);
      if (mounted) {
        context.pushReplacement('/strategy-report');
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
