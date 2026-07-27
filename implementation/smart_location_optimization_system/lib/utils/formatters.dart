import 'package:intl/intl.dart';

/// Formats large numbers compactly.
/// Example: 1500 -> 1.5k, 120000 -> 120k
String formatCompactNumber(num value) {
  if (value >= 1000) {
    return NumberFormat.compactCurrency(
      decimalDigits: 1,
      symbol: '',
    ).format(value).toLowerCase();
  }
  return value.toStringAsFixed(0);
}
