import 'dart:ui' show Rect;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<void> deliverStrategyReportDownload(
  Uint8List bytes,
  String filename,
) async {
  final blob = _pdfBlob(bytes);
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}

Future<void> deliverStrategyReportShare(
  Uint8List bytes,
  String filename, {
  Rect? bounds,
}) async {
  final file = web.File(
    <JSAny>[bytes.toJS].toJS,
    filename,
    web.FilePropertyBag(type: 'application/pdf'),
  );
  final shareData = web.ShareData(
    files: <web.File>[file].toJS,
    title: 'My RevoCred strategy',
    text: 'My personalized RevoCred credit card strategy.',
  );

  // Many browsers have no Web Share API at all (Firefox, most desktop and
  // headless Chromium), so feature-detect before calling it.
  final navigator = web.window.navigator;
  var canShareFile = false;
  if (navigator.has('canShare') && navigator.has('share')) {
    try {
      canShareFile = navigator.canShare(shareData);
    } catch (_) {
      canShareFile = false;
    }
  }
  if (canShareFile) {
    try {
      await navigator.share(shareData).toDart;
    } catch (error) {
      // Closing the share sheet is not a failure.
      if (error.toString().contains('AbortError')) return;
      await deliverStrategyReportDownload(bytes, filename);
    }
    return;
  }

  // Desktop browsers commonly do not support sharing files. Downloading the
  // exact report gives the user a reliable file they can attach anywhere.
  await deliverStrategyReportDownload(bytes, filename);
}

web.Blob _pdfBlob(Uint8List bytes) => web.Blob(
  <JSAny>[bytes.toJS].toJS,
  web.BlobPropertyBag(type: 'application/pdf'),
);
