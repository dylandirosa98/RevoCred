import '../models/app_models.dart';
import 'ongoing_value.dart';

/// Explore Rewards formulas, from the approved simulator handoff. Points are
/// valued at a 1¢ baseline; "extra value" is value above that baseline, not
/// literal cash saved.
double pointsBaselineDollars(int points) => points * 0.01;

/// Flight: `(cash - fees) / points * 100`. Hotel: pass `fees: 0`.
double redemptionCentsPerPoint({
  required int cash,
  required int points,
  int fees = 0,
}) => points <= 0 ? 0 : (cash - fees) / points * 100;

/// Flight: `cash - points × $0.01 - fees`. Hotel: pass `fees: 0`.
double extraValueDollars({
  required int cash,
  required int points,
  int fees = 0,
}) => cash - pointsBaselineDollars(points) - fees;

/// Spending categories that are usually not paid by card and earn nothing in
/// the wallet model.
const _nonCardCategories = {'rent', 'housing'};

/// Whose numbers the simulator starts from.
enum EarningSource {
  /// The signed-in member's (or their preview's) own spending and cards.
  wallet,

  /// The sample wallet shown to guests who have not entered anything.
  sample,

  /// Fixed example numbers when no spending or scoreable card is known.
  example,
}

/// What a wallet earns: monthly card spending, the wallet model's annual
/// points and the blended rate between them.
class WalletEarning {
  const WalletEarning({
    required this.monthlySpend,
    required this.annualPoints,
    this.source = EarningSource.wallet,
    this.cashBack = false,
  });

  /// Shown when there is no spending or no scoreable card yet.
  static const example = WalletEarning(
    monthlySpend: 3000,
    annualPoints: 54000,
    source: EarningSource.example,
  );

  /// Monthly card spending in whole dollars (housing excluded).
  final int monthlySpend;

  /// Points a year from the wallet model (1¢ per point, so equal to the
  /// rewards estimate in cents).
  final int annualPoints;
  final EarningSource source;

  /// True when every scored card pays plain cash back, so the yearly figure
  /// is dollars (in cents), not travel points.
  final bool cashBack;

  /// Yearly rewards in dollars at face value (1¢ per point).
  double get annualDollars => annualPoints / 100;

  /// True when these are the member's own numbers.
  bool get personalized => source == EarningSource.wallet;

  /// Points earned per dollar across all spending.
  double get multiplier =>
      monthlySpend <= 0 ? 0 : annualPoints / (monthlySpend * 12);
}

/// The wallet's earning from the same value model as Home: the server's
/// estimate for accounts, or its local mirror for previews. [ownWallet] is
/// false for guests looking at the sample wallet.
WalletEarning walletEarning(AppData data, {bool ownWallet = true}) {
  final spend = data.monthlySpend.entries
      .where((entry) => !_nonCardCategories.contains(entry.key))
      .fold<int>(0, (total, entry) => total + entry.value);
  final value =
      data.ongoingValue ??
      estimateOngoingValue(
        data.wallet,
        data.monthlySpend,
        data.questionnaireAnswers?.travelScope ?? '',
      );
  if (spend <= 0 || value.rewardsCents <= 0) return WalletEarning.example;
  final scored = data.wallet.where((c) => c.isActive && !c.termsUnknown);
  return WalletEarning(
    monthlySpend: spend,
    annualPoints: value.rewardsCents,
    source: ownWallet ? EarningSource.wallet : EarningSource.sample,
    cashBack: scored.isNotEmpty && !scored.any((c) => c.earnsTravelPoints),
  );
}

/// Whether [data] describes the viewer's own wallet rather than the sample.
bool isOwnWallet(AppData data, {required bool authenticated}) =>
    authenticated || data.isPersonalPreview;

/// Annual points for a simulated [monthlySpend] and [multiplier]. When both
/// match the wallet, returns the wallet's own estimate exactly.
int simulatedAnnualPoints(
  WalletEarning wallet, {
  required int monthlySpend,
  required double multiplier,
}) {
  if (monthlySpend == wallet.monthlySpend &&
      (multiplier - wallet.multiplier).abs() < 1e-9) {
    return wallet.annualPoints;
  }
  return (monthlySpend * 12 * multiplier).round();
}

/// Short label for a blended rate, e.g. `1.8x`.
String formatMultiplier(double value) {
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? '${rounded.toStringAsFixed(0)}x'
      : '${rounded.toStringAsFixed(1)}x';
}

/// Months of earning at [annualPoints] a year needed to collect [points].
double monthsToEarn(int points, int annualPoints) =>
    annualPoints <= 0 ? double.infinity : points / (annualPoints / 12);
