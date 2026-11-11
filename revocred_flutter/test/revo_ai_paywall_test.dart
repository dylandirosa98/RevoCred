import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/app.dart';
import 'package:revocred_flutter/core/config/app_config.dart';
import 'package:revocred_flutter/core/data/chat_stream.dart';
import 'package:revocred_flutter/core/data/mock_app_repository.dart';
import 'package:revocred_flutter/core/models/ai_plan.dart';
import 'package:revocred_flutter/core/models/chat_errors.dart';
import 'package:revocred_flutter/core/router/app_router.dart';
import 'package:revocred_flutter/core/services/subscriptions.dart';
import 'package:revocred_flutter/features/subscription/presentation/revo_ai_paywall.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Demo data with a controllable plan and a REVO send that hits the free
/// daily AI limit.
class _PlanRepository extends MockAppRepository {
  _PlanRepository(this.plan);
  AIPlan plan;

  /// Returned from a refresh, as after the server confirms a purchase.
  AIPlan? afterRefresh;
  int refreshes = 0;

  @override
  Future<AIPlan> loadAIPlan({bool refresh = false}) async {
    if (refresh) {
      refreshes++;
      if (afterRefresh != null) plan = afterRefresh!;
    }
    return plan;
  }

  @override
  Stream<ChatStreamEvent> streamMessage(
    String prompt, {
    String? aiConsentVersion,
  }) async* {
    throw const ChatSendException(
      'chat_daily_limit',
      "You've used today's free REVO AI answers.",
      details: {'plan': 'free', 'limit': '3'},
    );
  }
}

class _FakeStore implements SubscriptionService {
  _FakeStore({this.offer, this.purchaseResult, this.restoreResult});
  StoreOffer? offer;
  PurchaseOutcome? purchaseResult;
  PurchaseOutcome? restoreResult;
  int purchases = 0;

  @override
  bool get available => true;
  @override
  Future<void> identify(String? userId) async {}
  @override
  Future<StoreOffer?> loadOffer() async => offer;
  @override
  Future<PurchaseOutcome> purchase(StoreOffer offer) async {
    purchases++;
    return purchaseResult ?? const PurchaseOutcome(PurchaseStatus.purchased);
  }

  @override
  Future<PurchaseOutcome> restore() async =>
      restoreResult ?? const PurchaseOutcome(PurchaseStatus.nothingToRestore);
}

const _free = AIPlan(
  subscriber: false,
  used: 3,
  limit: 3,
  purchasesEnabled: true,
);
final _subscriber = AIPlan(
  subscriber: true,
  source: 'revenuecat',
  used: 5,
  limit: 60,
  expiresAt: DateTime(2026, 12, 11),
  purchasesEnabled: true,
);
const _offer = StoreOffer(price: r'$9.99', handle: 'monthly');

Future<void> _launch(
  WidgetTester tester,
  _PlanRepository repository, {
  SubscriptionService subscriptions = const UnavailableSubscriptionService(),
  String route = '/profile',
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    RevoCredBootstrap(
      config: const AppConfig(useMocks: true),
      repository: repository,
      preferences: preferences,
      subscriptions: subscriptions,
    ),
  );
  await tester.pumpAndSettle();
  appRouter.go(route);
  await tester.pumpAndSettle();
}

/// Opens the plan sheet directly, as Profile and the send flow do.
Future<void> _openSheet(WidgetTester tester, {String? limitMessage}) async {
  final context = tester.element(find.byType(Navigator).first);
  showRevoAIPaywall(context, limitMessage: limitMessage);
  await tester.pumpAndSettle();
}

Finder _key(String key) => find.byKey(ValueKey(key));

