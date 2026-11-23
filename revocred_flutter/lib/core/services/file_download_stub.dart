/// Whether direct browser file downloads are available on this platform.
bool get canDownloadTextFile => false;

/// No-op on non-web platforms where users copy or share exports directly.
Future<void> downloadTextFile(
  String content,
  String filename, {
  String mimeType = 'application/json;charset=utf-8',
}) async {}
