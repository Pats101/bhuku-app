/// Currencies supported by Bhuku.
///
/// Zimbabwe operates in two currencies day-to-day. We store the ISO 4217 code
/// (`ZWG` is the official code for ZiG) so that data is unambiguous and
/// future-proof if more currencies are ever added.
///
/// IMPORTANT: There is no FX conversion in the MVP. A transaction is always in
/// exactly one currency; we never do arithmetic across currencies.
enum Currency {
  usd('USD', r'$', 2),
  zwg('ZWG', 'ZiG', 2);

  const Currency(this.code, this.symbol, this.decimalDigits);

  /// ISO 4217 code, e.g. `USD`, `ZWG`. This is what gets persisted.
  final String code;

  /// Display symbol, e.g. `$`, `ZiG`.
  final String symbol;

  /// Number of minor units per major unit (2 => cents).
  final int decimalDigits;

  /// Number of minor units in one major unit (10^decimalDigits).
  int get minorUnitsPerMajor {
    var factor = 1;
    for (var i = 0; i < decimalDigits; i++) {
      factor *= 10;
    }
    return factor;
  }

  /// Parse a persisted ISO code back into a [Currency].
  static Currency fromCode(String code) {
    return Currency.values.firstWhere(
      (c) => c.code == code,
      orElse: () => throw ArgumentError('Unknown currency code: $code'),
    );
  }
}
