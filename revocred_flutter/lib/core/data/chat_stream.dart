import 'dart:async';
import 'dart:convert';

import '../models/app_models.dart';
import '../models/chat_errors.dart';

/// One step of a REVO reply: progress while the server works, then the saved
/// exchange.
sealed class ChatStreamEvent {
  const ChatStreamEvent();
}

class ChatStatusEvent extends ChatStreamEvent {
  const ChatStatusEvent(this.stage, this.label);
  final String stage;
  final String label;
}

class ChatDoneEvent extends ChatStreamEvent {
  const ChatDoneEvent({required this.reply, this.user});

  /// The server's copy of the prompt, when the server returned one.
  final ChatMessage? user;
  final ChatMessage reply;

  /// Parses `{"data":[userMessage, assistantMessage]}`.
  factory ChatDoneEvent.fromEnvelope(Object? json) {
    final payload = json is Map ? json['data'] : null;
    if (payload is! List || payload.isEmpty || payload.last is! Map) {
      throw const ChatSendException(
        'invalid_response',
        'REVO returned an unreadable reply.',
      );
    }
    ChatMessage parse(Object? item) =>
        ChatMessage.fromJson((item as Map).cast<String, dynamic>());
    return ChatDoneEvent(
      user: payload.length > 1 && payload.first is Map
          ? parse(payload.first)
          : null,
      reply: parse(payload.last),
    );
  }
}

class ChatConsentStatus {
  const ChatConsentStatus({required this.granted, this.version = ''});
  const ChatConsentStatus.none() : granted = false, version = '';

  factory ChatConsentStatus.fromJson(Object? json) {
    final data = json is Map ? json['data'] : null;
    if (data is! Map) return const ChatConsentStatus.none();
    return ChatConsentStatus(
      granted: data['granted'] == true,
      version: data['version'] is String ? data['version'] as String : '',
    );
  }

  final bool granted;
  final String version;
}

/// Maps an API error envelope to a [ChatSendException].
ChatSendException chatErrorFromJson(Object? json, int status) {
  final error = json is Map ? json['error'] : null;
  final code = error is Map && error['code'] is String
      ? error['code'] as String
      : status >= 500
      ? 'server_error'
      : 'request_failed';
  final message = error is Map && error['message'] is String
      ? error['message'] as String
      : 'REVO could not send. Please try again.';
  return ChatSendException(code, message);
}

/// Parses server-sent events (`status`, then `done` or `error`). Comment
/// lines are keep-alives; CRLF and multi-line `data:` fields are accepted.
Stream<ChatStreamEvent> parseChatEvents(Stream<String> lines) async* {
  String? event;
  final data = StringBuffer();
  var finished = false;
  await for (final line in lines) {
    if (line.isEmpty) {
      if (data.isEmpty && event == null) continue;
      final name = event ?? 'message';
      final body = data.toString();
      event = null;
      data.clear();
      switch (name) {
        case 'status':
          final json = jsonDecode(body);
          if (json is Map && json['label'] is String) {
            yield ChatStatusEvent(
              json['stage']?.toString() ?? '',
              json['label'] as String,
            );
          }
        case 'done':
          finished = true;
          yield ChatDoneEvent.fromEnvelope(jsonDecode(body));
          return;
        case 'error':
          throw chatErrorFromJson(jsonDecode(body), 500);
      }
      continue;
    }
    if (line.startsWith(':')) continue;
    final colon = line.indexOf(':');
    final field = colon < 0 ? line : line.substring(0, colon);
    var value = colon < 0 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    if (field == 'event') {
      event = value;
    } else if (field == 'data') {
      if (data.isNotEmpty) data.write('\n');
      data.write(value);
    }
  }
  if (!finished) {
    throw const ChatSendException(
      'incomplete_response',
      'REVO stopped before finishing. Please try again.',
    );
  }
}
