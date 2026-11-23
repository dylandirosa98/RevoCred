import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Whether direct browser file downloads are available on this platform.
bool get canDownloadTextFile => true;

/// Triggers a browser download for a UTF-8 text payload (such as JSON export).
Future<void> downloadTextFile(
  String content,
  String filename, {
  String mimeType = 'application/json;charset=utf-8',
}) async {
  final bytes = utf8.encode(content);
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  // Keep the object URL alive long enough for mobile Safari / PWA WebKit and
  // Chromium download managers to finish reading the blob.
  unawaited(
    Future<void>.delayed(
      const Duration(seconds: 60),
      () => web.URL.revokeObjectURL(url),
    ),
  );
}
