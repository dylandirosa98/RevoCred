import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/core/data/demo_seed.dart';
import 'package:revocred_flutter/core/services/strategy_report_export.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('strategy report export builds a real PDF', () async {
    final bytes = await buildStrategyReportPdf(createDemoAppData());

    expect(bytes.length, greaterThan(5000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
