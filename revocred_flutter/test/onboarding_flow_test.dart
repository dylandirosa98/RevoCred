import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:revocred_flutter/core/config/app_config.dart';
import 'package:revocred_flutter/core/data/api_app_repository.dart';
import 'package:revocred_flutter/core/data/app_repository.dart';
import 'package:revocred_flutter/core/data/mock_app_repository.dart';
import 'package:revocred_flutter/core/data/onboarding_draft_store.dart';
import 'package:revocred_flutter/core/models/app_models.dart';
import 'package:revocred_flutter/core/state/app_controller.dart';

const answers = QuestionnaireAnswers(
  lifeStage: 'adult',
  existingCardIds: ['owned'],
  feeTolerance: 'none',
  travelScope: 'none',
  creditTier: 'good',
  monthlySpend: {
    'dining': 300,
    'groceries': 450,
    'gas': 120,
    'travel': 50,
    'streaming': 25,
    'other': 200,
  },
  rewardsGoal: 'cash_back',
);

Map<String, dynamic> planJson({bool saved = false}) => {
  'profile': {
    'display_name': 'Member',
    'credit_card_strategy': saved ? 'S03' : '',
  },
  'catalog': [
    {'id': 'owned', 'name': 'Owned card'},
    {'id': 'next', 'name': 'Next card'},
  ],
  'wallet': [
    if (saved)
      {
        'id': 'wallet',
        'status': 'active',
        'card': {'id': 'owned', 'name': 'Owned card'},
      },
  ],
  if (saved) 'latest_questionnaire': answers.toRecommendationJson(),
  if (saved)
    'latest_recommendations': {
      'strategy_code': 'S03',
      'items': [
        {
          'card_id': 'next',
          'card_name': 'Next card',
          'reasons': ['Fits your spending.'],
        },
      ],
    },
};

class PreviewRepository extends MockAppRepository {
  bool authenticated = false;
  String email = 'member@example.test';
  QuestionnaireAnswers? saved;
  int saves = 0;
  bool failSave = false;
  @override
  bool get isAuthenticated => authenticated;
  @override
  String? get accountEmail => authenticated ? email : null;
  @override
  Future<AuthResult> signUp(String email, String password) async {
    this.email = email;
    return const AuthResult(success: true, message: 'Confirm email.');
  }

  @override
  Future<AppData> loadAppData() async => AppData.fromApiJson(
    planJson(saved: saved != null),
    messages: [],
    email: email,
  );
  @override
  Future<AppData> previewQuestionnaire(QuestionnaireAnswers input) async =>
      AppData.fromApiJson(
        planJson(saved: true),
        messages: [],
        email: '',
      ).copyWith(isPersonalPreview: true);
  @override
  Future<DemoRecommendation?> saveQuestionnaire(
    QuestionnaireAnswers input,
  ) async {
    saves++;
    if (failSave) throw StateError('offline');
    saved = input;
    return null;
  }
}

ProviderContainer containerFor(
  PreviewRepository repo,
  OnboardingDraftStore drafts,
) => ProviderContainer(
  overrides: [
    appConfigProvider.overrideWithValue(const AppConfig(useMocks: false)),
    appRepositoryProvider.overrideWithValue(repo),
    onboardingDraftStoreProvider.overrideWithValue(drafts),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'guest plan survives email confirmation and saves selected wallet once',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = PreviewRepository();
      var container = containerFor(repo, OnboardingDraftStore(prefs));
      final controller = container.read(appControllerProvider.notifier);
      await controller.completeQuestionnaire(answers);
      expect(repo.saves, 0);
      expect(
        container.read(appControllerProvider).data!.isPersonalPreview,
        isTrue,
      );
      await controller.signUp('member@example.test', 'longpassword123');
      container.dispose();
      repo.authenticated = true;
      final drafts = OnboardingDraftStore(prefs);
      container = containerFor(repo, drafts);
      addTearDown(container.dispose);
      final restored = container.read(appControllerProvider.notifier);
      await Future.wait([restored.initialize(), restored.refresh()]);
      expect(repo.saves, 1);
      expect(repo.saved!.existingCardIds, ['owned']);
      expect(repo.saved!.monthlySpend['groceries'], 450);
      expect(
        container.read(appControllerProvider).data!.wallet.single.id,
        'owned',
      );
      expect(
        container.read(appControllerProvider).data!.isPersonalPreview,
        isFalse,
      );
      expect(drafts.answers, isNull);
    },
  );
  test(
    'draft never imports into a different email or overwrites a saved plan',
    () async {
      for (final hasSaved in [false, true]) {
        final drafts = OnboardingDraftStore();
        await drafts.save(answers, email: 'member@example.test');
        final repo = PreviewRepository()
          ..authenticated = true
          ..email = (hasSaved ? 'member@example.test' : 'other@example.test')
          ..saved = (hasSaved ? answers : null);
        final container = containerFor(repo, drafts);
        await container.read(appControllerProvider.notifier).initialize();
        expect(repo.saves, 0);
        container.dispose();
      }
    },
  );
  test('failed import retains the draft for a safe retry', () async {
    final drafts = OnboardingDraftStore();
    await drafts.save(answers, email: 'member@example.test');
    final repo = PreviewRepository()
      ..authenticated = true
      ..failSave = true;
    final container = containerFor(repo, drafts);
    addTearDown(container.dispose);
    final controller = container.read(appControllerProvider.notifier);
    await controller.initialize();
    expect(container.read(appControllerProvider).error, isNotNull);
    expect(drafts.answers, isNotNull);
    repo.failSave = false;
    await controller.refresh();
    expect(drafts.answers, isNull);
  });
  test(
    'API preview is anonymous and saving uses atomic onboarding endpoint',
    () async {
      final paths = <String>[];
      final repo = ApiAppRepository(
        baseUrl: 'https://api.example.test',
        supabaseClient: null,
        accessTokenProvider: () => 'test-token',
        httpClient: MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path == '/v1/public/plan') {
            expect(request.headers.containsKey('Authorization'), isFalse);
            expect(jsonDecode(request.body)['existing_card_ids'], ['owned']);
            return http.Response(
              jsonEncode({'data': planJson(saved: true)}),
              200,
            );
          }
          expect(request.headers['Authorization'], 'Bearer test-token');
          return http.Response('{"data":{"items":[]}}', 201);
        }),
      );
      expect(
        (await repo.previewQuestionnaire(answers)).isPersonalPreview,
        isTrue,
      );
      expect(await repo.saveQuestionnaire(answers), isNull);
      expect(paths, ['/v1/public/plan', '/v1/onboarding']);
    },
  );
}