void main() {
  testWidgets('without in-app purchases the sheet explains the limit only', (
    tester,
  ) async {
    await _launch(tester, _PlanRepository(_free));
    await _openSheet(tester, limitMessage: 'Free AI answers used.');
    expect(find.text('Free AI answers used.'), findsOneWidget);
    expect(find.text('3 of 3 AI answers used today'), findsOneWidget);
    expect(_key('paywall-free-note'), findsOneWidget);
    expect(_key('paywall-subscribe'), findsNothing);
    expect(_key('paywall-restore'), findsNothing);
    expect(_key('paywall-terms-link'), findsOneWidget);
    expect(_key('paywall-privacy-link'), findsOneWidget);
  });

  testWidgets('the store price, renewal terms and restore are shown', (
    tester,
  ) async {
    final store = _FakeStore(offer: _offer);
    await _launch(tester, _PlanRepository(_free), subscriptions: store);
    await _openSheet(tester);
    expect(find.text(r'REVO AI — $9.99/month'), findsOneWidget);
    expect(find.text(r'Subscribe for $9.99/month'), findsOneWidget);
    final terms = tester.widget<Text>(_key('paywall-terms')).data!;
    expect(terms, contains('renews automatically each month at \$9.99'));
    expect(terms, contains('24 hours before the end of the current period'));
    expect(terms, contains('Subscriptions'));
    expect(find.textContaining('60 AI answers a day'), findsOneWidget);
    expect(find.text('For card and money questions only'), findsOneWidget);
    expect(_key('paywall-restore'), findsOneWidget);
  });

  testWidgets('no purchase is offered while the server cannot accept one', (
    tester,
  ) async {
    const plan = AIPlan(subscriber: false, used: 1, limit: 3);
    await _launch(
      tester,
      _PlanRepository(plan),
      subscriptions: _FakeStore(offer: _offer),
    );
    await _openSheet(tester);
    expect(_key('paywall-subscribe'), findsNothing);
    expect(_key('paywall-restore'), findsNothing);
    expect(_key('paywall-free-note'), findsOneWidget);
  });

  testWidgets('a missing store product disables subscribing', (tester) async {
    await _launch(tester, _PlanRepository(_free), subscriptions: _FakeStore());
    await _openSheet(tester);
    final button = tester.widget<FilledButton>(_key('paywall-subscribe'));
    expect(button.onPressed, isNull);
    expect(find.textContaining('could not be loaded'), findsOneWidget);
  });

  testWidgets('a purchase unlocks once the server confirms it', (tester) async {
    final repository = _PlanRepository(_free)..afterRefresh = _subscriber;
    final store = _FakeStore(offer: _offer);
    await _launch(tester, repository, subscriptions: store);
    await _openSheet(tester);
    await tester.tap(_key('paywall-subscribe'));
    await tester.pumpAndSettle();
    expect(store.purchases, 1);
    expect(repository.refreshes, 1);
    expect(find.textContaining('REVO AI is active'), findsOneWidget);
    expect(find.text('You have REVO AI'), findsOneWidget);
    expect(_key('paywall-manage'), findsOneWidget);
    expect(_key('paywall-subscribe'), findsNothing);
  });

  testWidgets('a cancelled purchase says nothing; restore reports none', (
    tester,
  ) async {
    final store = _FakeStore(
      offer: _offer,
      purchaseResult: const PurchaseOutcome(PurchaseStatus.cancelled),
    );
    final repository = _PlanRepository(_free);
    await _launch(tester, repository, subscriptions: store);
    await _openSheet(tester);
    await tester.tap(_key('paywall-subscribe'));
    await tester.pumpAndSettle();
    expect(_key('paywall-notice'), findsNothing);
    expect(repository.refreshes, 0);
    await tester.tap(_key('paywall-restore'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No REVO AI subscription'), findsOneWidget);
  });

  testWidgets('restore unlocks after server confirmation', (tester) async {
    final repository = _PlanRepository(_free)..afterRefresh = _subscriber;
    await _launch(
      tester,
      repository,
      subscriptions: _FakeStore(
        offer: _offer,
        restoreResult: const PurchaseOutcome(PurchaseStatus.restored),
      ),
    );
    await _openSheet(tester);
    await tester.tap(_key('paywall-restore'));
    await tester.pumpAndSettle();
    expect(repository.refreshes, 1);
    expect(find.text('You have REVO AI'), findsOneWidget);
  });

  for (final status in [PurchaseStatus.pending, PurchaseStatus.failed]) {
    testWidgets('a $status purchase does not grant access', (tester) async {
      final repository = _PlanRepository(_free);
      await _launch(
        tester,
        repository,
        subscriptions: _FakeStore(
          offer: _offer,
          purchaseResult: PurchaseOutcome(status),
        ),
      );
      await _openSheet(tester);
      await tester.tap(_key('paywall-subscribe'));
      await tester.pumpAndSettle();
      expect(_key('paywall-notice'), findsOneWidget);
      expect(repository.refreshes, 0);
      expect(find.text('You have REVO AI'), findsNothing);
    });
  }

  testWidgets('a subscriber sees the plan and Manage subscription', (
    tester,
  ) async {
    await _launch(
      tester,
      _PlanRepository(_subscriber),
      subscriptions: _FakeStore(offer: _offer),
    );
    expect(_key('revo-ai-plan-row'), findsOneWidget);
    expect(
      find.text('REVO AI · 5 of 60 AI answers used today'),
      findsOneWidget,
    );
    expect(_key('revo-ai-manage'), findsOneWidget);
    await tester.tap(_key('revo-ai-plan-row'));
    await tester.pumpAndSettle();
    expect(find.text('You have REVO AI'), findsOneWidget);
    expect(find.text('Renews or ends Dec 11, 2026'), findsOneWidget);
    expect(_key('paywall-manage'), findsOneWidget);
    expect(_key('paywall-subscribe'), findsNothing);
  });

  testWidgets('the free plan row shows usage without Manage subscription', (
    tester,
  ) async {
    await _launch(tester, _PlanRepository(_free));
    expect(find.text('Free · 3 of 3 AI answers used today'), findsOneWidget);
    expect(_key('revo-ai-manage'), findsNothing);
  });

  testWidgets('the free limit opens the paywall where purchases work', (
    tester,
  ) async {
    await _launch(
      tester,
      _PlanRepository(_free),
      subscriptions: _FakeStore(offer: _offer),
      route: '/revo',
    );
    await tester.enterText(_key('revo-composer'), 'Best grocery card?');
    await tester.tap(_key('revo-send'));
    await tester.pumpAndSettle();
    expect(_key('paywall-subscribe'), findsOneWidget);
    expect(_key('paywall-title'), findsOneWidget);
  });

  testWidgets('without purchases the free limit shows only the message', (
    tester,
  ) async {
    await _launch(tester, _PlanRepository(_free), route: '/revo');
    await tester.enterText(_key('revo-composer'), 'Best grocery card?');
    await tester.tap(_key('revo-send'));
    await tester.pumpAndSettle();
    expect(find.textContaining("today's free REVO AI answers"), findsOneWidget);
    expect(_key('paywall-title'), findsNothing);
  });

  test('limit errors keep the server details', () {
    final error = chatErrorFromJson({
      'error': {
        'code': 'chat_daily_limit',
        'message': 'Limit',
        'details': {'plan': 'free', 'limit': 3},
      },
    }, 429);
    expect(error.freeLimitReached, isTrue);
    expect(error.details['limit'], '3');
    expect(
      const ChatSendException(
        'chat_daily_limit',
        '',
        details: {'plan': 'subscriber'},
      ).freeLimitReached,
      isFalse,
    );
  });

  test('plans parse from the API', () {
    final plan = AIPlan.fromJson({
      'data': {
        'plan': 'subscriber',
        'source': 'revenuecat',
        'used': 4,
        'limit': 60,
        'remaining': 56,
        'expires_at': '2026-12-11T00:00:00Z',
        'next_reset_at': null,
        'ai_available': true,
        'purchases_enabled': true,
      },
    });
    expect(plan.subscriber, isTrue);
    expect(plan.appStoreSubscription, isTrue);
    expect(plan.remaining, 56);
    expect(plan.expiresAt, isNotNull);
    expect(plan.purchasesEnabled, isTrue);
  });
}
