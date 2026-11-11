import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The REVO AI subscription as the store sells it.
class StoreOffer {
  const StoreOffer({required this.price, required this.handle});

  /// Localized price from the store, e.g. "$9.99".
  final String price;

  /// The store's package object, passed back to [SubscriptionService.purchase].
  final Object handle;
}

enum PurchaseStatus {
  purchased,
  restored,
  nothingToRestore,
  cancelled,
  pending,
  failed,
}

class PurchaseOutcome {
  const PurchaseOutcome(this.status, [this.message]);
  final PurchaseStatus status;
  final String? message;
}

/// In-app purchase of REVO AI. Only the iOS build with a RevenueCat key has
/// a working implementation; everywhere else (web, tests, unconfigured
/// builds) [available] is false and the app never offers a purchase.
abstract interface class SubscriptionService {
  bool get available;

  /// Sets the store's user to the signed-in account (null after sign-out).
  Future<void> identify(String? userId);

  /// The current offer, or null when the store has none to sell.
  Future<StoreOffer?> loadOffer();
  Future<PurchaseOutcome> purchase(StoreOffer offer);
  Future<PurchaseOutcome> restore();
}

class UnavailableSubscriptionService implements SubscriptionService {
  const UnavailableSubscriptionService();
  @override
  bool get available => false;
  @override
  Future<void> identify(String? userId) async {}
  @override
  Future<StoreOffer?> loadOffer() async => null;
  @override
  Future<PurchaseOutcome> purchase(StoreOffer offer) async =>
      const PurchaseOutcome(PurchaseStatus.failed, _unavailable);
  @override
  Future<PurchaseOutcome> restore() async =>
      const PurchaseOutcome(PurchaseStatus.failed, _unavailable);
}

const _unavailable = 'Subscriptions are not available in this version.';

final subscriptionServiceProvider = Provider<SubscriptionService>(
  (ref) => const UnavailableSubscriptionService(),
);

/// Apple's subscription management page (Settings › Apple ID › Subscriptions).
final appStoreSubscriptionsUrl = Uri.parse(
  'https://apps.apple.com/account/subscriptions',
);
