import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/app.dart';
import 'package:revocred_flutter/core/config/app_config.dart';
import 'package:revocred_flutter/core/data/mock_app_repository.dart';
import 'package:revocred_flutter/core/models/app_models.dart';
import 'package:revocred_flutter/core/router/app_router.dart';
import 'package:revocred_flutter/core/state/app_controller.dart';
import 'package:revocred_flutter/core/state/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  greetingTest();
  group('name handling', () {
    test('greeting inputs come from the profile, never a fixed name', () {
      const profile = UserProfile(
        name: 'Alex Morgan',
        strategy: 'S03',
        goal: 'Cash back',
        topSpendCategories: 'dining',
        nextTarget: 'Freedom Unlimited',
        email: 'a@example.test',
      );
      expect(profile.firstName, 'Alex');
      expect(profile.initials, 'AM');
      expect(
        const UserProfile(
          name: '',
          strategy: '',
          goal: '',
          topSpendCategories: '',
          nextTarget: '',
          email: '',
        ).initials,
        isEmpty,
      );
      expect(
        const UserProfile(
          name: 'María Fernández',
          strategy: '',
          goal: '',
          topSpendCategories: '',
          nextTarget: '',
          email: '',
        ).initials,
        'MF',
        reason: 'letters outside the basic plane must not be cut in half',
      );
      expect(
        const UserProfile(
          name: '  cher  ',
          strategy: '',
          goal: '',
          topSpendCategories: '',
          nextTarget: '',
          email: '',
        ).firstName,
        'cher',
      );
    });

    test('the name rides along with the questionnaire payload', () {
      final answers = QuestionnaireAnswers(
        lifeStage: 'adult',
        existingCardIds: const [],
        feeTolerance: 'low',
        travelScope: 'none',
        creditTier: 'good',
        monthlySpend: const {'dining': 100},
        rewardsGoal: 'cash_back',
        displayName: '  Dana  ',
      );
      final json = answers.toRecommendationJson();
      expect(json['display_name'], 'Dana');
      expect(
        QuestionnaireAnswers.fromRecommendationJson(json).displayName,
        'Dana',
      );
      // An absent name must not send an empty override.
      expect(
        QuestionnaireAnswers(
          lifeStage: 'adult',
          existingCardIds: const [],
          feeTolerance: 'low',
          travelScope: 'none',
          creditTier: 'good',
          monthlySpend: const {},
          rewardsGoal: 'cash_back',
        ).toRecommendationJson().containsKey('display_name'),
        isFalse,
      );
    });
  });

  test('a name correction reaches the API and lands in state', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = _RecordingRepository();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(const AppConfig(useMocks: false)),
        appRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(preferences),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(appControllerProvider.notifier);
    // An empty name must be rejected before any request is made.
    await expectLater(notifier.updateDisplayName('   '), throwsStateError);
    expect(repository.savedNames, isEmpty);

    await notifier.updateDisplayName('  Dana Okafor  ');
    expect(repository.savedNames, ['Dana Okafor']);
    expect(
      container.read(appControllerProvider).data!.profile.name,
      'Dana Okafor',
      reason:
          'the corrected name must show immediately, not after a later refresh',
    );
  });
}

class _RecordingRepository extends MockAppRepository {
  final savedNames = <String>[];

  @override
  Future<void> updateDisplayName(String name) async {
    savedNames.add(name);
    // Mirror the real repository so the following refresh sees the new name.
    await super.updateDisplayName(name);
  }
}

/// The greeting must come from the signed-in profile. It used to be a fixed
/// string, so every account was greeted as the same demo person.
void greetingTest() {
  testWidgets('home greets the signed-in member by name', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = _NamedRepository('Dana Okafor');
    appRouter.go('/home');

    await tester.pumpWidget(
      RevoCredBootstrap(
        config: const AppConfig(useMocks: true),
        repository: repository,
        preferences: preferences,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hello, Dana'), findsOneWidget);
    expect(find.textContaining('Alex'), findsNothing);
  });
}

class _NamedRepository extends MockAppRepository {
  _NamedRepository(this.name);
  final String name;

  @override
  Future<AppData> loadAppData() async {
    final data = await super.loadAppData();
    return data.copyWith(
      profile: UserProfile(
        name: name,
        strategy: data.profile.strategy,
        goal: data.profile.goal,
        topSpendCategories: data.profile.topSpendCategories,
        nextTarget: data.profile.nextTarget,
        email: data.profile.email,
      ),
    );
  }
}
