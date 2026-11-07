import 'package:revocred_flutter/app.dart';
import 'package:revocred_flutter/core/config/app_config.dart';
import 'package:revocred_flutter/core/data/mock_app_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/core/logic/friendly_error.dart';
import 'package:revocred_flutter/core/router/app_router.dart';

void main() {
  test('errors never disclose exception details', () {
    for (final error in [
      'SocketException https://private.example',
      'ClientException private.example',
      'TimeoutException private.example',
      'HandshakeException private.example',
      'HTTP 503 private.example',
      '401 private.example',
      '429 private.example',
      'unknown private.example',
    ]) {
      final message = friendlyError(error);
      expect(message, isNot(contains('private.example')));
      expect(message, isNot(contains('Exception')));
    }
  });

  testWidgets('unknown route provides a friendly navigation action', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      RevoCredBootstrap(
        config: const AppConfig(useMocks: true),
        repository: MockAppRepository(),
        preferences: preferences,
      ),
    );
    appRouter.go('/missing-page');
    await tester.pumpAndSettle();
    expect(find.text('Page not found'), findsOneWidget);
    expect(find.text('Go to Home'), findsOneWidget);
    appRouter.go('/');
    await tester.pumpAndSettle();
    expect(appRouter.routeInformationProvider.value.uri.path, '/home');
  });
}
