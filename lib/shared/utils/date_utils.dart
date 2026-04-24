import 'package:intl/intl.dart';

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
}
