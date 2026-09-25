import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/core/data/demo_seed.dart';
import 'package:revocred_flutter/core/models/affiliate_offer.dart';
import 'package:revocred_flutter/core/services/strategy_report_export.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('strategy report export builds a real PDF', () async {
    final bytes = await buildStrategyReportPdf(createDemoAppData());

    expect(bytes.length, greaterThan(5000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
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
