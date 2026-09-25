import 'package:flutter_test/flutter_test.dart';
import 'package:revocred_flutter/core/data/demo_seed.dart';
import 'package:revocred_flutter/core/logic/wallet_score.dart';
import 'package:revocred_flutter/core/logic/yearly_value.dart';

void main() {
  group('scoreWallet', () {
    test('2x catch-all adds 10 total', () {
      expect(scoreWallet(const WalletCapabilities(catchAll: 2)).additions, 10);
    });

    test('addition tiers do not stack', () {
      expect(scoreWallet(const WalletCapabilities(catchAll: 1.5)).additions, 5);
      expect(scoreWallet(const WalletCapabilities(dining: 3)).additions, 4);
      expect(scoreWallet(const WalletCapabilities(dining: 4)).additions, 8);
      expect(
        scoreWallet(
          const WalletCapabilities(
            catchAll: 2,
            dining: 4,
            groceries: 3,
            gas: 3,
            travel: 2,
            flights: 5,
            hotels: 5,
            transferPartners: true,
            premiumBenefits: true,
            ecosystemDiversity: true,
          ),
        ).additions,
        45,
      );
    });

    test('empty wallet does not stack catch-all penalties', () {
      final got = scoreWallet(const WalletCapabilities());
      expect(got.penalties, -26);
      expect(got.score, 24);
      expect(got.rating, 'Poor');
    });

    test('2x catch-all skips 1x category penalties', () {
      final got = scoreWallet(const WalletCapabilities(catchAll: 2));
      expect(got.penalties, -4);
      expect(got.score, 56);
      expect(got.rating, 'Fair');
    });

    test('flights and hotels above catch-all drop those penalties', () {
      expect(
        scoreWallet(
          const WalletCapabilities(catchAll: 2, flights: 5, hotels: 5),
        ).penalties,
        0,
      );
    });

    test('overlap penalties do not stack and clamp at 22', () {
      final got = scoreWallet(
        const WalletCapabilities(majorOverlap: true, multipleOverlap: true),
      );
      expect(got.penalties, -28);
      expect(got.score, 22);
    });

    test('maxed wallet is elite 95', () {
      final got = scoreWallet(
        const WalletCapabilities(
          catchAll: 2,
          dining: 4,
          groceries: 3,
          gas: 3,
          travel: 2,
          flights: 5,
          hotels: 5,
          transferPartners: true,
          premiumBenefits: true,
          ecosystemDiversity: true,
        ),
      );
      expect(got.score, 95);
      expect(got.rating, 'Elite');
      expect(got.penalties, 0);
    });
  });

  group('yearlyValue', () {
    test('treats 4x as 4 percent', () {
      expect(
        yearlyValue(
          const MonthlySpending(diningGrocery: 100),
          const BestCreditPoints(
            rentOrHousing: 1,
            diningGrocery: 4,
            traveling: 1,
            other: 1,
          ),
        ),
        48,
      );
    });

    test('sums buckets', () {
      expect(
        yearlyValue(
          const MonthlySpending(
            rentOrHousing: 200,
            diningGrocery: 400,
            traveling: 100,
            other: 300,
          ),
          const BestCreditPoints(
            rentOrHousing: 2,
            diningGrocery: 4,
            traveling: 5,
            other: 1.5,
          ),
        ),
        354,
      );
    });

    test('missing rate is 1x', () {
      expect(
        yearlyValue(
          const MonthlySpending(other: 100),
          const BestCreditPoints(
            rentOrHousing: 0,
            diningGrocery: 0,
            traveling: 0,
            other: 0,
          ),
        ),
        12,
      );
    });
  });

  group('walletCapabilities', () {
    test('reads demo wallet rates and flags', () {
      final wallet = demoCatalog.where((card) => card.isActive).toList();
      final got = walletCapabilities(wallet);
      expect(got.catchAll, 2);
      expect(got.dining, 4);
      expect(got.groceries, 4);
      expect(got.flights, 5);
      expect(got.hotels, 10);
      expect(got.transferPartners, isTrue);
      expect(got.premiumBenefits, isTrue);
      expect(got.ecosystemDiversity, isTrue);
      expect(got.majorOverlap, isFalse);
    });

    test('empty wallet has no rewards flags', () {
      final got = walletCapabilities(const []);
      expect(got.catchAll, 0);
      expect(got.transferPartners, isFalse);
      expect(got.ecosystemDiversity, isFalse);
    });

    test('demo wallet scores and yearly value', () {
      final data = createDemoAppData();
      final capabilities = walletCapabilities(data.wallet);
      final score = scoreWallet(capabilities);
      final yearly = yearlyValue(
        MonthlySpending.fromQuestionnaire(data.monthlySpend),
        bestRates(capabilities),
      );
      expect(score.score, 88);
      expect(score.rating, 'Great');
      expect(yearly, 468);
      expect(
        displayWalletScore(useLocal: true, storedScore: 359, localScore: score),
        88,
      );
    });
  });
}
