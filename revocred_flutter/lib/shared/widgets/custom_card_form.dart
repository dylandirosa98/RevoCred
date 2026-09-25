import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';
import 'content_layout.dart';

Future<CustomCardDraft?> showCustomCardSheet(BuildContext context) {
  return showModalBottomSheet<CustomCardDraft>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.product.canvas,
    builder: (context) => const _CustomCardForm(),
  );
}

class _CustomCardForm extends StatefulWidget {
  const _CustomCardForm();

  @override
  State<_CustomCardForm> createState() => _CustomCardFormState();
}

class _CustomCardFormState extends State<_CustomCardForm> {
  final name = TextEditingController();
  final issuer = TextEditingController();
  final fee = TextEditingController(text: '0');
  final bestUse = TextEditingController();
  final rates = {
    'other': TextEditingController(text: '1'),
    'dining': TextEditingController(text: '1'),
    'groceries': TextEditingController(text: '1'),
    'gas': TextEditingController(text: '1'),
    'travel': TextEditingController(text: '1'),
    'flights': TextEditingController(text: '1'),
    'hotels': TextEditingController(text: '1'),
  };
  String network = 'Visa';
  bool transferable = false;

  @override
  void dispose() {
    name.dispose();
    issuer.dispose();
    fee.dispose();
    bestUse.dispose();
    for (final controller in rates.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + padding),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add a card you already have',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Enter the terms you actually have. This is user-supplied, not issuer-verified.',
              style: TextStyle(color: context.product.muted),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('custom-card-name'),
              controller: name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Card name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: issuer,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Issuer'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: network,
              decoration: const InputDecoration(labelText: 'Network'),
              items: const [
                DropdownMenuItem(value: 'Visa', child: Text('Visa')),
                DropdownMenuItem(
                  value: 'Mastercard',
                  child: Text('Mastercard'),
                ),
                DropdownMenuItem(value: 'Amex', child: Text('Amex')),
                DropdownMenuItem(value: 'Discover', child: Text('Discover')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (value) => setState(() => network = value ?? 'Visa'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: fee,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Annual fee (dollars)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bestUse,
              decoration: const InputDecoration(labelText: 'Best use'),
            ),
            const SizedBox(height: 16),
            const SectionLabel('Reward rates (x)'),
            const SizedBox(height: 8),
            for (final entry in rates.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: entry.value,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(labelText: _rateLabel(entry.key)),
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Transferable points'),
              value: transferable,
              onChanged: (value) => setState(() => transferable = value),
            ),
            FilledButton(
              key: const ValueKey('custom-card-save'),
              onPressed: _submit,
              child: const Text('Add to wallet'),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final cardName = name.text.trim();
    final cardIssuer = issuer.text.trim();
    if (cardName.isEmpty || cardIssuer.isEmpty) return;
    Navigator.pop(
      context,
      CustomCardDraft(
        name: cardName,
        issuer: cardIssuer,
        network: network,
        annualFeeDollars: int.tryParse(fee.text) ?? 0,
        rates: rates.map(
          (key, value) => MapEntry(key, double.tryParse(value.text) ?? 1),
        ),
        transferablePoints: transferable,
        bestUse: bestUse.text.trim(),
      ),
    );
  }

  String _rateLabel(String key) => switch (key) {
    'other' => 'Catch-all / everything else',
    'dining' => 'Dining',
    'groceries' => 'Groceries',
    'gas' => 'Gas',
    'travel' => 'Travel',
    'flights' => 'Flights',
    'hotels' => 'Hotels',
    _ => key,
  };
}
