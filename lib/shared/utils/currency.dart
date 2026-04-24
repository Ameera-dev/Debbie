import 'package:intl/intl.dart';

class CurrencyUtils {
  CurrencyUtils._();

  static final _formatter = NumberFormat('#,###', 'id_ID');

  /// Format an integer IDR amount as "Rp 1.250.000"
  static String format(int amount) {
    if (amount == 0) return 'Rp 0';
    final formatted = _formatter.format(amount);
    return 'Rp $formatted';
  }

  /// Format with sign for income/expense display
  static String formatSigned(int amount, {required bool isExpense}) {
    final base = format(amount.abs());
    return isExpense ? '- $base' : '+ $base';
  }

  /// Parse a user-typed IDR string back to integer.
  /// Accepts "1.250.000", "1250000", "Rp 1.250.000" etc.
  static int? parse(String input) {
    final cleaned = input
        .replaceAll('Rp', '')
        .replaceAll(' ', '')
        .replaceAll('.', '')
        .trim();
    return int.tryParse(cleaned);
  }

  /// Format as user types — insert dot separators automatically.
  static String formatInput(String digits) {
    final numeric = digits.replaceAll(RegExp(r'[^0-9]'), '');
    if (numeric.isEmpty) return '';
    final value = int.parse(numeric);
    return _formatter.format(value);
  }
}
