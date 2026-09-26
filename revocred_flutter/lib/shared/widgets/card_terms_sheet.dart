import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';

/// Result of the terms step: either the cardholder confirmed terms, or they
/// explicitly declined and the card must stay out of scoring.
class TermsChoice {
  const TermsChoice.accepted({
    required this.annualFeeCents,
    required this.rewardRates,
    this.transferable = false,
  }) : skipped = false;
  const TermsChoice.skipped()
    : skipped = true,
      annualFeeCents = 0,
      rewardRates = const {},
      transferable = false;

  final bool skipped;
  final int annualFeeCents;
  final Map<String, double> rewardRates;
  final bool transferable;
}

/// Asks for the terms RevoCred cannot know. Values published by the issuer are
/// pre-filled where we have them, and skipping is always allowed and always
/// explained.
Future<TermsChoice?> showCardTermsSheet(
  BuildContext context,
  ReferenceCard card,
) {
  return showModalBottomSheet<TermsChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.product.canvas,
    builder: (context) => _CardTermsForm(card: card),
  );
}

class _CardTermsForm extends StatefulWidget {
  const _CardTermsForm({required this.card});
  final ReferenceCard card;

  @override
  State<_CardTermsForm> createState() => _CardTermsFormState();
}

class _CardTermsFormState extends State<_CardTermsForm> {
  late final TextEditingController fee;
  late final Map<String, TextEditingController> rates;
  static const categories = <String>[
    'other',
    'dining',
    'groceries',
    'gas',
    'travel',
    'flights',
    'hotels',
  ];

  @override
  void initState() {
    super.initState();
    fee = TextEditingController(
      text: widget.card.annualFeeCents > 0
          ? (widget.card.annualFeeCents / 100).toStringAsFixed(0)
          : '0',
    );
    rates = {
      for (final category in categories)
        category: TextEditingController(
          text: _formatRate(widget.card.rewardRates[category] ?? 1),
        ),
    };
  }

  /// Whole-number rates read better as "3" than "3.0" in a form field.
  static String _formatRate(double value) =>
      value == value.roundToDouble() && value > 0
      ? value.toStringAsFixed(0)
      : value.toString();

  @override
  void dispose() {
    fee.dispose();
    for (final controller in rates.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    final sourced = widget.card.hasTerms;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Terms for ${widget.card.label}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              sourced
                  ? "We pre-filled the issuer's published earn rates. Check them against your own card, or skip."
                  : "We don't have verified rates for this card. Enter what your card actually earns, or skip.",
              style: TextStyle(color: product.muted),
            ),
            if (widget.card.sourceUrl.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Issuer list checked ${widget.card.sourceCapturedOn}. Fees and rewards change, so verify with the issuer.',
                style: TextStyle(color: product.muted, fontSize: 11),
              ),
            ],
            const SizedBox(height: 18),
            TextField(
              key: const ValueKey('index-card-fee'),
              controller: fee,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Annual fee in dollars',
                prefixText: r'$ ',
              ),
            ),
            const SizedBox(height: 14),
            const Text('Points or cash back per dollar'),
            const SizedBox(height: 8),
            for (final category in _CardTermsFormState.categories)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  key: ValueKey('index-card-rate-$category'),
                  controller: rates[category],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    labelText: category.replaceAll('_', ' '),
                    suffixText: 'x',
                  ),
                ),
              ),
            const SizedBox(height: 6),
            FilledButton(
              key: const ValueKey('index-card-save-terms'),
              onPressed: _accept,
              child: const Text('Use these terms'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const ValueKey('index-card-skip-terms'),
              onPressed: () =>
                  Navigator.pop(context, const TermsChoice.skipped()),
              child: const Text('Skip - do not use this card in my score'),
            ),
            const SizedBox(height: 8),
            Text(
              'Without terms RevoCred cannot include this card in your wallet score or value, so your score may be less accurate than it could be.',
              style: TextStyle(color: product.warning, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _accept() {
    final parsed = <String, double>{};
    for (final entry in rates.entries) {
      final value = double.tryParse(entry.value.text);
      if (value != null && value > 0) parsed[entry.key] = value;
    }
    final other = parsed['other'] ?? 1;
    parsed['other'] = other < 1 ? 1 : other;
    Navigator.pop(
      context,
      TermsChoice.accepted(
        annualFeeCents: (int.tryParse(fee.text) ?? 0) * 100,
        rewardRates: parsed,
      ),
    );
  }
}
