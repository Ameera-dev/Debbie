import 'package:intl/intl.dart';

enum TxRange {
  today,
  week,
  month,
  threeMonths,
  sixMonths,
  oneYear,
  threeYears,
  fiveYears;

  String get label => switch (this) {
    TxRange.today => 'Today',
    TxRange.week => 'Week',
    TxRange.month => 'Month',
    TxRange.threeMonths => '3M',
    TxRange.sixMonths => '6M',
    TxRange.oneYear => '1Y',
    TxRange.threeYears => '3Y',
    TxRange.fiveYears => '5Y',
  };
}

class AppDateUtils {
  AppDateUtils._();

  static final _monthFormatter = DateFormat('yyyy-MM');
  static final _displayMonth = DateFormat('MMMM yyyy');
  static final _displayDate = DateFormat('d MMM yyyy');
  static final _displayTime = DateFormat('HH:mm');
  static final _shortMonth = DateFormat('MMM');

  static String greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// Returns "2025-07" for a given date.
  static String toMonthKey(DateTime date) => _monthFormatter.format(date);

  static String currentMonthKey() => toMonthKey(DateTime.now());

  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime startOfMonth(DateTime date) =>
      DateTime(date.year, date.month, 1);

  static bool isSameDay(DateTime a, DateTime b) =>
      startOfDay(a) == startOfDay(b);

  static DateTime startOfWeek(DateTime date) {
    final normalized = startOfDay(date);
    final daysFromMonday = normalized.weekday - DateTime.monday;
    return normalized.subtract(Duration(days: daysFromMonday));
  }

  static DateTime endOfWeek(DateTime date) =>
      startOfWeek(date).add(const Duration(days: 6));

  static bool isWithinRange(DateTime date, DateTime start, DateTime end) {
    final normalized = startOfDay(date);
    return !normalized.isBefore(startOfDay(start)) &&
        !normalized.isAfter(startOfDay(end));
  }

  static String formatWeekRange(DateTime weekStart) {
    final start = startOfDay(weekStart);
    final end = start.add(const Duration(days: 6));

    if (start.year == end.year && start.month == end.month) {
      return '${start.day}-${end.day} ${_shortMonth.format(start)}';
    }

    if (start.year == end.year) {
      return '${start.day} ${_shortMonth.format(start)} - ${end.day} ${_shortMonth.format(end)}';
    }

    return '${start.day} ${_shortMonth.format(start)} ${start.year} - ${end.day} ${_shortMonth.format(end)} ${end.year}';
  }

  /// Returns the month key for the previous month (e.g. "2025-06").
  static String previousMonthKey([DateTime? from]) {
    final date = from ?? DateTime.now();
    final prev = DateTime(date.year, date.month - 1, 1);
    return toMonthKey(prev);
  }

  static String formatMonthDisplay(DateTime date) => _displayMonth.format(date);

  static String formatDate(DateTime date) => _displayDate.format(date);

  static String formatTime(DateTime date) => _displayTime.format(date);

  /// Human-friendly group label for a date.
  static String groupLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = today.difference(d).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return 'This Week';
    if (date.month == now.month && date.year == now.year) return 'This Month';
    return formatMonthDisplay(date);
  }

  /// Returns [startOfMonth, endOfMonth] for the given year+month.
  static (DateTime, DateTime) monthRange(int year, int month) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1).subtract(const Duration(days: 1));
    return (start, end);
  }

  /// Date range [from, to] for a given [TxRange] ending now.
  static (DateTime, DateTime) rangeFor(TxRange range) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final from = switch (range) {
      TxRange.today => DateTime(now.year, now.month, now.day),
      TxRange.week => startOfWeek(now),
      TxRange.month => DateTime(now.year, now.month, 1),
      TxRange.threeMonths => DateTime(now.year, now.month - 2, 1),
      TxRange.sixMonths => DateTime(now.year, now.month - 5, 1),
      TxRange.oneYear => DateTime(now.year - 1, now.month + 1, 1),
      TxRange.threeYears => DateTime(now.year - 3, now.month + 1, 1),
      TxRange.fiveYears => DateTime(now.year - 5, now.month + 1, 1),
    };
    return (from, today);
  }

  /// Group label for a transaction date within a given [TxRange].
  static String groupLabelForRange(DateTime date, TxRange range) {
    final now = DateTime.now();
    switch (range) {
      case TxRange.today:
        final h = date.hour;
        if (h < 6) return 'Night';
        if (h < 12) return 'Morning';
        if (h < 17) return 'Afternoon';
        if (h < 21) return 'Evening';
        return 'Night';

      case TxRange.week:
        final d = startOfDay(date);
        final today = startOfDay(now);
        final diff = today.difference(d).inDays;
        if (diff == 0) return 'Today';
        if (diff == 1) return 'Yesterday';
        return DateFormat('EEEE, d MMM').format(date);

      case TxRange.month:
        final d = startOfDay(date);
        final today = startOfDay(now);
        final diff = today.difference(d).inDays;
        if (diff == 0) return 'Today';
        if (diff == 1) return 'Yesterday';
        return DateFormat('d MMM').format(date);

      case TxRange.threeMonths:
      case TxRange.sixMonths:
        return DateFormat('MMMM yyyy').format(date);

      case TxRange.oneYear:
        return DateFormat('MMM yyyy').format(date);

      case TxRange.threeYears:
      case TxRange.fiveYears:
        return date.year.toString();
    }
  }
}
