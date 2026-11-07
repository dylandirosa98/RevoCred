/// Converts failures (including stored exception strings) to safe display copy.
/// Never returns server-provided text.
String friendlyError(Object? error) {
  final value = error.toString().toLowerCase();
  if (value.contains('401') || value.contains('sessionexpired')) {
    return 'Your session has expired. Please sign in again.';
  }
  if (value.contains('429') || value.contains('rate limit')) {
    return 'Too many requests. Please wait a moment and try again.';
  }
  if (value.contains('timeout') || value.contains('timed out')) {
    return 'This is taking too long. Please try again.';
  }
  if (value.contains('handshake') || value.contains('certificate')) {
    return 'A secure connection could not be established. Please try again.';
  }
  if (value.contains('socket') ||
      value.contains('clientexception') ||
      value.contains('network') ||
      value.contains('connection')) {
    return 'Unable to connect. Check your internet connection and try again.';
  }
  if (RegExp(r'\b5\d{2}\b').hasMatch(value)) {
    return 'The service is temporarily unavailable. Please try again later.';
  }
  return 'Something went wrong. Please try again.';
}
