import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ReportBrand extends StatelessWidget {
  const ReportBrand({super.key, this.onDark = false});
  final bool onDark;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.center,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'REVO',
                style: TextStyle(
                  color: onDark ? Colors.white : context.product.ink,
                ),
              ),
              const TextSpan(
                text: 'CRED',
                style: TextStyle(color: Color(0xff6400ed)),
              ),
            ],
          ),
          style: const TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontWeight: FontWeight.w900,
            fontSize: 58,
            height: 1,
            letterSpacing: -2,
          ),
        ),
        if (!onDark)
          const Text(
            'C R E D I T   C A R D   S T R A T E G Y',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
          ),
      ],
    ),
  );
}

class ReportScore extends StatelessWidget {
  const ReportScore({super.key, required this.score});
  final int score;

  @override
  Widget build(BuildContext context) => Container(
    width: 290,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.product.action.withValues(alpha: .06),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 132,
          child: Column(
            children: [
              const Text(
                'YOUR WALLET SCORE',
                style: TextStyle(fontFamily: 'Anton', fontSize: 14),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 126,
                height: math.max(
                  76,
                  MediaQuery.textScalerOf(context).scale(45) + 10,
                ),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: ScoreGaugePainter(score)),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '$score',
                          style: const TextStyle(
                            fontFamily: 'Anton',
                            fontSize: 32,
                            height: 1,
                          ),
                        ),
                        const Text('/100', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                score >= 80 ? 'Strong foundation!' : 'Room to grow!',
                style: TextStyle(
                  fontFamily: 'Anton',
                  color: context.product.action,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Follow your strategy to make more of your everyday spending.',
                style: TextStyle(fontSize: 11, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class ScoreGaugePainter extends CustomPainter {
  const ScoreGaugePainter(this.score);
  final int score;

  /// A circular semicircle regardless of the available widget's aspect ratio.
  static Rect arcBounds(Size size) {
    const inset = 7.0;
    final radius = math.max(
      0.0,
      math.min(size.width / 2 - inset, size.height - inset * 2),
    );
    return Rect.fromCircle(
      center: Offset(size.width / 2, size.height - inset),
      radius: radius,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = arcBounds(size);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      math.pi,
      math.pi,
      false,
      paint..color = const Color(0xffded8ec),
    );
    canvas.drawArc(
      rect,
      math.pi,
      math.pi * score.clamp(0, 100) / 100,
      false,
      paint..color = const Color(0xff6400ed),
    );
  }

  @override
  bool shouldRepaint(ScoreGaugePainter oldDelegate) =>
      oldDelegate.score != score;
}

class ReportHeading extends StatelessWidget {
  const ReportHeading(this.title, {super.key, this.icon});
  final String title;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (icon != null) ...[
        Icon(icon, color: context.product.action, size: 28),
        const SizedBox(width: 10),
      ],
      Expanded(
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Anton',
            fontSize: 21,
            height: 1.15,
          ),
        ),
      ),
    ],
  );
}
