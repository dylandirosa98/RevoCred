import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/core/data/demo_seed.dart';
import 'package:revocred_flutter/core/theme/app_theme.dart';
import 'package:revocred_flutter/features/strategy/presentation/report_branding.dart';
import 'package:revocred_flutter/features/strategy/presentation/strategy_roadmap_view.dart';

void main() {
  test('score meter stays circular rather than stretching to its bounds', () {
    for (final size in [
      const Size(126, 76),
      const Size(126, 90),
      const Size(200, 70),
    ]) {
      final arc = ScoreGaugePainter.arcBounds(size);
      expect(arc.width, closeTo(arc.height, .001));
      expect(arc.center.dx, size.width / 2);
      expect(arc.top, greaterThanOrEqualTo(7));
      expect(arc.center.dy, lessThan(size.height));
    }
  });
  testWidgets('mobile report centers branding and score on the same axis', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.decisionFlow,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: StrategyRoadmapView(data: createDemoAppData()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getCenter(find.byType(ReportBrand).first).dx,
      closeTo(195, .1),
    );
    expect(tester.getCenter(find.byType(ReportScore)).dx, closeTo(195, .1));
    const labels = [
      'Travel redemption uplift',
      'Target wallet cards',
      'Target annual fees',
      'Primary goal',
    ];
    final labelStarts = labels
        .map(
          (label) =>
              tester.getTopLeft(find.byKey(ValueKey('reward-label-$label'))).dx,
        )
        .toList();
    final valueEnds = labels
        .map(
          (label) => tester
              .getTopRight(find.byKey(ValueKey('reward-value-$label')))
              .dx,
        )
        .toList();
    for (var i = 1; i < labels.length; i++) {
      expect(labelStarts[i], labelStarts.first);
      expect(valueEnds[i], valueEnds.first);
    }
    final goalBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('reward-label-Primary goal')))
        .dy;
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('strategy-net-value'))).dy,
      greaterThan(goalBottom),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('portrait report renders the reference visual hierarchy', (
    tester,
  ) async {
    tester.view.physicalSize = Size(
      double.parse(Platform.environment['REVOCRED_SCREEN_WIDTH'] ?? '1024'),
      2300,
    );
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const key = ValueKey('report-visual-capture');
    final fonts = {
      'Anton': 'assets/fonts/Anton-Regular.ttf',
      'SpaceGrotesk': 'assets/fonts/SpaceGrotesk.ttf',
    };
    for (final entry in fonts.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot != null) {
      await tester.runAsync(() async {
        final material = File(
          '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        );
        await (FontLoader('MaterialIcons')..addFont(
              material.readAsBytes().then(
                (bytes) => ByteData.sublistView(bytes),
              ),
            ))
            .load();
      });
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.decisionFlow,
        home: Scaffold(
          body: SingleChildScrollView(
            child: RepaintBoundary(
              key: key,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(24),
                child: StrategyRoadmapView(data: createDemoAppData()),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pumpAndSettle();
    expect(find.byType(ReportScore), findsOneWidget);
    expect(find.text('APPLICATION TIMELINE'), findsOneWidget);
    expect(find.text('HOW THEY WORK TOGETHER'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final path = Platform.environment['REVOCRED_SCREEN_PREVIEW'];
    if (path != null) {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(key),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(path).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
