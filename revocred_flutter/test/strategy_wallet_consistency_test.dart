import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/app.dart';
import 'package:revocred_flutter/core/config/app_config.dart';
import 'package:revocred_flutter/core/data/demo_seed.dart';
import 'package:revocred_flutter/core/data/mock_app_repository.dart';
import 'package:revocred_flutter/core/logic/playbook.dart';
import 'package:revocred_flutter/core/logic/strategy_digest.dart';
import 'package:revocred_flutter/core/models/app_models.dart';
import 'package:revocred_flutter/core/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:revocred_flutter/shared/widgets/credit_card_view.dart';

void main() {
  test(
    'A stale family-covered role never repeats an issued card under a second name',
    () {
      final base = _currentWallet();
      final student = base.catalog
          .firstWhere((card) => card.id == 'savor-student')
          .copyWith(isActive: true);
      final data = base.copyWith(
        wallet: [...base.wallet, student],
        playbook: PlaybookAssignment.fromJson({
          'code': 'S03',
          'title': 'Personal roadmap',
          'ecosystem': 'Mixed',
          'steps': [
            {
              'name': 'SavorOne',
              'card_id': 'savor-one',
              'status': 'have',
              'covered_by': 'Savor for Students',
            },
            {
              'name': 'Savor for Students',
              'card_id': student.id,
              'status': 'have',
              'covered_by': student.name,
              'completed_recommendation': true,
              'completed_order': 1,
            },
          ],
          'unused_cards': [],
          'alternatives': [],
        }),
      );
      final slots = strategyRoadmapSlots(data);
      expect(
        slots.where((s) => s.displayName == 'Savor for Students').length,
        1,
        reason: 'issued card rendered as both SavorOne cover and its own step',
      );
      expect(
        slots
            .where((s) => s.displayName == 'SavorOne')
            .every((s) => !s.isCovered),
        isTrue,
      );
    },
  );

  test(
    'Adding the second card keeps the first completed step in place and never duplicates the third',
    () {
      final base = _currentWallet();
      final student = base.catalog
          .firstWhere((card) => card.id == 'savor-student')
          .copyWith(isActive: true);
      final strata = CreditCard.fromApiJson({
        'id': 'strata',
        'name': 'Strata',
        'issuer': 'Citi',
      });
      AppData journey(bool thirdOwned) => base.copyWith(
        catalog: [...base.catalog, strata],
        wallet: [
          ...base.wallet,
          student,
          if (thirdOwned) strata.copyWith(isActive: true),
        ],
        playbook: PlaybookAssignment.fromJson({
          'code': 'S03',
          'title': 'Personal roadmap',
          'ecosystem': 'Mixed',
          'steps': [
            // Absorbed server shape: SavorOne's redundant template role is
            // gone once Savor for Students fills the family, so only 3 roles.
            {
              'name': 'Savor for Students',
              'card_id': student.id,
              'status': 'have',
              'covered_by': student.name,
              'completed_recommendation': true,
              'completed_order': 2,
              'note': 'Fills the SavorOne role in this strategy.',
            },
            {
              'name': 'Double Cash',
              'card_id': 'double-cash',
              'status': 'have',
              'covered_by': 'Double Cash',
              'completed_recommendation': true,
              'completed_order': 1,
            },
            {
              'name': 'Strata',
              'card_id': 'strata',
              'status': thirdOwned ? 'have' : 'next',
              'completed_recommendation': thirdOwned,
              'completed_order': thirdOwned ? 3 : 0,
            },
            {'name': 'Strata alias', 'card_id': 'strata', 'status': 'later'},
          ],
          'unused_cards': [],
          'alternatives': [],
        }),
      );
      for (final thirdOwned in [false, true]) {
        final slots = strategyRoadmapSlots(journey(thirdOwned));
        expect(
          slots
              .where(
                (s) =>
                    s.completedRecommendation ||
                    s.status == StrategySlotStatus.next,
              )
              .map((s) => s.displayName),
          ['Double Cash', 'Savor for Students', 'Strata'],
        );
        expect(slots.first.status, StrategySlotStatus.completed);
        expect(slots[1].status, StrategySlotStatus.completed);
        expect(
          slots.where((s) => s.displayName == 'Strata').single.status,
          thirdOwned ? StrategySlotStatus.completed : StrategySlotStatus.next,
        );
        expect(slots.where((s) => s.displayName == 'Strata').length, 1);
        expect(
          slots.where((s) => s.displayName == 'SavorOne'),
          isEmpty,
          reason: 'absorbed template role must not render',
        );
        expect(slots.length, 3, reason: 'only 3 roles, no redundant fourth');
        final ids = [
          for (final s in slots)
            s.cardId.isNotEmpty ? s.cardId : '${s.displayName}|${s.targetName}',
        ];
        expect(
          ids.toSet().length,
          ids.length,
          reason: 'same card in two roles',
        );
        expect(
          slots.map((s) => s.displayName).toSet().length,
          slots.length,
          reason: 'same card name rendered twice',
        );
      }
    },
  );

  testWidgets(
    'Previously recommended Double Cash remains an exact completed roadmap step',
    (tester) async {
      final base = _currentWallet();
      final custom = CreditCard.fromApiJson({
        'id': 'custom-double',
        'name': 'Double Cash',
        'issuer': 'Member entered',
        'terms_unknown': true,
      }).copyWith(isActive: true);
      final data = base.copyWith(
        wallet: [custom, ...base.wallet],
        playbook: PlaybookAssignment.fromJson({
          'code': 'S03',
          'title': 'Cash back',
          'ecosystem': 'Capital One',
          'steps': [
            {
              'name': 'Double Cash',
              'card_id': 'double-cash',
              'status': 'have',
              'covered_by': 'Double Cash',
              'completed_recommendation': true,
              'use': 'Previously recommended; now in your wallet.',
            },
            {
              'name': 'Savor for Students',
              'card_id': 'savor-student',
              'status': 'next',
            },
          ],
          'unused_cards': [],
          'alternatives': [],
        }),
      );
      await _pump(tester, data);
      expect(find.text('ROLE 1: COMPLETED'), findsOneWidget);
      expect(find.text('Completed recommendation'), findsWidgets);
      final role = find.byKey(const ValueKey('strategy-roadmap-card-1'));
      expect(
        tester
            .widget<CreditCardArt>(
              find.descendant(of: role, matching: find.byType(CreditCardArt)),
            )
            .card
            .id,
        'double-cash',
      );
      expect(strategyNextCardName(data), 'Savor for Students');
      expect(tester.takeException(), isNull);
      final removed = data.copyWith(
        wallet: data.wallet.where((card) => card.id != 'double-cash').toList(),
      );
      expect(
        strategyRoadmapSlots(
          removed,
        ).where((slot) => slot.completedRecommendation),
        isEmpty,
        reason:
            'A same-name custom card cannot retain completion for the removed exact product.',
      );
    },
  );

  testWidgets(
    'Strategy keeps all owned cards visible without inventing covered roles',
    (tester) async {
      final data = _currentWallet();

      await _pump(tester, data);
      for (final card in data.wallet) {
        expect(
          find.byKey(ValueKey('strategy-owned-card-${card.id}')),
          findsOneWidget,
        );
      }
      expect(find.text('Already owned'), findsNWidgets(2));
      expect(
        find.textContaining('Consider next: Savor for Students'),
        findsOneWidget,
      );
      expect(find.text('0 OF 3 ROLES COVERED'), findsOneWidget);
      expect(strategyNextCardName(data), 'Savor for Students');
      expect(data.pointsValue, 77);
      expect(data.projectedYearlyValue, 288);
      expect(tester.takeException(), isNull);
      for (final width in [320.0, 900.0]) {
        tester.view.physicalSize = Size(width, 1000);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        await tester.pumpAndSettle();
        expect(find.text('Already owned'), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'A four-role strategy retains its two owned roles and only one next application',
    (tester) async {
      final data = _currentWallet(fourRoles: true);
      await _pump(tester, data);
      expect(find.text('2 OF 4 ROLES COVERED'), findsOneWidget);
      expect(find.text('ROLE 1: IN YOUR WALLET'), findsOneWidget);
      expect(find.text('ROLE 2: IN YOUR WALLET'), findsOneWidget);
      expect(find.text('Already owned'), findsNWidgets(2));
      expect(
        find.byKey(const ValueKey('strategy-next-details')),
        findsOneWidget,
      );
      expect(strategyTargetCards(data).length, 4);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Cards picker and Strategy name the same personalized next card',
    (tester) async {
      final data = _currentWallet();
      await _pump(tester, data, location: '/cards?search=1');
      final next = find.byKey(
        const ValueKey('wallet-search-result-savor-student'),
      );
      expect(
        find.descendant(of: next, matching: find.text('Next in your strategy')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('wallet-search-result-double-cash')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('wallet-search-result-discover-it')),
        findsNothing,
      );
      expect(
        find.text(
          'Other results are catalog cards, not additional recommendations.',
        ),
        findsOneWidget,
      );
      appRouter.go('/strategy-report');
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Consider next: Savor for Students'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('strategy-owned-card-double-cash')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'A just-added owned next card is completed without promoting a later card locally',
    () {
      final data = _currentWallet().copyWith(
        playbook: const PlaybookAssignment(
          code: 'S03',
          title: 'Cash back',
          ecosystem: 'Capital One',
          steps: [
            PlaybookStep(
              name: 'Double Cash',
              use: 'Everyday purchases',
              status: 'next',
            ),
            PlaybookStep(
              name: 'Savor for Students',
              use: 'Dining',
              status: 'later',
            ),
          ],
          unused: [],
          alternatives: [],
        ),
      );
      expect(
        strategyRoadmapSlots(data).first.status,
        StrategySlotStatus.completed,
      );
      expect(strategyNextCardName(data), isNull);
      expect(strategyDigest(data).nextMove, contains('No new application'));
      expect(strategyRoadmapSlots(data).last.status, StrategySlotStatus.later);
    },
  );

  test(
    'Offline add and removal refresh owned roles and the common next card',
    () async {
      final repository = MockAppRepository(initialData: createDemoAppData());
      await repository.addCard('freedom-flex');
      var data = await repository.loadAppData();
      expect(strategyNextCardName(data), 'Sapphire Preferred');
      expect(
        strategyRoadmapSlots(
          data,
        ).where((s) => s.isCovered).map((s) => s.displayName),
        contains('Freedom Flex'),
      );
      await repository.removeCard('freedom-flex');
      data = await repository.loadAppData();
      expect(strategyNextCardName(data), 'Freedom Flex');
      expect(
        strategyRoadmapSlots(
          data,
        ).where((s) => s.isCovered).map((s) => s.displayName),
        isNot(contains('Freedom Flex')),
      );
    },
  );
}

Future<void> _pump(
  WidgetTester tester,
  AppData data, {
  String location = '/strategy-report',
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  appRouter.go(location);
  await tester.pumpWidget(
    RevoCredBootstrap(
      config: const AppConfig(useMocks: true),
      repository: MockAppRepository(initialData: data),
      preferences: preferences,
    ),
  );
  await tester.pumpAndSettle();
}

// API-shaped fixture for a personalized S03 next card outside its template.
AppData _currentWallet({bool fourRoles = false}) {
  final catalog = [
    {
      'id': 'double-cash',
      'name': 'Double Cash',
      'issuer': 'Citi',
      'reward_rates': {'other': 2},
    },
    {
      'id': 'discover-it',
      'name': 'Discover it Cash Back',
      'issuer': 'Discover',
      'reward_rates': {'other': 1},
    },
    {
      'id': 'savor-student',
      'name': 'Savor for Students',
      'issuer': 'Capital One',
    },
    {'id': 'savor-one', 'name': 'SavorOne', 'issuer': 'Capital One'},
    {'id': 'quicksilver', 'name': 'Quicksilver', 'issuer': 'Capital One'},
  ];
  return AppData.fromApiJson(
    {
      'profile': {'display_name': 'Member', 'credit_card_strategy': 'S03'},
      'catalog': catalog,
      'wallet': [
        for (final card in catalog.take(2))
          {'id': 'wallet-${card['id']}', 'status': 'active', 'card': card},
      ],
      'playbook': {
        'code': 'S03',
        'title': 'Everyday cash-back foundation',
        'ecosystem': 'Capital One',
        'steps': [
          if (fourRoles) ...[
            {
              'name': 'Double Cash',
              'status': 'have',
              'covered_by': 'Double Cash',
            },
            {
              'name': 'Discover it Cash Back',
              'status': 'have',
              'covered_by': 'Discover it Cash Back',
            },
          ] else ...[
            {'name': 'SavorOne', 'status': 'unavailable'},
            {'name': 'Quicksilver', 'status': 'unavailable'},
          ],
          {
            'name': 'Savor for Students',
            'status': 'next',
            'use': 'Highest-ranked eligible improvement.',
          },
          if (fourRoles) {'name': 'SavorOne', 'status': 'later'},
        ],
        'unused_cards': [],
        'alternatives': [],
      },
      'wallet_metrics': {'score': 77, 'yearly_value': 288},
    },
    messages: [],
    email: 'member@example.test',
  );
}
