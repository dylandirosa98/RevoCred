import 'package:flutter/material.dart';

/// Explicit colors render consistently on web, without depending on emoji fonts.
class CategoryIcon extends StatelessWidget {
  const CategoryIcon({required this.category, super.key});
  final String category;

  static (IconData, Color) designFor(String category) => switch (category) {
    'Dining' => (Icons.restaurant, const Color(0xffdd6540)),
    'Groceries' => (Icons.shopping_cart_outlined, const Color(0xff278650)),
    'Travel' => (Icons.flight, const Color(0xff297bc2)),
    'Gas' => (Icons.local_gas_station, const Color(0xffd6474b)),
    'Transit' => (Icons.tram, const Color(0xff218b97)),
    'Online shopping' => (Icons.shopping_bag_outlined, const Color(0xffac4fa1)),
    'Rent' => (Icons.home_outlined, const Color(0xff936345)),
    'Streaming' => (Icons.live_tv, const Color(0xff7353c6)),
    'Entertainment' => (Icons.local_activity_outlined, const Color(0xffc04781)),
    'Drugstores' => (Icons.local_pharmacy_outlined, const Color(0xff278d79)),
    'Wholesale clubs' => (Icons.warehouse_outlined, const Color(0xff467aba)),
    'Utilities' => (Icons.lightbulb_outline, const Color(0xffa77a10)),
    'Phone & internet' => (Icons.wifi, const Color(0xff426dc1)),
    'Home improvement' => (Icons.handyman_outlined, const Color(0xffb76b2f)),
    'Office supplies' => (Icons.folder_outlined, const Color(0xff727ca7)),
    _ => (Icons.credit_card, const Color(0xff6950ba)),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, color) = designFor(category);
    return ExcludeSemantics(
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .92),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 21),
      ),
    );
  }
}
