import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/app.dart';
import 'package:revocred_flutter/core/config/app_config.dart';
import 'package:revocred_flutter/core/data/mock_app_repository.dart';
import 'package:revocred_flutter/core/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('home wallet preview uses the shared card illustrations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    appRouter.go('/home');
    await tester.pumpWidget(
      RevoCredBootstrap(
        config: const AppConfig(useMocks: true),
        repository: MockAppRepository(),
        preferences: prefs,
      ),
    );
    await tester.pumpAndSettle();
    bool usesSharedArt(Widget w) {
      if (w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName.startsWith(
            'assets/images/cards/',
          )) {
        return true;
      }
      final decoration = w is Container ? w.decoration : null;
      final image = decoration is BoxDecoration ? decoration.image : null;
      return image != null &&
          image.image is AssetImage &&
          (image.image as AssetImage).assetName.startsWith(
            'assets/images/cards/',
          );
    }

    expect(
      find.byWidgetPredicate(usesSharedArt),
      findsWidgets,
      reason: 'Wallet preview tiles must use the shared illustrations.',
    );
    expect(tester.takeException(), isNull);
  });
}
