import 'package:flutter/material.dart';

/// A compact issuer badge for places where a full card face would be too small
/// to read: list rows, search results and roadmap steps. It shows the issuer's
/// colour and a short monogram. Real issuer logos are trademarks, so the app
/// draws its own mark instead of shipping them.
class IssuerMark extends StatelessWidget {
  const IssuerMark({required this.issuer, super.key, this.size = 40});

  final String issuer;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = issuerStyle(issuer);
    final foreground =
        ThemeData.estimateBrightnessForColor(style.color) == Brightness.light
        ? const Color(0xFF101522)
        : Colors.white;
    // Decorative: it always sits beside text that names the card, so reading
    // the issuer again would only lengthen every row's spoken label.
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: style.color,
          borderRadius: BorderRadius.circular(size * 0.26),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.08),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              style.monogram,
              maxLines: 1,
              style: TextStyle(
                color: foreground,
                fontSize: size * 0.36,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class IssuerStyle {
  const IssuerStyle(this.monogram, this.color);

  final String monogram;
  final Color color;
}

/// The colour and monogram for an issuer. Unknown issuers get a neutral tile
/// with their initials, so a card from any bank still reads cleanly.
IssuerStyle issuerStyle(String issuer) {
  final key = issuer.toLowerCase().replaceAll('.', '').trim();
  for (final entry in _issuerStyles.entries) {
    if (key.contains(entry.key)) return entry.value;
  }
  final words = key.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  final initials = words.take(2).map((w) => w[0].toUpperCase()).join();
  return IssuerStyle(
    initials.isEmpty ? '?' : initials,
    const Color(0xFF4A5568),
  );
}

// Matched by substring against the lowercased issuer with dots removed.
const _issuerStyles = {
  'chase': IssuerStyle('CH', Color(0xFF1B4F9C)),
  'american express': IssuerStyle('AX', Color(0xFF2671B9)),
  'amex': IssuerStyle('AX', Color(0xFF2671B9)),
  'capital one': IssuerStyle('C1', Color(0xFF0B3B5E)),
  'citi': IssuerStyle('citi', Color(0xFF056DAE)),
  'discover': IssuerStyle('D', Color(0xFFE37D2F)),
  'wells fargo': IssuerStyle('WF', Color(0xFFC8102E)),
  'us bank': IssuerStyle('US', Color(0xFF0C2074)),
  'bank of america': IssuerStyle('BA', Color(0xFFDC1431)),
  'bilt': IssuerStyle('BILT', Color(0xFF1F1F24)),
  'apple': IssuerStyle('A', Color(0xFF3A3A3C)),
};
