import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class ContentLayout extends StatelessWidget {
  const ContentLayout({
    required this.children,
    super.key,
    this.maxWidth = 1080,
    this.padding,
  });

  final List<Widget> children;
  final double maxWidth;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    final wide = MediaQuery.sizeOf(context).width >= 700;
    final safeTop = wide ? 0.0 : MediaQuery.paddingOf(context).top;
    final scroll = SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding:
          padding ??
          EdgeInsets.fromLTRB(
            wide ? product.pagePadding * 1.5 : product.pagePadding,
            product.pagePadding + safeTop,
            wide ? product.pagePadding * 1.5 : product.pagePadding,
            product.pagePadding * 2,
          ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
    if (product.panelTreatment == PanelTreatment.technical) {
      return Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _TechnicalGrid(color: product.border)),
          ),
          scroll,
        ],
      );
    }
    if (product.panelTreatment == PanelTreatment.paper) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [product.canvas, product.surface.withValues(alpha: .35)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: scroll,
      );
    }
    return scroll;
  }
}

class _TechnicalGrid extends CustomPainter {
  const _TechnicalGrid({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: .14)
      ..strokeWidth = .5;
    for (var x = 0.0; x < size.width; x += 48) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += 48) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TechnicalGrid oldDelegate) =>
      oldDelegate.color != color;
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    final label = switch (product.panelTreatment) {
      PanelTreatment.paper => text,
      PanelTreatment.technical => '// ${text.toUpperCase()}',
      PanelTreatment.wallet => text.toUpperCase(),
      _ => text.toUpperCase(),
    };
    return Text(
      label,
      style: TextStyle(
        color: product.panelTreatment == PanelTreatment.paper
            ? product.secondary
            : product.muted,
        fontFamily: product.panelTreatment == PanelTreatment.paper
            ? product.headingFontFamily
            : product.bodyFontFamily,
        fontSize: product.panelTreatment == PanelTreatment.paper ? 13 : 11,
        fontStyle: product.panelTreatment == PanelTreatment.paper
            ? FontStyle.italic
            : FontStyle.normal,
        fontWeight: FontWeight.w800,
        letterSpacing: product.panelTreatment == PanelTreatment.paper
            ? .2
            : product.compact
            ? 1.2
            : 1.5,
      ),
    );
  }
}

class AppPanel extends StatelessWidget {
  const AppPanel({required this.child, super.key, this.padding});
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    final treatment = product.panelTreatment;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding ?? EdgeInsets.all(product.panelPadding),
      decoration: BoxDecoration(
        color: treatment == PanelTreatment.technical
            ? product.subtle.withValues(alpha: .72)
            : product.surface,
        border:
            treatment == PanelTreatment.flat ||
                treatment == PanelTreatment.wallet
            ? null
            : Border.all(
                color: treatment == PanelTreatment.paper
                    ? product.border.withValues(alpha: .72)
                    : product.border,
              ),
        borderRadius: treatment == PanelTreatment.paper
            ? BorderRadius.only(
                topRight: Radius.circular(product.radius * 4),
                bottomLeft: Radius.circular(product.radius * 4),
              )
            : BorderRadius.circular(product.radius),
        boxShadow:
            treatment == PanelTreatment.paper ||
                treatment == PanelTreatment.wallet
            ? [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: dark
                        ? .24
                        : treatment == PanelTreatment.wallet
                        ? .045
                        : .07,
                  ),
                  blurRadius: treatment == PanelTreatment.wallet ? 16 : 22,
                  offset: Offset(0, treatment == PanelTreatment.wallet ? 5 : 9),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

class GradientButton extends StatelessWidget {
  const GradientButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? FilledButton(onPressed: onPressed, child: Text(label))
        : FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          );
    return child;
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({required this.label, super.key, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    final resolved = color ?? product.action;
    final technical = product.panelTreatment == PanelTreatment.technical;
    final pill =
        product.panelTreatment == PanelTreatment.flat ||
        product.panelTreatment == PanelTreatment.wallet;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: technical || pill ? 8 : 0,
        vertical: technical || pill ? 5 : 3,
      ),
      decoration: technical || pill
          ? BoxDecoration(
              color: pill
                  ? resolved.withValues(alpha: .12)
                  : Colors.transparent,
              border: technical ? Border.all(color: resolved) : null,
              borderRadius: BorderRadius.circular(pill ? 999 : 0),
            )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: resolved),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              technical ? '[ $label ]' : label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: resolved,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: .4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
