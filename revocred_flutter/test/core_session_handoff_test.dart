import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:revocred_flutter/core/config/app_config.dart';
import 'package:revocred_flutter/core/data/app_repository.dart';
import 'package:revocred_flutter/core/data/mock_app_repository.dart';
import 'package:revocred_flutter/core/data/onboarding_draft_store.dart';
import 'package:revocred_flutter/core/data/demo_seed.dart';
import 'package:revocred_flutter/core/models/app_models.dart';
import 'package:revocred_flutter/core/state/app_controller.dart';

const answers = QuestionnaireAnswers(
  lifeStage: 'adult',
  existingCardIds: [],
  feeTolerance: 'none',
  travelScope: 'none',
  creditTier: 'good',
  monthlySpend: {'other': 100},
  rewardsGoal: 'cash_back',
);

class Sessions extends MockAppRepository {
  final events = StreamController<AccountSession>.broadcast(sync: true);
  String email = 'a@example.test';
  Completer<void>? mutation;
  Completer<void>? logout;
  Completer<void>? password;
  @override
  Future<void> signOut() => logout?.future ?? super.signOut();
  @override
  Future<void> updatePassword(String value) =>
      password?.future ?? super.updatePassword(value);
  Completer<AppData>? load;
  bool rejectExpired = false;
  @override
  String? get accountEmail => email;
  @override
  Stream<AccountSession> get sessionChanges => events.stream;
  @override
  Future<DemoRecommendation?> saveQuestionnaire(
    QuestionnaireAnswers answers,
  ) async => null;
  int loads = 0;
  @override
  Future<AppData> loadAppData() {
    loads++;
    return rejectExpired
        ? Future.error(const SessionExpiredException())
        : load?.future ?? Future.value(createDemoAppData());
  }

  @override
  Future<void> addCard(String id) => mutation?.future ?? Future.value();
  @override
  Future<void> addCustomCard(CustomCardDraft card) =>
      mutation?.future ?? Future.value();
  @override
  Future<void> removeCard(String id) => mutation?.future ?? Future.value();
  @override
  Future<void> switchStrategy(String value) =>
      mutation?.future ?? Future.value();
}

