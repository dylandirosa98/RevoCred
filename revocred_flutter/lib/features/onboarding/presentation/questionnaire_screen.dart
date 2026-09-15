import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logic/card_search.dart';
import '../../../core/models/app_models.dart';
import '../../../core/state/app_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/content_layout.dart';

class QuestionnaireScreen extends ConsumerStatefulWidget {
  const QuestionnaireScreen({super.key});
  @override
  ConsumerState<QuestionnaireScreen> createState() =>
      _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends ConsumerState<QuestionnaireScreen> {
  int step = 0;
  String lifeStage = 'adult-building';
  final existingCardIds = <String>[];
  String feeTolerance = 'low';
  String travelScope = 'both';
  String creditTier = 'good';
  String rewardsGoal = 'travel';
  String cardQuery = '';
  final spendControllers = {
    'rent': TextEditingController(),
    'food': TextEditingController(),
    'travel': TextEditingController(),
    'everyday': TextEditingController(),
  };
  bool saving = false;
  DemoRecommendation? result;

  static const totalSteps = 7;

  @override
  void dispose() {
    for (final controller in spendControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appControllerProvider).data!;
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
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(.025, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
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
                  if (step > 0 && result == null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: saving ? null : () => setState(() => step--),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  if (step > 0 && result == null) const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      key: const ValueKey('questionnaire-next'),
                      onPressed: saving
                          ? null
                          : result != null
                          ? _finish
                          : _next,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: Text(
                        saving
                            ? 'Calculating...'
                            : result != null
                            ? 'Return to profile'
                            : step == totalSteps - 1
                            ? 'Calculate recommendation'
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
    if (result != null) {
      return _ResultView(
        result: result!,
        isMock: ref.read(appConfigProvider).useMocks,
      );
    }
    return switch (step) {
      0 => _Question(
        key: const ValueKey('question-life-stage'),
        title: 'What adult life stage fits best?',
        hint:
            'All choices are for adults age 18 or older. This is used only to frame the demo strategy.',
        child: _choices(
          value: lifeStage,
          onChanged: (value) => setState(() => lifeStage = value),
          options: const {
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
            'Search and select any existing cards. You can continue with none.',
        child: _cardSelector(catalog),
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
            'low': r'Up to about $95',
            'mid': r'Up to about $250',
            'high': r'$250+ premium cards',
          },
        ),
      ),
      3 => _Question(
        key: const ValueKey('question-travel'),
        title: 'What travel scope should REVO consider?',
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
            'Enter rough dollar amounts. Values stay on this device in demo mode.',
        child: _spendInputs(),
      ),
      _ => _Question(
        key: const ValueKey('question-goal'),
        title: 'What is your primary rewards goal?',
        hint:
            'The local v1 formula values travel rewards at 2.5% and cash back at 2.0% of entered spend.',
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

  Widget _cardSelector(List<CreditCard> catalog) {
    final results = searchCards(catalog, cardQuery).take(8);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                final card = catalog.where((item) => item.id == id).first;
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
          onChanged: (value) => setState(() => cardQuery = value),
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search cards or issuers',
          ),
        ),
        const SizedBox(height: 12),
        for (final card in results)
          CheckboxListTile(
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
              decoration: InputDecoration(
                labelText: _label(entries[index].key),
                prefixText: r'$ ',
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _next() async {
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
    );
    try {
      final recommendation = await ref
          .read(appControllerProvider.notifier)
          .completeQuestionnaire(answers);
      if (mounted) {
        setState(() => result = recommendation);
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

  void _finish() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/profile');
    }
  }

  String _label(String value) => switch (value) {
    'rent' => 'Rent or housing',
    'food' => 'Dining and groceries',
    'travel' => 'Travel',
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

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result, required this.isMock});
  final DemoRecommendation result;
  final bool isMock;
  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('questionnaire-result'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Icon(Icons.auto_awesome, size: 52, color: context.product.success),
      const SizedBox(height: 18),
      Text(
        'Your local v1 result',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 8),
      Text(
        isMock
            ? 'Demo mode calculated this on device. Your answers were not sent anywhere.'
            : 'Preferences were sent to the configured API. The v1 estimate below was calculated locally.',
        textAlign: TextAlign.center,
        style: TextStyle(color: context.product.warning),
      ),
      const SizedBox(height: 24),
      AppPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Recommended focus'),
            const SizedBox(height: 9),
            Text(
              result.cardName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Estimated yearly rewards value: \$${result.estimatedYearlyValue}',
              style: TextStyle(
                color: context.product.success,
                fontWeight: FontWeight.w700,
              ),
            ),
            Divider(height: 28, color: context.product.border),
            for (final reason in result.reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('- $reason'),
              ),
            const SizedBox(height: 8),
            const SectionLabel('Transparent formula'),
            const SizedBox(height: 6),
            Text(
              result.formula,
              style: TextStyle(color: context.product.muted),
            ),
            const SizedBox(height: 12),
            Text(
              'This estimate excludes welcome offers, annual fees, caps, interest, taxes, and changing issuer terms.',
              style: TextStyle(color: context.product.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    ],
  );
}
