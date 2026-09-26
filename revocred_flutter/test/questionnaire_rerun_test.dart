import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:revocred_flutter/app.dart';
import 'package:revocred_flutter/core/config/app_config.dart';
import 'package:revocred_flutter/core/data/mock_app_repository.dart';
import 'package:revocred_flutter/core/models/app_models.dart';
import 'package:revocred_flutter/core/router/app_router.dart';
import 'package:revocred_flutter/core/state/app_controller.dart';
import 'package:revocred_flutter/core/state/theme_controller.dart';

class _SignedInRepository extends MockAppRepository {
  @override
  bool get isAuthenticated => true;
}

/// A signed-in person re-running the questionnaire must still see the cards
/// they own, already selected, or they can silently clear their own wallet.
void main() {
  testWidgets('re-running the questionnaire keeps owned cards selected', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    final catalog = CreditCard.fromApiJson({
      'id': 'freedom-unlimited',
      'name': 'Freedom Unlimited',
      'issuer': 'Chase',
      'annual_fee_cents': 0,
      'reward_rates': {'other': 1.5},
    });
    final owned = catalog.copyWith(isActive: true, walletCardId: 'w-1');
    final savedAnswers = QuestionnaireAnswers(
      lifeStage: 'adult-building',
      existingCardIds: const ['freedom-unlimited'],
      feeTolerance: 'low',
      travelScope: 'both',
      creditTier: 'good',
      monthlySpend: const {'dining': 400},
      rewardsGoal: 'travel',
    );

    final controller = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(const AppConfig(useMocks: false)),
        sharedPreferencesProvider.overrideWithValue(preferences),
        appRepositoryProvider.overrideWithValue(_SignedInRepository()),
      ],
    );
    addTearDown(controller.dispose);
    final notifier = controller.read(appControllerProvider.notifier);
    // A signed-in wallet with a saved plan, as the API would return it.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: controller,
        child: RevoCredBootstrap(
          config: const AppConfig(useMocks: false),
          repository: _SignedInRepository(),
          preferences: preferences,
        ),
      ),
    );
    notifier.state = AppState(
      isAuthenticated: true,
      isLoading: false,
      data: AppData(
        profile: const UserProfile(
          name: 'Member',
          strategy: 'S04',
          goal: 'Travel',
          topSpendCategories: 'dining',
          nextTarget: 'Freedom Unlimited',
          email: 'member@example.test',
        ),
        wallet: [owned],
        catalog: [catalog],
        roadmap: const [],
        messages: const [],
        quickPrompts: const [],
        pointsValue: 60,
        projectedYearlyValue: 300,
        questionnaireAnswers: savedAnswers,
      ),
    );
    await tester.pumpAndSettle();
    appRouter.go('/questionnaire');
    await tester.pumpAndSettle();

    // Step 1 is the life stage; step 2 lists the cards. Walk to it.
    await tester.tap(find.text('Adult and building a foundation'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('questionnaire-next')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('no-existing-cards')),
      findsOneWidget,
      reason: 'the owned-card step should be shown',
    );
    final tile = tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('existing-card-freedom-unlimited')),
    );
    expect(
      tile.value,
      isTrue,
      reason: 'a card the person owns must start selected when re-running',
    );
    // The rest of the saved answers are restored too.
  });
}