void main() {
  test(
    'old questionnaire refresh cannot put answers in switched account',
    () async {
      final repo = Sessions();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(const AppConfig(useMocks: false)),
          appRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repo.events.close();
      });
      final controller = container.read(appControllerProvider.notifier);
      await controller.initialize();
      final old = Completer<AppData>();
      repo.load = old;
      final pending = controller.completeQuestionnaire(answers);
      final expectation = expectLater(
        pending,
        throwsA(isA<SessionExpiredException>()),
      );
      await Future<void>.delayed(Duration.zero);
      repo.email = 'b@example.test';
      repo.load = null;
      repo.events.add(const AccountSession(authenticated: true));
      await controller.refresh();
      old.complete(createDemoAppData());
      await expectation;
      expect(
        container.read(appControllerProvider).data?.questionnaireAnswers,
        isNull,
      );
    },
  );
  for (final operation in ['strategy', 'password']) {
    test(
      'stale $operation completion cannot write into switched account',
      () async {
        final repo = Sessions()
          ..mutation = Completer<void>()
          ..password = Completer<void>();
        final container = ProviderContainer(
          overrides: [
            appConfigProvider.overrideWithValue(
              const AppConfig(useMocks: false),
            ),
            appRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await repo.events.close();
        });
        final controller = container.read(appControllerProvider.notifier);
        await controller.initialize();
        final pending = operation == 'strategy'
            ? controller.switchStrategy('cash_back')
            : controller.finishPasswordRecovery('password123');
        repo.email = 'b@example.test';
        repo.events.add(
          AccountSession(
            authenticated: true,
            passwordRecovery: operation == 'password',
          ),
        );
        await controller.refresh();
        final loads = repo.loads;
        repo.mutation!.complete();
        repo.password!.complete();
        await pending;
        expect(repo.loads, loads);
        expect(
          container.read(appControllerProvider).passwordRecovery,
          operation == 'password',
        );
        expect(container.read(appControllerProvider).actionMessage, isNull);
      },
    );
  }
  test('normal SDK signin clears recovery routing for same account', () async {
    final repo = Sessions();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(const AppConfig(useMocks: false)),
        appRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await repo.events.close();
    });
    await container.read(appControllerProvider.notifier).initialize();
    repo.events.add(
      const AccountSession(authenticated: true, passwordRecovery: true),
    );
    expect(container.read(appControllerProvider).passwordRecovery, isTrue);
    repo.events.add(const AccountSession(authenticated: true));
    expect(container.read(appControllerProvider).passwordRecovery, isFalse);
  });
  test('old JWT rejection does not sign out SDK refreshed session', () async {
    final repo = Sessions();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(const AppConfig(useMocks: false)),
        appRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await repo.events.close();
    });
    final controller = container.read(appControllerProvider.notifier);
    await controller.initialize();
    repo.rejectExpired = true;
    await controller.refresh();
    expect(container.read(appControllerProvider).isAuthenticated, isTrue);
  });
  test('late logout cannot clear a subsequently signed in account', () async {
    final repo = Sessions()..logout = Completer<void>();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(const AppConfig(useMocks: false)),
        appRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await repo.events.close();
    });
    final controller = container.read(appControllerProvider.notifier);
    await controller.initialize();
    final pending = controller.signOut();
    repo.events.add(const AccountSession(authenticated: false));
    repo.email = 'b@example.test';
    repo.events.add(const AccountSession(authenticated: true));
    await controller.refresh();
    repo.logout!.complete();
    await pending;
    expect(container.read(appControllerProvider).isAuthenticated, isTrue);
  });
  test(
    'transient SDK auth stream errors do not escape or discard session',
    () async {
      final repo = Sessions();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(const AppConfig(useMocks: false)),
          appRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repo.events.close();
      });
      await container.read(appControllerProvider.notifier).initialize();
      repo.events.addError(StateError('temporary auth network outage'));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(appControllerProvider).isAuthenticated, isTrue);
    },
  );
  test(
    'bound confirmation draft cannot be reassigned on another login',
    () async {
      final draft = OnboardingDraftStore();
      await draft.save(answers, email: 'a@example.test');
      await draft.saveName('Avery');
      await draft.bind('b@example.test');
      expect(draft.email, 'a@example.test');
      expect(draft.answers?.displayName, 'Avery');
    },
  );
  test('same email binding preserves registration name', () async {
    final draft = OnboardingDraftStore();
    await draft.save(answers);
    await draft.saveName('Avery');
    await draft.bind(' A@example.test ');
    expect(draft.email, 'a@example.test');
    expect(draft.answers?.displayName, 'Avery');
  });
  test(
    'authenticated account switch invalidates old refresh and mutation',
    () async {
      final repo = Sessions();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(const AppConfig(useMocks: false)),
          appRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repo.events.close();
      });
      final controller = container.read(appControllerProvider.notifier);
      await controller.initialize();
      final generation = controller.sessionGeneration;
      final old = Completer<AppData>();
      repo.load = old;
      final pending = controller.refresh();
      repo.mutation = Completer<void>();
      final mutation = controller.addCard('old-card');
      repo.email = 'b@example.test';
      repo.load = null;
      repo.events.add(const AccountSession(authenticated: true));
      await Future<void>.delayed(Duration.zero);
      expect(controller.sessionGeneration, greaterThan(generation));
      old.complete(createDemoAppData().copyWith(isPersonalPreview: true));
      repo.mutation!.complete();
      await pending;
      await mutation;
      final state = container.read(appControllerProvider);
      expect(state.data?.isPersonalPreview, isFalse);
      expect(state.actionMessage, isNot('Card added to your wallet.'));
    },
  );
}
