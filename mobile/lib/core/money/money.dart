import 'package:intl/intl.dart';

import 'currency.dart';

/// An exact monetary amount.
///
/// Money is stored and computed as an **integer number of minor units**
/// (e.g. cents) plus a [Currency]. We never use `double` for money — floating
/// point silently corrupts ledgers, which is unacceptable for a bookkeeping
/// app, and doubly so under ZiG inflation where amounts grow large.
///
/// All arithmetic guards against mixing currencies: combining USD with ZWG is
/// a programming error and throws immediately rather than producing nonsense.
class Money implements Comparable<Money> {
  const Money(this.amountMinor, this.currency);

  /// The amount in minor units. `$1.50` => `150`. Can be negative (e.g. a
  /// debt-balance overpayment), so callers should validate where appropriate.
  final int amountMinor;

  final Currency currency;

  /// Zero in the given [currency].
  factory Money.zero(Currency currency) => Money(0, currency);

  /// Build from a major-unit value (e.g. dollars). Rounds to the nearest minor
  /// unit. Use only at input boundaries (parsing user entry), never in storage.
  factory Money.fromMajor(num major, Currency currency) {
    final minor = (major * currency.minorUnitsPerMajor).round();
    return Money(minor, currency);
  }

  /// The amount expressed in major units (for display/formatting only).
  double get amountMajor => amountMinor / currency.minorUnitsPerMajor;

  bool get isZero => amountMinor == 0;
  bool get isNegative => amountMinor < 0;
  bool get isPositive => amountMinor > 0;

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(amountMinor + other.amountMinor, currency);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(amountMinor - other.amountMinor, currency);
  }

  /// Multiply by a quantity (e.g. unit price × 3). Rounds to nearest minor unit
  /// so a 0.5 kg sale of a per-kg price yields an exact integer of cents.
  Money operator *(num quantity) =>
      Money((amountMinor * quantity).round(), currency);

  void _assertSameCurrency(Money other) {
    if (currency != other.currency) {
      throw StateError(
        'Cannot combine ${currency.code} with ${other.currency.code}. '
        'Money arithmetic must stay within a single currency.',
      );
    }
  }

  @override
  int compareTo(Money other) {
    _assertSameCurrency(other);
    return amountMinor.compareTo(other.amountMinor);
  }

  /// Human-readable string, e.g. `$1.50` or `ZiG 1 250.00`.
  String format({String? locale}) {
    final fmt = NumberFormat.currency(
      locale: locale,
      symbol: '${currency.symbol} ',
      decimalDigits: currency.decimalDigits,
    );
    return fmt.format(amountMajor).trim();
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.amountMinor == amountMinor &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(amountMinor, currency);

  @override
  String toString() => '${currency.code} $amountMinor(minor)';
}
