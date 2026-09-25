import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:revocred_flutter/core/config/app_config.dart';
import 'package:revocred_flutter/core/data/api_app_repository.dart';
import 'package:revocred_flutter/core/data/app_repository.dart';
import 'package:revocred_flutter/core/data/demo_seed.dart';
import 'package:revocred_flutter/core/data/mock_app_repository.dart';
import 'package:revocred_flutter/core/models/app_models.dart';
import 'package:revocred_flutter/core/state/app_controller.dart';

const answers = QuestionnaireAnswers(
  lifeStage: 'adult',
  existingCardIds: [],
  feeTolerance: '0',
  travelScope: 'none',
  creditTier: 'good',
  monthlySpend: {'other': 100},
  rewardsGoal: 'cash_back',
);

class _SessionRepository extends MockAppRepository {
  final events = StreamController<AccountSession>.broadcast();
  Completer<AppData>? pending;
  @override
  Stream<AccountSession> get sessionChanges => events.stream;
  @override
  Future<AppData> loadAppData() =>
      pending?.future ?? Future.value(createDemoAppData());
}

void main() {
  test('real mode never falls back to demo when no card is eligible', () async {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(const AppConfig(useMocks: false)),
        appRepositoryProvider.overrideWithValue(MockAppRepository()),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(appControllerProvider.notifier);
    await expectLater(
      controller.completeQuestionnaire(answers),
      throwsStateError,
    );
    expect(container.read(appControllerProvider).recommendation, isNull);
  });

  test(
    'sign-out event clears data and late refresh cannot restore it',
    () async {
      final repository = _SessionRepository();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(const AppConfig(useMocks: false)),
          appRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repository.events.close();
      });
      final controller = container.read(appControllerProvider.notifier);
      await controller.refresh();
      repository.pending = Completer<AppData>();
      final refresh = controller.refresh();
      repository.events.add(const AccountSession(authenticated: false));
      await Future<void>.delayed(Duration.zero);
      repository.pending!.complete(createDemoAppData());
      await refresh;
      expect(container.read(appControllerProvider).isAuthenticated, isFalse);
      expect(container.read(appControllerProvider).data, isNull);
    },
  );

  test('401 is a session error, not a raw server response', () async {
    final repository = ApiAppRepository(
      baseUrl: 'https://api.example.test',
      supabaseClient: null,
      accessTokenProvider: () => 'expired',
      httpClient: MockClient(
        (_) async => http.Response('private internal data', 401),
      ),
    );
    await expectLater(
      repository.loadAppData(),
      throwsA(isA<SessionExpiredException>()),
    );
  });

  test('production refuses mock mode and HTTP endpoints', () {
    expect(
      () => const AppConfig(useMocks: true, production: true).validate(),
      throwsStateError,
    );
    expect(
      () => const AppConfig(
        useMocks: false,
        production: true,
        apiUrl: 'http://localhost',
        supabaseUrl: 'https://example.test',
        supabaseAnonKey: 'public',
        authRedirectUrl: 'https://app.example.test',
      ).validate(),
      throwsStateError,
    );
  });
}
