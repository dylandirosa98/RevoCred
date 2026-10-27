import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.compact = false,
    this.onDark = false,
    this.markSize,
  });

  final bool compact;
  final bool onDark;
  final double? markSize;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    final size = markSize ?? (compact ? 34.0 : 42.0);
    final scale = size / 42;
    final foreground = onDark ? Colors.white : product.ink;
    return Semantics(
      label: 'RevoCred',
      image: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/revocred_mark_v2.png',
            width: size,
            height: size,
            color: product.variant == AppThemeVariant.clear
                ? null
                : product.action,
            colorBlendMode: BlendMode.srcIn,
            filterQuality: FilterQuality.high,
            excludeFromSemantics: true,
          ),
          if (!compact) ...[
            // The mark has transparent padding in the source PNG. A slight
            // negative gap makes the visible R and EVOCRED read as one word.
            Transform.translate(
              offset: Offset(-1 * scale, 0),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'EVO',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    TextSpan(
                      text: 'CRED',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                style: TextStyle(
                  color: foreground,
                  fontFamily: product.headingFontFamily,
                  fontSize: 20 * scale,
                  letterSpacing:
                      (product.panelTreatment == PanelTreatment.technical
                          ? .2
                          : -.8) *
                      scale,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
