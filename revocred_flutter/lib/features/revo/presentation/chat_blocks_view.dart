import 'package:flutter/material.dart';

import '../../../core/models/app_models.dart';

/// Renders a REVO reply as structured blocks: heading, paragraph, bullet list,
/// server-drawn chart and closing note.
///
/// A message saved before blocks existed has no blocks, so it renders as the
/// plain text it always was. Numbers in charts come from the API, never from the
/// model, so this file only draws what it is given.
class ChatBlocksView extends StatelessWidget {
  const ChatBlocksView({
    required this.blocks,
    required this.fallbackText,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.surface,
    required this.bodySize,
    this.onAskAbout = _defaultAsk,
    super.key,
  });

  final List<ChatBlock> blocks;
  final String fallbackText;
  final Color ink;
  final Color muted;
  final Color accent;
  final Color surface;
  final double bodySize;
  final ValueChanged<String> onAskAbout;

  static void _defaultAsk(String _) {}

  @override
  Widget build(BuildContext context) {
    if (blocks.isEmpty) {
      return Text(
        fallbackText,
        style: TextStyle(color: ink, height: 1.6, fontSize: bodySize),
      );
    }
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < blocks.length; index++)
            Padding(
              padding: EdgeInsets.only(
                bottom: index == blocks.length - 1 ? 0 : 14,
              ),
              child: _buildBlock(context, blocks[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildBlock(BuildContext context, ChatBlock block) {
    switch (block.type) {
      case 'heading':
        return Text(
          block.text,
          style: TextStyle(
            color: ink,
            fontSize: bodySize + 3,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        );
      case 'bullets':
        if (block.items.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in block.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, right: 10),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          color: ink,
                          height: 1.5,
                          fontSize: bodySize,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      case 'chart':
        final chart = block.chart;
        if (chart == null || chart.bars.isEmpty) {
          return const SizedBox.shrink();
        }
        return _ChartCard(
          chart: chart,
          ink: ink,
          muted: muted,
          accent: accent,
          surface: surface,
          onAskAbout: onAskAbout,
        );
      case 'note':
        return Container(
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: muted.withValues(alpha: 0.5)),
            ),
          ),
          child: Text(
            block.text,
            style: TextStyle(
              color: muted,
              fontSize: bodySize - 2,
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      case 'paragraph':
      default:
        // An unknown block type falls back to whatever text it carried.
        return Text(
          block.text,
          style: TextStyle(color: ink, height: 1.6, fontSize: bodySize),
        );
    }
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.chart,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.surface,
    required this.onAskAbout,
  });

  final ChatChart chart;
  final Color ink;
  final Color muted;
  final Color accent;
  final Color surface;
  final ValueChanged<String> onAskAbout;

  @override
  Widget build(BuildContext context) {
    final top = chart.bars.reduce((a, b) => a.value >= b.value ? a : b);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: muted.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            chart.title,
            style: TextStyle(
              color: ink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          for (final bar in chart.bars)
            _Bar(
              bar: bar,
              highlighted: identical(bar, top),
              fraction: top.value <= 0
                  ? 0
                  : (bar.value / top.value).clamp(0.02, 1.0),
              isPercent: chart.isPercent,
              ink: ink,
              muted: muted,
              accent: accent,
            ),
          if (chart.note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              chart.note,
              style: TextStyle(color: muted, fontSize: 11, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.bar,
    required this.fraction,
    required this.highlighted,
    required this.isPercent,
    required this.ink,
    required this.muted,
    required this.accent,
  });

  final ChatBar bar;
  final double fraction;
  final bool highlighted;
  final bool isPercent;
  final Color ink;
  final Color muted;
  final Color accent;

  String _value() {
    if (bar.valueLabel.isNotEmpty) return bar.valueLabel;
    if (isPercent) {
      final points = bar.value <= 0
          ? '0'
          : bar.value.toStringAsFixed(
              bar.value == bar.value.roundToDouble() ? 0 : 1,
            );
      return '$points% cash back';
    }
    return '\$${_money(bar.value)}';
  }

  String _money(double value) {
    if (value >= 10000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  bar.label,
                  style: TextStyle(
                    color: ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _value(),
                style: TextStyle(
                  color: ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 8,
                    backgroundColor: muted.withValues(alpha: 0.15),
                    // The largest bar is the point of the chart; the others
                    // stay in the same colour but recede.
                    valueColor: AlwaysStoppedAnimation<Color>(
                      highlighted ? accent : accent.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
              if (bar.caption.isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    bar.caption,
                    textAlign: TextAlign.right,
                    style: TextStyle(color: muted, fontSize: 10),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
