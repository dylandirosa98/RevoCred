import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../models/affiliate_offer.dart';
import 'app_controller.dart';

final affiliateClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final affiliateOffersProvider = FutureProvider.autoDispose<List<AffiliateOffer>>((
  ref,
) async {
  final config = ref.watch(appConfigProvider);
  final authenticated = ref.watch(
    appControllerProvider.select((state) => state.isAuthenticated),
  );
  // Guest browsing uses unverified demo data, even when the API is configured.
  if (config.useMocks || !authenticated) return const [];
  final client = http.Client();
  ref.onDispose(client.close);
  final timer = Timer(const Duration(minutes: 1), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  final response = await client
      .get(
        Uri.parse('${config.apiUrl.replaceFirst(RegExp(r'/$'), '')}/v1/offers'),
      )
      .timeout(const Duration(seconds: 10));
  if (response.statusCode != 200) throw StateError('Offers are unavailable.');
  final data = (jsonDecode(response.body) as Map)['data'] as List;
  return data
      .map(
        (item) =>
            AffiliateOffer.fromJson((item as Map).cast<String, dynamic>()),
      )
      .toList();
});

final recommendedApplicationProvider = Provider.autoDispose
    .family<ApplicationLink?, ApplyPlacement>((ref, placement) {
      final config = ref.watch(appConfigProvider);
      if (config.useMocks) return null;
      final state = ref.watch(appControllerProvider);
      if (!state.isAuthenticated || state.isLoading || state.error != null) {
        return null;
      }
      final data = state.data;
      final id = data?.recommendedCardId;
      if (data == null ||
          id == null ||
          data.wallet.any((card) => card.id == id)) {
        return null;
      }
      final card = data.catalog.where((card) => card.id == id).firstOrNull;
      if (card == null) return null;
      final offers =
          ref.watch(affiliateOffersProvider).asData?.value ??
          const <AffiliateOffer>[];
      final now = ref.watch(affiliateClockProvider)();
      final offer = offers
          .where((offer) => offer.cardId == id && offer.endsAt.isAfter(now))
          .firstOrNull;
      if (offer == null || !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(offer.id)) {
        return null;
      }
      final expiration = Timer(
        offer.endsAt.difference(now),
        ref.invalidateSelf,
      );
      ref.onDispose(expiration.cancel);
      final base = Uri.tryParse(config.apiUrl);
      if (base == null ||
          !const ['http', 'https'].contains(base.scheme) ||
          base.host.isEmpty) {
        return null;
      }
      return ApplicationLink(
        cardName: card.name,
        endsAt: offer.endsAt,
        uri: Uri.parse(
          '${config.apiUrl.replaceFirst(RegExp(r'/$'), '')}/v1/offers/${offer.id}/apply',
        ).replace(queryParameters: {'placement': placement.name}),
      );
    });

final applicationLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      ),
);
