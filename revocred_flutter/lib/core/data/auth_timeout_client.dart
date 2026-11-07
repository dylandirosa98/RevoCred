import 'dart:async';

import 'package:http/http.dart' as http;

/// Bound auth transport (including response bodies), not SDK futures: a late
/// successful response must never install a session after the form timed out.
class AuthTimeoutClient extends http.BaseClient {
  AuthTimeoutClient(this._inner, {this.timeout = const Duration(seconds: 35)});

  final http.Client _inner;
  final Duration timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (!request.url.path.startsWith('/auth/v1/')) return _inner.send(request);
    return (() async {
      final response = await http.Response.fromStream(
        await _inner.send(request),
      );
      return http.StreamedResponse(
        Stream.value(response.bodyBytes),
        response.statusCode,
        contentLength: response.bodyBytes.length,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    })().timeout(timeout);
  }

  @override
  void close() => _inner.close();
}
