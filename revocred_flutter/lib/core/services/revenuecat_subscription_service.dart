import 'dart:async';

import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'subscriptions.dart';

/// RevenueCat-backed App Store subscription. The RevenueCat app user id is
/// always the Supabase user id, so the server's webhook can match purchases
/// to accounts; nothing is configured until someone signs in, and purchases
/// are refused while no account is identified.
class RevenueCatSubscriptionService implements SubscriptionService {
  RevenueCatSubscriptionService({
    required this.apiKey,
    required this.currentUserId,
    this.entitlementId = 'revo_ai',
  });

  final String apiKey;
  final String entitlementId;

  /// The signed-in Supabase user id, read at purchase time.
  final String? Function() currentUserId;

  bool _configured = false;
  String? _identified;
  Future<void> _queue = Future.value();

  @override
  bool get available => true;

  @override
  Future<void> identify(String? userId) {
    // Auth events can arrive quickly; apply them in order.
    final next = _queue.then((_) => _identify(userId)).catchError((_) {});
    _queue = next;
    return next;
  }

  Future<void> _identify(String? userId) async {
    if (userId == null) {
      if (_configured && _identified != null) {
        await Purchases.logOut();
        _identified = null;
      }
      return;
    }
    if (!_configured) {
      await Purchases.configure(
        PurchasesConfiguration(apiKey)..appUserID = userId,
      );
      _configured = true;
    } else if (_identified != userId) {
      await Purchases.logIn(userId);
    }
    _identified = userId;
  }

  Future<bool> _ready() async {
    final userId = currentUserId();
    if (userId == null) return false;
    await identify(userId);
    return _configured && _identified == userId && currentUserId() == userId;
  }

  @override
  Future<StoreOffer?> loadOffer() async {
    if (!await _ready()) return null;
    final offering = (await Purchases.getOfferings()).current;
    final package = offering?.monthly;
    if (package == null ||
        package.storeProduct.identifier != 'com.revocred.app.revo_ai_monthly') {
      return null;
    }
    return StoreOffer(price: package.storeProduct.priceString, handle: package);
  }

  @override
  Future<PurchaseOutcome> purchase(StoreOffer offer) async {
    if (!await _ready()) {
      return const PurchaseOutcome(
        PurchaseStatus.failed,
        'Sign in to subscribe.',
      );
    }
    try {
      final result = await Purchases.purchase(
        PurchaseParams.package(offer.handle as Package),
      );
      final active = result.customerInfo.entitlements.active.containsKey(
        entitlementId,
      );
      return active
          ? const PurchaseOutcome(PurchaseStatus.purchased)
          : const PurchaseOutcome(PurchaseStatus.pending);
    } on PlatformException catch (error) {
      return _failure(error);
    }
  }

  @override
  Future<PurchaseOutcome> restore() async {
    if (!await _ready()) {
      return const PurchaseOutcome(
        PurchaseStatus.failed,
        'Sign in to restore purchases.',
      );
    }
    try {
      final info = await Purchases.restorePurchases();
      return info.entitlements.active.containsKey(entitlementId)
          ? const PurchaseOutcome(PurchaseStatus.restored)
          : const PurchaseOutcome(PurchaseStatus.nothingToRestore);
    } on PlatformException catch (error) {
      return _failure(error);
    }
  }

  PurchaseOutcome _failure(PlatformException error) =>
      switch (PurchasesErrorHelper.getErrorCode(error)) {
        PurchasesErrorCode.purchaseCancelledError => const PurchaseOutcome(
          PurchaseStatus.cancelled,
        ),
        PurchasesErrorCode.paymentPendingError => const PurchaseOutcome(
          PurchaseStatus.pending,
        ),
        PurchasesErrorCode.purchaseNotAllowedError => const PurchaseOutcome(
          PurchaseStatus.failed,
          'Purchases are turned off on this device.',
        ),
        PurchasesErrorCode.networkError => const PurchaseOutcome(
          PurchaseStatus.failed,
          'Could not reach the App Store. Check your connection and try again.',
        ),
        _ => const PurchaseOutcome(
          PurchaseStatus.failed,
          'The App Store could not complete this. Please try again.',
        ),
      };
}
