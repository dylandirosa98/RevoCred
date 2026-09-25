import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/core/config/app_config.dart';
import 'package:revocred_flutter/core/models/affiliate_offer.dart';
import 'package:revocred_flutter/core/models/app_models.dart';
import 'package:revocred_flutter/core/state/affiliate_providers.dart';
import 'package:revocred_flutter/core/state/app_controller.dart';
import 'package:revocred_flutter/shared/widgets/apply_offer_button.dart';

class _Controller extends AppController {
  _Controller(this.initial);
  final AppState initial;
  @override
  AppState build() => initial;
}

const _offerId = '11111111-1111-4111-8111-111111111111';

AppData _data({bool owned = false, bool ranked = true}) => AppData.fromApiJson(
  {
    'catalog': [
      {'id': 'ranked-card', 'name': 'Recommended card'},
    ],
    'wallet': [
      if (owned)
        {
          'id': 'wallet-id',
          'status': 'active',
          'card': {'id': 'ranked-card', 'name': 'Recommended card'},
        },
    ],
    'latest_recommendations': {
      'items': [
        if (ranked) {'card_id': 'ranked-card'},
      ],
    },
  },
  messages: [],
  email: 'member@example.test',
);

void main() {
  Future<void> mount(
    WidgetTester tester, {
    bool mock = false,
    bool guest = false,
    bool owned = false,
    bool ranked = true,
    bool expired = false,
    bool outage = false,
    String offerCard = 'ranked-card',
    DateTime? expiresAt,
    DateTime Function()? clock,
    Future<bool> Function(Uri)? launch,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (clock != null) affiliateClockProvider.overrideWithValue(clock),
          appConfigProvider.overrideWithValue(
            AppConfig(useMocks: mock, apiUrl: 'https://api.example.test'),
          ),
          appControllerProvider.overrideWith(
            () => _Controller(
              AppState(
                isAuthenticated: !guest,
                isLoading: false,
                data: _data(owned: owned, ranked: ranked),
              ),
            ),
          ),
          affiliateOffersProvider.overrideWith((ref) async {
            if (outage) throw StateError('offline');
            return [
              AffiliateOffer(
                id: _offerId,
                cardId: offerCard,
                endsAt:
                    expiresAt ??
                    DateTime.now().add(Duration(hours: expired ? -1 : 1)),
              ),
            ];
          }),
          applicationLauncherProvider.overrideWithValue(
            launch ?? (_) async => true,
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ApplyOfferButton(placement: ApplyPlacement.strategy),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'disclosed link uses API redirect with placement and no account data',
    (tester) async {
      Uri? opened;
      await mount(
        tester,
        launch: (uri) async {
          opened = uri;
          return true;
        },
      );
      expect(find.text(affiliateDisclosure), findsOneWidget);
      await tester.tap(find.text('Apply for Recommended card'));
      await tester.pumpAndSettle();
      expect(
        opened.toString(),
        'https://api.example.test/v1/offers/$_offerId/apply?placement=strategy',
      );
    },
  );

  testWidgets('Apply disappears at expiry without navigation or polling', (
    tester,
  ) async {
    var now = DateTime.now().add(const Duration(hours: 1));
    await mount(
      tester,
      clock: () => now,
      expiresAt: now.add(const Duration(seconds: 2)),
    );
    expect(find.byType(FilledButton), findsOneWidget);
    now = now.add(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byType(FilledButton), findsNothing);
  });

  for (final scenario in [
    'mock',
    'guest',
    'owned',
    'unranked',
    'expired',
    'outage',
    'other card',
  ]) {
    testWidgets('no Apply button for $scenario', (tester) async {
      await mount(
        tester,
        mock: scenario == 'mock',
        guest: scenario == 'guest',
        owned: scenario == 'owned',
        ranked: scenario != 'unranked',
        expired: scenario == 'expired',
        outage: scenario == 'outage',
        offerCard: scenario == 'other card'
            ? 'paid-alternative'
            : 'ranked-card',
      );
      expect(find.byType(FilledButton), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('browser launch failure is actionable and allows retry', (
    tester,
  ) async {
    await mount(tester, launch: (_) async => false);
    await tester.tap(find.text('Apply for Recommended card'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not open the application link. Please try again.'),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });
}
