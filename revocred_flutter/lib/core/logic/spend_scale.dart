/// Maps a spending slider's position to a monthly amount. Steps grow with the
/// amount, so smaller budgets get fine control ($10 steps under $500) while
/// the slider still reaches $5,000+.
abstract final class SpendScale {
  static const max = 5000;

  // (band start, step) pairs. Each band runs to the next band's start.
  static const _bands = [(0, 10), (500, 25), (1500, 50), (3000, 100)];

  /// Every amount the slider can land on, from $0 to [max].
  static final List<int> stops = [
    for (var band = 0; band < _bands.length; band++)
      for (
        var amount = _bands[band].$1;
        amount < (band + 1 < _bands.length ? _bands[band + 1].$1 : max);
        amount += _bands[band].$2
      )
        amount,
    max,
  ];

  static int get divisions => stops.length - 1;

  static int amountAt(num position) =>
      stops[position.round().clamp(0, divisions)];

  /// The nearest slider position for [amount], which may be off the grid.
  static int positionOf(int amount) {
    var best = 0;
    for (var index = 1; index < stops.length; index++) {
      if ((stops[index] - amount).abs() < (stops[best] - amount).abs()) {
        best = index;
      }
    }
    return best;
  }
}
