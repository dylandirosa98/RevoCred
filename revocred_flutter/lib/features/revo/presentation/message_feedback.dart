import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state/app_controller.dart';
import '../../../core/theme/app_theme.dart';

class MessageFeedback extends ConsumerStatefulWidget {
  const MessageFeedback({required this.messageId, super.key});
  final String messageId;
  @override
  ConsumerState<MessageFeedback> createState() => _MessageFeedbackState();
}

class _MessageFeedbackState extends ConsumerState<MessageFeedback> {
  String? selected;
  bool busy = false;
  Future<void> rate(String rating, {bool report = false}) async {
    String? reason;
    if (rating == 'down') {
      reason = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (context) => _FeedbackSheet(report: report),
      );
      if (reason == null || !mounted) return;
      // The server keeps at most 500 characters of reason and details.
      if (reason.length > 500) reason = reason.substring(0, 500);
    }
    setState(() => busy = true);
    try {
      await ref
          .read(appControllerProvider.notifier)
          .rateMessage(widget.messageId, rating, reason: reason);
      if (!mounted) return;
      setState(() => selected = rating);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Thanks for the feedback')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save feedback. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      IconButton(
        tooltip: 'Helpful',
        isSelected: selected == 'up',
        color: context.product.muted,
        selectedIcon: const Icon(Icons.thumb_up),
        icon: const Icon(Icons.thumb_up_outlined),
        onPressed: busy ? null : () => rate('up'),
      ),
      IconButton(
        tooltip: 'Not helpful',
        isSelected: selected == 'down',
        color: context.product.muted,
        selectedIcon: const Icon(Icons.thumb_down),
        icon: const Icon(Icons.thumb_down_outlined),
        onPressed: busy ? null : () => rate('down'),
      ),
      TextButton(
        onPressed: busy ? null : () => rate('down', report: true),
        child: const Text('Report'),
      ),
    ],
  );
}

/// Asks why an answer was unhelpful or should be reported.
class _FeedbackSheet extends StatefulWidget {
  const _FeedbackSheet({required this.report});
  final bool report;

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  final details = TextEditingController();
  var choice = 'Inaccurate';

  @override
  void dispose() {
    details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.report ? 'Report answer' : 'What could be better?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          for (final value in [
            'Inaccurate',
            'Not helpful',
            'Harmful or offensive',
            'Other',
          ])
            ListTile(
              title: Text(value),
              selected: choice == value,
              leading: Icon(
                choice == value
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              onTap: () => setState(() => choice = value),
            ),
          TextField(
            controller: details,
            maxLength: 500,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Details (optional)'),
          ),
          FilledButton(
            onPressed: () {
              final text = details.text.trim();
              Navigator.pop(context, text.isEmpty ? choice : '$choice: $text');
            },
            child: const Text('Submit feedback'),
          ),
        ],
      ),
    ),
  );
}
