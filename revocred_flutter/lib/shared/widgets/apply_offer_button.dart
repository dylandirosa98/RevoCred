import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/affiliate_offer.dart';
import '../../core/state/affiliate_providers.dart';

class ApplyOfferButton extends ConsumerStatefulWidget {
  const ApplyOfferButton({required this.placement, super.key});
  final ApplyPlacement placement;

  @override
  ConsumerState<ApplyOfferButton> createState() => _ApplyOfferButtonState();
}

class _ApplyOfferButtonState extends ConsumerState<ApplyOfferButton> {
  bool opening = false;

  @override
  Widget build(BuildContext context) {
    final link = ref.watch(recommendedApplicationProvider(widget.placement));
    if (link == null || !link.isCurrent) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton.icon(
            onPressed: opening ? null : () => _open(link),
            icon: const Icon(Icons.open_in_new),
            label: Text('Apply for ${link.cardName}'),
          ),
          const SizedBox(height: 8),
          const Text(affiliateDisclosure, style: TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          const Text(
            'Opens an external site. Review current terms; approval is not guaranteed.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _open(ApplicationLink link) async {
    if (!link.isCurrent) {
      ref.invalidate(affiliateOffersProvider);
      return;
    }
    setState(() => opening = true);
    try {
      if (!await ref.read(applicationLauncherProvider)(link.uri)) {
        throw StateError('Cannot open browser');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open the application link. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }
}
