import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Selectable inline links; only HTTPS destinations can leave the app.
class ChatLinkText extends StatelessWidget {
  const ChatLinkText(
    this.text, {
    required this.accent,
    required this.style,
    this.launcher,
    super.key,
  });
  final String text;
  final Color accent;
  final TextStyle style;
  final Future<bool> Function(Uri)? launcher;

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\[([^\]]+)\]\(([^\s)]+)\)|https://[^\s]+');
    var end = 0;
    for (final match in pattern.allMatches(text)) {
      spans.add(TextSpan(text: text.substring(end, match.start)));
      var target = match.group(2) ?? match.group(0)!;
      var suffix = '';
      if (match.group(2) == null) {
        while (target.endsWith('.') ||
            target.endsWith(',') ||
            target.endsWith(')')) {
          suffix = target.substring(target.length - 1) + suffix;
          target = target.substring(0, target.length - 1);
        }
      }
      final uri = Uri.tryParse(target);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        spans.add(TextSpan(text: match.group(0)));
      } else {
        final label =
            match.group(1) ??
            '${uri.host}${uri.path.isNotEmpty && uri.path != '/' ? '/…' : ''}';
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Semantics(
              link: true,
              label: label,
              child: InkWell(
                onTap: () async {
                  try {
                    final opened =
                        await (launcher?.call(uri) ??
                            launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            ));
                    if (!opened) throw StateError('launch failed');
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Could not open this link. Please try again.',
                          ),
                        ),
                      );
                    }
                  }
                },
                child: Text(
                  label,
                  style: style.copyWith(
                    color: accent,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ),
        );
        spans.add(TextSpan(text: suffix));
      }
      end = match.end;
    }
    spans.add(TextSpan(text: text.substring(end)));
    return Text.rich(TextSpan(children: spans), style: style);
  }
}
