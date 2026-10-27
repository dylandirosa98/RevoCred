import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/core/config/app_config.dart';
import 'package:revocred_flutter/core/data/app_repository.dart';
import 'package:revocred_flutter/core/data/mock_app_repository.dart';
import 'package:revocred_flutter/core/data/onboarding_draft_store.dart';
import 'package:revocred_flutter/core/models/app_models.dart';
import 'package:revocred_flutter/core/state/app_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SessionRepository extends MockAppRepository {
  final sessions = StreamController<AccountSession>.broadcast(sync: true);
  final loaded = Completer<AppData>();
  bool delayLoad = false;
  bool authenticated = true;

  @override
  bool get isAuthenticated => authenticated;

  @override
  Stream<AccountSession> get sessionChanges => sessions.stream;

  @override
  Future<AppData> loadAppData() =>
      delayLoad ? loaded.future : super.loadAppData();
}

void main() {
  late _SessionRepository repository;
  late ProviderContainer container;
  late OnboardingDraftStore drafts;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    drafts = OnboardingDraftStore(await SharedPreferences.getInstance());
    repository = _SessionRepository();
    container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(const AppConfig(useMocks: false)),
        appRepositoryProvider.overrideWithValue(repository),
        onboardingDraftStoreProvider.overrideWithValue(drafts),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await repository.sessions.close();
  });

  test(
    'expired session removes the locally persisted personal draft',
    () async {
      final controller = container.read(appControllerProvider.notifier);
      await controller.initialize();
      await drafts.save(
        QuestionnaireAnswers(
          lifeStage: 'adult',
          existingCardIds: const [],
          feeTolerance: 'low',
          travelScope: 'none',
          creditTier: 'good',
          monthlySpend: const {'dining': 800},
          rewardsGoal: 'cash_back',
        ),
        email: 'private@example.test',
      );
      repository.sessions.add(const AccountSession(authenticated: false));
      await Future<void>.delayed(Duration.zero);
      expect(drafts.answers, isNull);
      expect(drafts.email, isNull);
    },
  );

  test('initial guest session preserves confirmation handoff draft', () async {
    repository.authenticated = false;
    final controller = container.read(appControllerProvider.notifier);
    await controller.initialize();
    await drafts.save(
      QuestionnaireAnswers(
        lifeStage: 'adult',
        existingCardIds: const [],
        feeTolerance: 'low',
        travelScope: 'none',
        creditTier: 'good',
        monthlySpend: const {'dining': 800},
        rewardsGoal: 'cash_back',
      ),
      email: 'private@example.test',
    );
    repository.sessions.add(const AccountSession(authenticated: false));
    await Future<void>.delayed(Duration.zero);
    expect(drafts.answers, isNotNull);
    expect(drafts.email, 'private@example.test');
  });

  test(
    'name refresh completing after logout cannot restore private data',
    () async {
      final controller = container.read(appControllerProvider.notifier);
      await controller.initialize();
      final privateData = container.read(appControllerProvider).data!;
      repository.delayLoad = true;
      final pending = controller.updateDisplayName('Private Member');
      await Future<void>.delayed(Duration.zero);
      await controller.signOut();
      repository.loaded.complete(privateData);
      await pending;
      final state = container.read(appControllerProvider);
      expect(state.isAuthenticated, isFalse);
      expect(state.data, isNot(same(privateData)));
      expect(state.actionMessage, isNot('Name updated.'));
    },
  );
}
