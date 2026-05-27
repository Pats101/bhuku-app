import 'package:bhuku/core/money/currency.dart';
import 'package:bhuku/core/money/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money', () {
    test('fromMajor converts to minor units and rounds', () {
      expect(Money.fromMajor(1.50, Currency.usd).amountMinor, 150);
      expect(Money.fromMajor(1.005, Currency.usd).amountMinor, 101); // rounds
    });

    test('adds and subtracts within the same currency', () {
      final a = Money(150, Currency.usd);
      final b = Money(50, Currency.usd);
      expect((a + b).amountMinor, 200);
      expect((a - b).amountMinor, 100);
    });

    test('multiplies by a fractional quantity and rounds', () {
      // 0.5 kg at $2.51/kg = $1.255 -> 126 cents
      final price = Money(251, Currency.usd);
      expect((price * 0.5).amountMinor, 126);
    });

    test('refuses to mix currencies', () {
      final usd = Money(100, Currency.usd);
      final zwg = Money(100, Currency.zwg);
      expect(() => usd + zwg, throwsStateError);
      expect(() => usd.compareTo(zwg), throwsStateError);
    });

    test('round-trips currency codes', () {
      expect(Currency.fromCode('ZWG'), Currency.zwg);
      expect(Currency.fromCode('USD'), Currency.usd);
      expect(() => Currency.fromCode('EUR'), throwsArgumentError);
    });

    test('equality is by amount and currency', () {
      expect(Money(100, Currency.usd), Money(100, Currency.usd));
      expect(Money(100, Currency.usd) == Money(100, Currency.zwg), isFalse);
    });
  });
}
