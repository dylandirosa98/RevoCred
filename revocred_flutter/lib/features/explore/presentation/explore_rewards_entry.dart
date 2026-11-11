import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logic/explore_rewards.dart';
import '../../../core/state/app_controller.dart';
import '../../../core/theme/app_theme.dart';

/// Home card that opens Explore Rewards with the member's own annual points.
class ExploreRewardsEntry extends ConsumerWidget {
  const ExploreRewardsEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = context.product;
    final state = ref.watch(appControllerProvider);
    final data = state.data;
    final wallet = data == null
        ? WalletEarning.example
        : walletEarning(
            data,
            ownWallet: isOwnWallet(data, authenticated: state.isAuthenticated),
          );
    final points = wallet.annualPoints.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return Material(
      color: product.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(product.radius),
        side: BorderSide(color: product.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('explore-rewards-entry'),
        onTap: () => context.push('/explore-rewards'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: product.action.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.travel_explore, color: product.action),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Explore Rewards',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      !wallet.personalized
                          ? 'See the flights and hotels credit card rewards could cover.'
                          : wallet.cashBack
                          ? 'Your cards earn about \$${wallet.annualDollars.round()} cash back a year. See the trips it could pay for.'
                          : 'Your cards earn about $points points a year. See the flights and hotels they could cover.',
                      style: TextStyle(color: product.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: product.muted),
            ],
          ),
        ),
      ),
    );
  }
}
