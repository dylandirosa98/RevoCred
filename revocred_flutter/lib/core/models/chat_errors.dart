import 'dart:async';

import 'package:http/http.dart' as http;

import '../data/app_repository.dart' show SessionExpiredException;

/// A REVO send failure with a server or client error code.
class ChatSendException implements Exception {
  const ChatSendException(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => message;
}

/// The member stopped a REVO message before it was answered.
class ChatCancelledException implements Exception {
  const ChatCancelledException();
}

const _genericFailure =
    'REVO could not send. Please try again. Your message has been kept.';

/// Friendly text for any REVO failure. Never includes exception class names,
/// hosts or stack traces.
String chatErrorMessage(Object error) {
  if (error is ChatSendException) {
    return switch (error.code) {
      'account_required' =>
        'Create an account to let REVO discuss your personal plan.',
      // The server's wording names the limit and the basic-answer fallback.
      'chat_daily_limit' =>
        error.message.isNotEmpty
            ? error.message
            : "You've reached today's REVO AI limit. Basic answers are still available.",
      'ai_consent_changed' =>
        'REVO’s AI sharing details changed. Review them and send again.',
      'account_changed' =>
        'Your account changed. Send again from the current account.',
      'busy' => 'REVO is still answering your last message.',
      'timeout' ||
      'request_timeout' => 'REVO took too long to respond. Please try again.',
      'offline' =>
        'REVO could not connect. Check your connection and try again.',
      'rate_limited' || 'too_many_requests' =>
        'You are sending messages quickly. Wait a moment and try again.',
      'server_error' ||
      'internal_error' ||
      'incomplete_response' ||
      'invalid_response' => 'REVO had a problem answering. Please try again.',
      _ => _genericFailure,
    };
  }
  if (error is SessionExpiredException) {
    return 'Your session expired. Sign in again to keep chatting.';
  }
  if (error is TimeoutException) {
    return 'REVO took too long to respond. Please try again.';
  }
  if (error is http.ClientException ||
      error.runtimeType.toString() == 'SocketException') {
    return 'REVO could not connect. Check your connection and try again.';
  }
  return _genericFailure;
}
