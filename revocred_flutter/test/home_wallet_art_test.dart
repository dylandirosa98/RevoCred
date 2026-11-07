import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/app.dart';
import 'package:revocred_flutter/core/config/app_config.dart';
import 'package:revocred_flutter/core/data/mock_app_repository.dart';
import 'package:revocred_flutter/core/router/app_router.dart';
import 'package:revocred_flutter/core/state/app_controller.dart';
import 'package:revocred_flutter/core/state/theme_controller.dart';
import 'package:revocred_flutter/core/theme/app_theme.dart';
import 'package:revocred_flutter/features/home/presentation/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _screenshotKey = ValueKey('home-wallet-screenshot');
const _artSize = Size(2400, 1512);

void main() {
  setUpAll(() async {
    // Use the app's actual font metrics and readable screenshots, not Ahem.
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final family in ['SpaceGrotesk', 'Fraunces', 'IBMPlexMono']) {
      final loader = FontLoader(family)
        ..addFont(
          rootBundle.load(
            'assets/fonts/${switch (family) {
              'IBMPlexMono' => 'IBMPlexMono-Regular',
              _ => family,
            }}.ttf',
          ),
        );
      await loader.load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets('Use now shows artwork without duplicate painted lettering', (
    tester,
  ) async {
    _phone(tester);
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
    final hero = find.byKey(const ValueKey('decision-recommended-card'));
    expect(hero, findsOneWidget);
    expect(
      find.descendant(of: hero, matching: find.byType(Text)),
      findsNothing,
      reason: 'The illustration already contains its own lettering.',
    );
    final illustration = find.descendant(
      of: hero,
      matching: find.byWidgetPredicate(_isSharedArt),
    );
    expect(illustration, findsOneWidget);
    expect(tester.widget<Image>(illustration).fit, BoxFit.contain);
    expect(
      find.byKey(const ValueKey('decision-purchase-earn-label')),
      findsOneWidget,
      reason: 'Keep the live earning rate outside the illustration.',
    );
    expect(tester.takeException(), isNull);
  });

  for (final variant in availableAppThemeVariants) {
    testWidgets('actual Home wallet shows full artwork in ${variant.name}', (
      tester,
    ) async {
      _phone(tester);
      SharedPreferences.setMockInitialValues({
        themePreferenceKey: variant.name,
      });
      final prefs = await SharedPreferences.getInstance();
      appRouter.go('/home');
      await tester.pumpWidget(
        RepaintBoundary(
          key: _screenshotKey,
          child: RevoCredBootstrap(
            config: const AppConfig(useMocks: true),
            repository: MockAppRepository(),
            preferences: prefs,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final carousel = find.byKey(const ValueKey('decision-wallet-cards'));
      await tester.ensureVisible(carousel);
      await tester.pumpAndSettle();
      _expectFullArtwork(tester, carousel);
      expect(tester.takeException(), isNull);
      await _screenshot(tester, variant.name);
    });
  }

  // Legacy themes are no longer selectable, but Home still implements all of
  // their hero treatments. Keep the current product tokens and exercise every
  // Home branch, rather than certifying retired themes' unrelated layout.
  for (final treatment in HeroTreatment.values) {
    testWidgets('Home ${treatment.name} shows full wallet artwork', (
      tester,
    ) async {
      _phone(
        tester,
        textScale:
            [
              HeroTreatment.wallet,
              HeroTreatment.walletStudio,
            ].contains(treatment)
            ? 1.6
            : 1,
      );
      final theme = AppTheme.decisionFlow;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(
              const AppConfig(useMocks: true),
            ),
            appRepositoryProvider.overrideWithValue(MockAppRepository()),
          ],
          child: MaterialApp(
            theme: theme.copyWith(
              extensions: [
                theme.extension<ProductTheme>()!.copyWith(
                  heroTreatment: treatment,
                ),
              ],
            ),
            home: const Scaffold(body: HomeScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final carouselKey = switch (treatment) {
        HeroTreatment.decision => 'decision-wallet-cards',
        HeroTreatment.walletStudio => 'wallet-studio-cards',
        HeroTreatment.wallet => 'wallet-flow-cards',
        _ => null,
      };
      if (carouselKey != null) {
        final carousel = find.byKey(ValueKey(carouselKey));
        await tester.ensureVisible(carousel);
        await tester.pumpAndSettle();
        _expectFullArtwork(tester, carousel);
        // Check later tiles too: lazy carousels must not conceal an overflow.
        await tester.drag(carousel, const Offset(-220, 0));
        await tester.pumpAndSettle();
        _expectFullArtwork(tester, carousel);
      } else {
        final illustrations = find.byWidgetPredicate(_isSharedArt);
        expect(illustrations, findsWidgets);
        for (final image in tester.widgetList<Image>(illustrations)) {
          expect(image.fit, BoxFit.contain);
        }
      }
      final error = tester.takeException();
      if (carouselKey == null && error != null) {
        // The retired stack layouts wrap their value ExpansionTile in AppPanel.
        // Flutter warns about invisible ink, unrelated to card layout. Keep
        // that existing issue out of this fix, but never swallow overflows or
        // any other framework error.
        expect(error, isA<FlutterError>());
        expect(
          error.toString(),
          startsWith(
            'ListTile background color or ink splashes may be invisible.',
          ),
        );
      } else {
        expect(error, isNull);
      }
    });
  }

  for (final variant in availableAppThemeVariants) {
    for (final scale in [1.6, 2.0]) {
      testWidgets('Home ${variant.name} wallet fits 320px at ${scale}x text', (
        tester,
      ) async {
        _phone(tester, width: 320);
        SharedPreferences.setMockInitialValues({
          themePreferenceKey: variant.name,
        });
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
        final carousel = find.byKey(const ValueKey('decision-wallet-cards'));
        final normalHeight = tester.getSize(carousel).height;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        await tester.pumpAndSettle();
        await tester.ensureVisible(carousel);
        await tester.pumpAndSettle();
        expect(tester.getSize(carousel).height, greaterThan(normalHeight));
        _expectFullArtwork(tester, carousel);
        await tester.drag(carousel, const Offset(-220, 0));
        await tester.pumpAndSettle();
        _expectFullArtwork(tester, carousel);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

void _phone(WidgetTester tester, {double width = 390, double textScale = 1}) {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

bool _isSharedArt(Widget widget) =>
    widget is Image &&
    widget.image is AssetImage &&
    (widget.image as AssetImage).assetName.startsWith('assets/images/cards/');

void _expectFullArtwork(WidgetTester tester, Finder carousel) {
  final illustrations = find.descendant(
    of: carousel,
    matching: find.byWidgetPredicate(_isSharedArt),
  );
  expect(illustrations, findsWidgets);
  for (final element in illustrations.evaluate()) {
    final imageFinder = find.byWidget(element.widget);
    final image = element.widget as Image;
    final bounds = tester.getRect(imageFinder);
    final fit = applyBoxFit(
      image.fit ?? BoxFit.scaleDown,
      _artSize,
      bounds.size,
    );
    expect(
      fit.source,
      _artSize,
      reason: 'Home must display the entire shared illustration, not a crop.',
    );
    expect(image.fit, BoxFit.contain);
    expect(bounds.width / bounds.height, closeTo(2400 / 1512, .001));
    expect(bounds.height, greaterThan(88), reason: 'Do not use a tiny strip.');
    final tile = find
        .ancestor(of: imageFinder, matching: find.byType(InkWell))
        .first;
    final labels = find.descendant(of: tile, matching: find.byType(Text));
    expect(labels, findsWidgets);
    final tileBounds = tester.getRect(tile);
    expect(
      bounds.top - tileBounds.top,
      greaterThanOrEqualTo(10),
      reason: 'Keep the full image inset below the tile edge, not shifted up.',
    );
    expect(bounds.left - tileBounds.left, greaterThanOrEqualTo(10));
    expect(tileBounds.right - bounds.right, greaterThanOrEqualTo(10));
    for (final label in labels.evaluate()) {
      final labelBounds = tester.getRect(find.byWidget(label.widget));
      expect(
        labelBounds.top,
        greaterThanOrEqualTo(bounds.bottom),
        reason: 'Labels belong below the illustration, not over its own text.',
      );
      expect(labelBounds.bottom, lessThanOrEqualTo(tileBounds.bottom));
    }
  }
}

Future<void> _screenshot(WidgetTester tester, String name) async {
  const directory = String.fromEnvironment('HOME_WALLET_SCREENSHOT_DIR');
  if (directory.isEmpty) return;
  // Asset decoding and image readback need real asynchronous work in a widget
  // test. Capture the actual routed Home after scrolling its wallet into view.
  await tester.runAsync(() async {
    for (final element in find.byWidgetPredicate(_isSharedArt).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_screenshotKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File(
      '$directory/home-wallet-$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
