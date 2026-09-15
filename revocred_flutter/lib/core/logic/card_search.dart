import '../models/app_models.dart';

List<CreditCard> searchCards(List<CreditCard> cards, String query) {
  final normalized = query.trim().toLowerCase();
  final tokens = normalized
      .split(RegExp(r'\s+'))
      .where((value) => value.isNotEmpty);
  if (tokens.isEmpty) return const [];

  final scored = <({CreditCard card, int score})>[];
  for (final card in cards) {
    final fields = [
      card.id,
      card.issuer,
      card.brand,
      card.name,
    ].map((value) => value.toLowerCase()).toList();
    var score = 0;
    var matches = true;
    if (card.name.toLowerCase() == normalized) score += 100;
    if (card.issuer.toLowerCase() == normalized) score += 95;
    for (final token in tokens) {
      if (fields.any((field) => field == token)) {
        score += 30;
      } else if (fields.any(
        (field) =>
            field.startsWith(token) ||
            field
                .split(RegExp(r'[\s-]+'))
                .any((word) => word.startsWith(token)),
      )) {
        score += 14;
      } else {
        matches = false;
        break;
      }
    }
    if (matches) scored.add((card: card, score: score));
  }
  scored.sort((a, b) {
    final scoreOrder = b.score.compareTo(a.score);
    return scoreOrder != 0 ? scoreOrder : a.card.name.compareTo(b.card.name);
  });
  return scored.map((entry) => entry.card).toList();
}
