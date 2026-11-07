import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/core/config/app_config.dart';
import 'package:revocred_flutter/core/models/app_models.dart';
import 'package:revocred_flutter/core/router/app_router.dart';
import 'package:revocred_flutter/core/state/app_controller.dart';
import 'package:revocred_flutter/core/theme/app_theme.dart';
import 'package:revocred_flutter/shared/widgets/community_card_details.dart';
import 'package:revocred_flutter/shared/widgets/content_layout.dart';
import 'package:revocred_flutter/shared/widgets/credit_card_view.dart';

const _sharedBenefit = 'Purchase protection — Eligible purchases only.';
const _catalogBenefit =
    r'Hotel credit — Up to $100 per anniversary year; two-night minimum; enrollment required.';
const _sourceRate =
    '5% — Rotating categories when activated · cap: {"amount":1500,"period":"quarter","currency":"USD"}';

CreditCard _card({bool community = true}) => CreditCard.fromApiJson({
  'id': 'card-presentation-test',
  'name': 'Everyday card',
  'annual_fee_cents': 9500,
  'reward_rates': {'other': 1, 'dining': 3},
  'benefits': [_sharedBenefit, _catalogBenefit],
  if (community)
    'community_data': {
      'attribution': 'OpenCard DB · CC BY 4.0 · adapted for display',
      'warning': 'Technical warning that must not be repeated in Cards.',
      'last_verified': '2020-01-01',
      'retrieved_at': '2026-10-25T23:00:00Z',
      'issuer_url': 'https://issuer.example/terms',
      'reward_rates': [_sourceRate, '1% — Other eligible purchases'],
      'currency_label': 'Cash back',
      'benefits': [_sharedBenefit, 'Extended warranty — Limits apply.'],
      'travel_perks': {
        'hotel_status': 'IHG One Rewards Platinum Elite through 2027-12-31',
        'lounge_access': {
          'program': 'Priority Pass',
          'notes': 'Enrollment required',
        },
      },
      'welcome_offer': {
        'description': 'An offer may be available for eligible new applicants.',
      },
    },
});

Future<void> _wallet(WidgetTester tester, CreditCard card) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.decisionFlow,
      home: Scaffold(
        body: SingleChildScrollView(child: WalletCardStack(cards: [card])),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _heading(String label) => find.byWidgetPredicate(
  (widget) => widget is SectionLabel && widget.text == label,
);

void main() {
  testWidgets('wallet has one complete rewards and merged benefits section', (
    tester,
  ) async {
    final card = _card();
    await _wallet(tester, card);
    expect(find.text('Annual fee'), findsOneWidget);
    expect(find.text(r'$95'), findsOneWidget);
    expect(_heading('Rewards'), findsOneWidget);
    expect(_heading('Reward multipliers'), findsNothing);
    for (final modeledRate in card.pointMultipliers) {
      expect(find.text(modeledRate), findsNothing);
    }
    expect(_heading('Credits & benefits'), findsOneWidget);
    expect(find.text(_sharedBenefit), findsOneWidget);
    expect(find.text(_catalogBenefit), findsOneWidget);
    expect(find.textContaining('Extended warranty'), findsOneWidget);
    expect(
      find.textContaining('IHG One Rewards Platinum Elite'),
      findsOneWidget,
    );
    expect(find.textContaining('Enrollment required'), findsOneWidget);
    expect(find.textContaining('when activated'), findsOneWidget);
    expect(find.textContaining('1,500'), findsOneWidget);
    expect(find.textContaining('quarter'), findsOneWidget);
    final text = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
        .join('\n');
    for (final technical in [
      'OpenCard DB',
      'CC BY',
      'Retrieved',
      'Technical warning',
      'from source',
      'cap:',
      '"amount"',
      '{',
      '}',
    ]) {
      expect(text, isNot(contains(technical)));
    }
    expect(find.text('Issuer terms'), findsOneWidget);
    expect(find.text('Data source'), findsNothing);
    expect(find.text('Data license'), findsNothing);
    expect(
      find.textContaining('excluded from value estimates'),
      findsOneWidget,
    );
    expect(card.communityData!.rewardRates.first, _sourceRate);
    expect(card.pointMultipliers, ['1x other', '3x dining']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('issuer terms and optional first-year offer stay available', (
    tester,
  ) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final launched = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'launch') {
            launched.add((call.arguments as Map)['url'] as String);
          }
          return true;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    final card = _card();
    await _wallet(tester, card);
    final offer = card.communityData!.welcomeOfferDescription;
    expect(find.text(offer), findsNothing);
    await tester.ensureVisible(find.text('First-year offer'));
    await tester.tap(find.text('First-year offer'));
    await tester.pumpAndSettle();
    expect(find.text(offer), findsOneWidget);
    expect(
      find.textContaining('excluded from value estimates'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Issuer terms'));
    await tester.tap(find.text('Issuer terms'));
    await tester.pumpAndSettle();
    expect(launched, ['https://issuer.example/terms']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom and legacy wallets retain their own terms', (
    tester,
  ) async {
    final card = _card(community: false);
    await _wallet(tester, card);
    for (final rate in card.pointMultipliers) {
      expect(find.text(rate), findsOneWidget);
    }
    expect(find.text(_catalogBenefit), findsOneWidget);
    expect(find.text(_sharedBenefit), findsOneWidget);
    expect(find.text('Annual fee'), findsOneWidget);
    expect(find.text(r'$95'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown verification and benefits are not presented as absent', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.decisionFlow,
        home: Scaffold(
          body: SingleChildScrollView(
            child: CommunityCardDetails(data: CommunityCardData.fromJson({})),
          ),
        ),
      ),
    );
    expect(find.textContaining('verification date is unknown'), findsOneWidget);
    expect(
      find.textContaining('does not mean the card has no benefits'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Reward details are not available'),
      findsOneWidget,
    );
    expect(find.text('Issuer terms'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('provider credit and working links are reachable at /legal', (
    tester,
  ) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final launched = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'launch') {
            launched.add((call.arguments as Map)['url'] as String);
          }
          return true;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    appRouter.go('/legal');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(const AppConfig(useMocks: true)),
        ],
        child: MaterialApp.router(routerConfig: appRouter),
      ),
    );
    await tester.pumpAndSettle();
    expect(appRouter.routeInformationProvider.value.uri.path, '/legal');
    await tester.scrollUntilVisible(find.textContaining('OpenCard DB'), 400);
    expect(find.textContaining('CC BY 4.0'), findsWidgets);
    expect(find.textContaining('adapted for display'), findsOneWidget);
    for (final label in ['Original card data', 'CC BY 4.0 license']) {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    expect(launched, [
      'https://github.com/thedavidweng/opencard-db',
      'https://creativecommons.org/licenses/by/4.0/',
    ]);
    expect(tester.takeException(), isNull);
  });
}
