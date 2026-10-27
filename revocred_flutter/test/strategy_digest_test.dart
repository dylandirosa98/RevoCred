import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/core/data/demo_seed.dart';
import 'package:revocred_flutter/core/logic/playbook.dart';
import 'package:revocred_flutter/core/logic/strategy_digest.dart';
import 'package:revocred_flutter/core/models/app_models.dart';

void main() {
  test(
    'server next card precedes later roles and timing is shared unchanged',
    () {
      final data = createDemoAppData().copyWith(
        playbook: const PlaybookAssignment(
          code: 'S04',
          title: 'Personal strategy',
          ecosystem: 'Chase',
          steps: [
            PlaybookStep(
              name: 'Future card',
              use: '',
              status: 'later',
              timing: 'Wait 3-6 months',
            ),
            PlaybookStep(
              name: 'Owned card',
              use: '',
              status: 'have',
              coveredBy: 'Owned substitute',
            ),
            PlaybookStep(
              name: 'Unavailable card',
              use: '',
              status: 'unavailable',
            ),
            PlaybookStep(
              name: 'Ranked next',
              use: '',
              status: 'next',
              timing: 'Consider now, after checks',
              timingNote: 'History unknown',
            ),
          ],
          unused: [],
          alternatives: [],
        ),
      );
      final slots = strategyRoadmapSlots(data);
      expect(slots.map((slot) => slot.displayName), [
        'Owned substitute',
        'Ranked next',
        'Future card',
        'Unavailable card',
      ]);
      expect(slots[0].timing, 'Already covered');
      expect(slots[1].timing, 'Consider now, after checks');
      expect(slots[1].timingNote, 'History unknown');
      expect(slots[3].timing, 'Do not apply now');
    },
  );
  test('application order stays consistent with the visible roadmap', () {
    const data = AppData(
      profile: UserProfile(
        name: 'Rae',
        strategy: 'S04',
        goal: 'Travel',
        topSpendCategories: '',
        nextTarget: 'Freedom Flex',
        email: '',
      ),
      wallet: [],
      catalog: [],
      roadmap: [
        RoadmapStep(
          id: '1',
          cardId: 'Freedom Unlimited',
          stage: 'Already in wallet',
          note: '',
          estimatedValue: 0,
        ),
        RoadmapStep(
          id: '2',
          cardId: 'Freedom Flex',
          stage: 'Consider next',
          note: '',
          estimatedValue: 0,
        ),
        RoadmapStep(
          id: '3',
          cardId: 'Sapphire Preferred',
          stage: 'Later',
          note: '',
          estimatedValue: 0,
        ),
      ],
      messages: [],
      quickPrompts: [],
      pointsValue: 0,
      projectedYearlyValue: 0,
      monthlySpend: {},
    );

    expect(strategyDigest(data).order, [
      'Already in wallet: Freedom Unlimited',
      'Consider next: Freedom Flex',
      'Later: Sapphire Preferred',
    ]);
  });

  test('next move follows the first actionable roadmap card', () {
    const data = AppData(
      profile: UserProfile(
        name: 'Alex',
        strategy: 'S04',
        goal: 'Travel',
        topSpendCategories: 'Food, Everyday, Travel',
        nextTarget: 'Freedom Flex',
        email: '',
      ),
      wallet: [],
      catalog: [],
      roadmap: [
        RoadmapStep(
          id: '1',
          cardId: 'Sapphire Preferred',
          stage: 'Apply now',
          note: 'Add transferable points and travel protections.',
          estimatedValue: 0,
        ),
        RoadmapStep(
          id: '2',
          cardId: 'Bilt Mastercard',
          stage: 'In 6 months',
          note: 'Add rent rewards after spacing applications.',
          estimatedValue: 0,
        ),
      ],
      messages: [],
      quickPrompts: [],
      pointsValue: 88,
      projectedYearlyValue: 468,
      monthlySpend: {},
      recommendedCardId: null,
    );

    expect(
      strategyDigest(data).nextMove,
      'Consider next: Sapphire Preferred — Add transferable points and travel protections.',
    );
  });

  test('demo recommendations follow the selected strategy in one order', () {
    final data = createDemoAppData();

    expect(data.strategyPlan?.cards, [
      'Freedom Unlimited',
      'Freedom Flex',
      'Sapphire Preferred',
    ]);
    expect(data.roadmap.map((step) => step.cardId), [
      'freedom-flex',
      'sapphire-preferred',
    ]);
    expect(strategyNextCardName(data), 'Freedom Flex');
    expect(strategyComparisonCards(data).take(2).map((card) => card.name), [
      'Freedom Flex',
      'Sapphire Preferred',
    ]);
    expect(strategyTargetCards(data).map((card) => card.name), [
      'Freedom Unlimited',
      'Freedom Flex',
      'Sapphire Preferred',
    ]);
    final slots = strategyRoadmapSlots(data);
    expect(slots.map((slot) => slot.status), [
      StrategySlotStatus.completed,
      StrategySlotStatus.next,
      StrategySlotStatus.later,
    ]);
    expect(strategyCoveredRoleCount(data), 1);
  });

  test('owned approved substitute replaces its roadmap role', () {
    final base = createDemoAppData();
    final discover = demoCatalog
        .firstWhere((card) => card.id == 'discover-it')
        .copyWith(isActive: true);
    final data = base.copyWith(
      wallet: [...base.wallet, discover],
      playbook: const PlaybookAssignment(
        code: 'S04',
        title: 'Flexible travel foundation',
        ecosystem: 'Chase',
        steps: [
          PlaybookStep(
            name: 'Freedom Unlimited',
            use: 'Everyday catch-all',
            status: 'have',
            coveredBy: 'Freedom Unlimited',
          ),
          PlaybookStep(
            name: 'Freedom Flex',
            use: 'Rotating categories',
            status: 'have',
            coveredBy: 'Discover it Cash Back',
            note:
                'Keep your Discover it Cash Back; it covers the Freedom Flex role in this strategy.',
          ),
          PlaybookStep(
            name: 'Sapphire Preferred',
            use: 'Transfer partners',
            status: 'next',
          ),
        ],
        unused: [],
        alternatives: [],
      ),
    );

    final slots = strategyRoadmapSlots(data);
    expect(slots[1].status, StrategySlotStatus.substituted);
    expect(slots[1].displayName, 'Discover it Cash Back');
    expect(slots[1].targetName, 'Freedom Flex');
    expect(strategyTargetCards(data).map((card) => card.name), [
      'Freedom Unlimited',
      'Discover it Cash Back',
      'Sapphire Preferred',
    ]);
  });

  test(
    'profile name personalizes a saved plan when questionnaire name is empty',
    () {
      const data = AppData(
        profile: UserProfile(
          name: 'Dana Okafor',
          strategy: 'S04',
          goal: 'Travel',
          topSpendCategories: '',
          nextTarget: 'Strata',
          email: 'dana@example.test',
        ),
        wallet: [],
        catalog: [],
        roadmap: [],
        messages: [],
        quickPrompts: [],
        pointsValue: 0,
        projectedYearlyValue: 0,
        monthlySpend: {},
        questionnaireAnswers: QuestionnaireAnswers(
          lifeStage: 'adult-building',
          existingCardIds: [],
          feeTolerance: 'low',
          travelScope: 'both',
          creditTier: 'good',
          monthlySpend: {},
          rewardsGoal: 'travel',
        ),
      );

      expect(
        strategyDigest(data).title,
        'Dana’s Personalized Credit Card Strategy',
      );
    },
  );

  test('account metadata fills a temporarily blank API profile name', () {
    final data = AppData.fromApiJson(
      const {
        'profile': {
          'display_name': '',
          'credit_card_strategy': 'S04',
          'goal': 'Travel',
        },
      },
      messages: const [],
      email: 'dana@example.test',
      displayNameFallback: 'Dana Okafor',
    );

    expect(data.profile.name, 'Dana Okafor');
    expect(
      strategyDigest(data).title,
      'Dana’s Personalized Credit Card Strategy',
    );
  });
}
