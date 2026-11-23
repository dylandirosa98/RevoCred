import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/core/services/pwa_install.dart';
import 'package:revocred_flutter/core/state/theme_controller.dart';
import 'package:revocred_flutter/core/theme/app_theme.dart';
import 'package:revocred_flutter/shared/widgets/pwa_install_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePwaInstallClient implements PwaInstallClient {
  _FakePwaInstallClient(this.status, {this.acceptPrompt = true});

  PwaInstallStatus status;
  final bool acceptPrompt;
  int promptCalls = 0;
  final controller = StreamController<PwaInstallStatus>.broadcast();

  @override
  PwaInstallStatus readStatus() => status;

  @override
  Stream<PwaInstallStatus> get statusChanges => controller.stream;

  @override
  Future<bool> promptInstall() async {
    promptCalls++;
    return acceptPrompt;
  }
}

Future<void> _pumpBanner(
  WidgetTester tester, {
  required _FakePwaInstallClient client,
  Map<String, Object> initialPrefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(initialPrefs);
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pwaInstallClientProvider.overrideWithValue(client),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp(
        theme: AppTheme.decisionFlow,
        home: const Scaffold(body: PwaInstallBanner()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('hides banner on desktop or already-standalone PWA', (
    tester,
  ) async {
    for (final status in const [
      PwaInstallStatus.unsupported(),
      PwaInstallStatus(
        isMobileBrowser: false,
        isStandalone: false,
        canPrompt: true,
        isIos: false,
      ),
      PwaInstallStatus(
        isMobileBrowser: true,
        isStandalone: true,
        canPrompt: false,
        isIos: true,
      ),
    ]) {
      final client = _FakePwaInstallClient(status);
      addTearDown(client.controller.close);
      await _pumpBanner(tester, client: client);
      expect(find.byKey(const ValueKey('pwa-install-banner')), findsNothing);
    }
  });

  testWidgets(
    'shows native install prompt on Chromium mobile and hides on accept',
    (tester) async {
      final client = _FakePwaInstallClient(
        const PwaInstallStatus(
          isMobileBrowser: true,
          isStandalone: false,
          canPrompt: true,
          isIos: false,
        ),
      );
      addTearDown(client.controller.close);

      await _pumpBanner(tester, client: client);
      expect(find.text('Install RevoCred'), findsOneWidget);
      expect(find.byKey(const ValueKey('pwa-install-button')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('pwa-install-button')));
      await tester.pumpAndSettle();

      expect(client.promptCalls, 1);
      expect(find.byKey(const ValueKey('pwa-install-banner')), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(pwaInstallHintDismissedKey), isTrue);
    },
  );

  testWidgets('keeps banner visible if native install prompt is cancelled', (
    tester,
  ) async {
    final client = _FakePwaInstallClient(
      const PwaInstallStatus(
        isMobileBrowser: true,
        isStandalone: false,
        canPrompt: true,
        isIos: false,
      ),
      acceptPrompt: false,
    );
    addTearDown(client.controller.close);

    await _pumpBanner(tester, client: client);
    await tester.tap(find.byKey(const ValueKey('pwa-install-button')));
    await tester.pumpAndSettle();

    expect(client.promptCalls, 1);
    expect(find.byKey(const ValueKey('pwa-install-banner')), findsOneWidget);
  });

  testWidgets(
    'shows Safari Add to Home Screen guidance on iOS and remembers dismissal',
    (tester) async {
      final client = _FakePwaInstallClient(
        const PwaInstallStatus(
          isMobileBrowser: true,
          isStandalone: false,
          canPrompt: false,
          isIos: true,
        ),
      );
      addTearDown(client.controller.close);

      await _pumpBanner(tester, client: client);
      expect(find.text('Install RevoCred'), findsOneWidget);
      expect(find.textContaining('Add to Home Screen'), findsOneWidget);
      expect(find.byKey(const ValueKey('pwa-install-button')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('pwa-install-dismiss')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('pwa-install-banner')), findsNothing);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(pwaInstallHintDismissedKey), isTrue);
    },
  );

  testWidgets('stays hidden when previously dismissed', (tester) async {
    final client = _FakePwaInstallClient(
      const PwaInstallStatus(
        isMobileBrowser: true,
        isStandalone: false,
        canPrompt: true,
        isIos: false,
      ),
    );
    addTearDown(client.controller.close);

    await _pumpBanner(
      tester,
      client: client,
      initialPrefs: {pwaInstallHintDismissedKey: true},
    );
    expect(find.byKey(const ValueKey('pwa-install-banner')), findsNothing);
  });
}
