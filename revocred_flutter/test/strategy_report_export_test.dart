import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/core/data/demo_seed.dart';
import 'package:revocred_flutter/core/models/affiliate_offer.dart';
import 'package:revocred_flutter/core/services/strategy_report_export.dart';
import 'package:revocred_flutter/core/logic/playbook.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('strategy report export builds a real PDF', () async {
    final bytes = await buildStrategyReportPdf(createDemoAppData());

    expect(bytes.length, greaterThan(5000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    expect(
      RegExp(r'/Type\s*/Page\b').allMatches(String.fromCharCodes(bytes)).length,
      1,
    );
    final previewPath = Platform.environment['REVOCRED_REPORT_PREVIEW'];
    if (previewPath != null) await File(previewPath).writeAsBytes(bytes);
  });

  test('larger personalized strategies remain a single portrait page', () async {
    final base = createDemoAppData();
    for (final count in [1, 4, 7, 12]) {
      final data = base.copyWith(
        playbook: PlaybookAssignment(
          code: 'S04',
          title: 'Personal strategy',
          ecosystem: 'Chase',
          steps: List.generate(
            count,
            (i) => PlaybookStep(
              name: 'Personalized card ${i + 1}',
              use: 'Everyday rewards',
              status: i == 0 ? 'next' : 'later',
              timing: i == 0
                  ? 'Consider now, after checks'
                  : 'Wait approximately 3-6 months after the previous application',
              timingNote:
                  'Planning estimate only. Verify issuer rules and account history.',
            ),
          ),
          unused: const [],
          alternatives: const [],
        ),
      );
      final bytes = await buildStrategyReportPdf(data);
      final previewPath = Platform.environment['REVOCRED_REPORT_PREVIEW'];
      if (previewPath != null) {
        await File('$previewPath-$count.pdf').writeAsBytes(bytes);
      }
      expect(
        RegExp(
          r'/Type\s*/Page\b',
        ).allMatches(String.fromCharCodes(bytes)).length,
        1,
      );
    }
  });

  test(
    'PDF carries the revocable redirect only while the offer is current',
    () async {
      final uri = Uri.parse(
        'https://api.example.test/v1/offers/11111111-1111-4111-8111-111111111111/apply?placement=report',
      );
      for (final expired in [false, true]) {
        final bytes = await buildStrategyReportPdf(
          createDemoAppData(),
          application: ApplicationLink(
            cardName: 'Reviewed card',
            uri: uri,
            endsAt: DateTime.now().add(Duration(hours: expired ? -1 : 1)),
          ),
        );
        final pdf = String.fromCharCodes(bytes);
        // URI actions are PDF annotation dictionaries, independent of compressed page text.
        expect(pdf.contains(uri.toString()), !expired);
      }
    },
  );
}
