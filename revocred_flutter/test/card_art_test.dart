import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/core/data/demo_seed.dart';
import 'package:revocred_flutter/core/logic/card_art.dart';
import 'package:revocred_flutter/core/logic/card_art_catalog.dart';
import 'package:revocred_flutter/core/theme/app_theme.dart';
import 'package:revocred_flutter/shared/widgets/credit_card_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('reference cards have distinct artwork based on names, not API ids', () {
    expect(
      cardArtAssetForName('Citi Double Cash'),
      endsWith('/citi-doublecash.png'),
    );
    expect(
      cardArtAssetForName('Chase Freedom Flex'),
      endsWith('/chase-freedomflex.png'),
    );
    expect(
      cardArtAssetForName('Chase Sapphire Preferred'),
      endsWith('/chase-sapphirepreferred.png'),
    );
    expect(
      cardArtAssetForName('Citi Strata Premier'),
      endsWith('/citi-stratapremier.png'),
    );
    expect(cardArtAssetForName('My custom card'), endsWith('/generic.png'));
    expect(
      cardArtAssetForName('Platinum', issuer: 'My bank'),
      endsWith('/generic.png'),
    );
    expect(
      cardArtAssetForName('Capital One Platinum'),
      endsWith('/capitalone-platinum.png'),
    );
  });

  test(
    'every catalog identity has a dedicated high-resolution asset',
    () async {
      final paths = <String>{};
      for (final entry in cardArtCatalog.entries) {
        for (final name in entry.value) {
          final path = cardArtAssetForName(name, issuer: entry.key);
          expect(
            path,
            isNot(endsWith('/generic.png')),
            reason: '${entry.key}: $name',
          );
          expect(paths.add(path), isTrue, reason: 'Two products share $path');
          final bytes = await rootBundle.load(path);
          expect(bytes.getUint32(16), 2400, reason: path);
          expect(bytes.getUint32(20), 1512, reason: path);
        }
      }
      expect(paths.length, greaterThanOrEqualTo(88));
      expect(
        cardArtAssetForName('Platinum', issuer: 'Capital One'),
        isNot(cardArtAssetForName('Platinum', issuer: 'American Express')),
      );
      expect(
        cardArtAssetForName('One Key+', issuer: 'Wells Fargo'),
        isNot(cardArtAssetForName('One Key', issuer: 'Wells Fargo')),
      );
    },
  );

  test('issuer catalog and searchable seed rows cannot lose artwork coverage', () {
    final referenceRows = RegExp(
      r"""\(\s*'[^']+',\s*'((?:''|[^'])*)',\s*'((?:''|[^'])*)',\s*'(?:Unknown|Visa|Mastercard|Discover|American Express)'""",
      caseSensitive: false,
    );
    final primaryRows = RegExp(
      r"""\(\s*'20000000[^']+',\s*'[^']+',\s*'([^']+)',\s*'[^']+',\s*'([^']+)'\)""",
    );
    var checked = 0;
    for (final file in Directory(
      '../revocred-api/migrations',
    ).listSync().whereType<File>()) {
      final sql = file.readAsStringSync();
      final rows = sql.contains('INSERT INTO revocred.card_reference_index')
          ? referenceRows.allMatches(sql)
          : primaryRows.allMatches(sql);
      for (final row in rows) {
        final issuer = row.group(1)!.replaceAll("''", "'");
        final name = row.group(2)!.replaceAll("''", "'");
        if (issuer.startsWith('Demo Bank')) continue;
        expect(
          cardArtCatalog[issuer],
          contains(name),
          reason: '${file.path}: $issuer / $name needs dedicated art',
        );
        checked++;
      }
    }
    expect(checked, greaterThan(70));
  });

  testWidgets('small category cards retain their illustrated faces', (
    tester,
  ) async {
    final card = demoCatalog.firstWhere((card) => card.id == 'freedom-flex');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.decisionFlow,
        home: Scaffold(body: CreditCardArt(card: card, width: 85, height: 54)),
      ),
    );
    await tester.pumpAndSettle();
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, cardArtAsset(card));
    expect(tester.takeException(), isNull);
  });
}
