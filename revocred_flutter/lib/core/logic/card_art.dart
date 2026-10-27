import '../models/app_models.dart';
import 'card_art_catalog.dart';

/// Identity uses the card name, never opaque API UUIDs. Artwork is an original
/// illustration; it is not a current issuer design or evidence of card terms.
String cardArtIdentity(String value) => value
    .toLowerCase()
    .replaceAll('+', 'plus')
    .replaceAll(RegExp(r'[^a-z0-9]'), '');

String cardArtAsset(CreditCard card) =>
    cardArtAssetForName(card.name, issuer: card.issuer);

String cardArtAssetForName(String name, {String? issuer}) {
  final identity = cardArtIdentity(name);
  final issuerIdentity = cardArtIdentity(issuer ?? '');
  for (final entry in cardArtCatalog.entries) {
    final canonical = cardArtIdentity(entry.key);
    final matchesIssuer =
        issuerIdentity.isEmpty ||
        issuerIdentity == canonical ||
        (canonical == 'americanexpress' && issuerIdentity == 'amex');
    if (!matchesIssuer) continue;
    for (final product in entry.value) {
      final productIdentity = cardArtIdentity(product);
      if (identity == productIdentity ||
          identity == '$canonical$productIdentity') {
        return 'assets/images/cards/$canonical-$productIdentity.png';
      }
    }
  }
  // A custom card with a familiar product word must not borrow another bank's
  // identity. Bare strategy aliases are resolved below only without an issuer.
  if (issuerIdentity.isNotEmpty) {
    if ((issuerIdentity == 'amex' || issuerIdentity == 'americanexpress') &&
        (identity == 'gold' || identity == 'americanexpressgold')) {
      return 'assets/images/cards/americanexpress-amexgold.png';
    }
    return 'assets/images/cards/generic.png';
  }
  final key = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  final design = switch (key) {
    final n when n.contains('doublecash') => 'double-cash',
    final n when n.contains('freedomflex') || n == 'flex' => 'freedom-flex',
    final n when n.contains('freedomunlimited') => 'freedom-unlimited',
    final n when n.contains('freedomrise') => 'freedom-rise',
    final n when n.contains('sapphirepreferred') || n == 'csp' =>
      'sapphire-preferred',
    final n when n.contains('sapphirereserve') || n == 'csr' =>
      'sapphire-reserve',
    final n when n.contains('strataelite') => 'strata-elite',
    final n when n.contains('stratapremier') => 'strata-premier',
    final n when n.contains('strata') => 'strata',
    final n
        when n == 'platinum' ||
            n == 'amexplatinum' ||
            n == 'americanexpressplatinum' =>
      'amex-platinum',
    final n when n == 'gold' || n == 'amexgold' || n == 'americanexpressgold' =>
      'amex-gold',
    final n when n.contains('venturex') => 'venture-x',
    final n when n.contains('savor') => 'savor',
    final n when n.contains('quicksilver') => 'quicksilver',
    final n when n.contains('discover') => 'discover',
    final n when n.contains('bilt') => 'bilt',
    _ => 'generic',
  };
  return 'assets/images/cards/$design.png';
}
