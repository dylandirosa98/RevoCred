import 'dart:typed_data';

import 'package:printing/printing.dart';

Future<void> deliverStrategyReportDownload(Uint8List bytes, String filename) =>
    Printing.layoutPdf(name: filename, onLayout: (_) async => bytes);

Future<void> deliverStrategyReportShare(Uint8List bytes, String filename) =>
    Printing.sharePdf(bytes: bytes, filename: filename);
