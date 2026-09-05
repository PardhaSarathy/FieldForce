import 'package:intl/intl.dart';

/// Display formatting helpers.
///
/// Centralised so that a date or an amount looks identical in Home, a report
/// and an approval card. Currency is Indian Rupee with the Indian digit
/// grouping convention (1,25,000 rather than 125,000) — getting this wrong is
/// immediately noticeable to the intended users.
abstract final class Fmt {
  /// "1 visit", "2 visits" — the difference between finished and unfinished.
  ///
  /// The app said "1 visits" in eight places. It is the smallest possible
  /// defect and one of the most damaging: everything else on the screen can be
  /// immaculate and a reader still registers that nobody checked.
  static String count(int n, String singular, [String? plural]) =>
      '$n ${n == 1 ? singular : (plural ?? '${singular}s')}';

  static final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static final _currencyPrecise = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final _compact = NumberFormat.compactCurrency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 1,
  );

  static final _decimal = NumberFormat.decimalPattern('en_IN');

  static final _dayMonth = DateFormat('d MMM');
  static final _dayMonthYear = DateFormat('d MMM yyyy');
  static final _weekdayLong = DateFormat('EEEE');
  static final _weekdayShort = DateFormat('EEE');
  static final _monthYear = DateFormat('MMMM yyyy');
  static final _monthName = DateFormat('MMMM');
  static final _monthShort = DateFormat('MMM');
  static final _time = DateFormat('h:mm a');
  static final _dateTime = DateFormat('d MMM yyyy, h:mm a');

  // -------------------------------------------------------------- currency
  /// ₹4,25,000
  static String money(num value) => _currency.format(value);

  /// ₹1,182.50 — for order lines and invoices where paise matter.
  static String moneyPrecise(num value) => _currencyPrecise.format(value);

  /// ₹4.3L — for tight metric cards only.
  static String moneyCompact(num value) => _compact.format(value);

  static String number(num value) => _decimal.format(value);

  /// 68%
  static String percent(num value, {int decimals = 0}) =>
      '${value.toStringAsFixed(decimals)}%';

  /// Achievement percentage guarding against a zero target.
  static double achievement(num actual, num target) =>
      target <= 0 ? 0 : (actual / target) * 100;

  // ------------------------------------------------------------------ dates
  static String date(DateTime d) => _dayMonthYear.format(d);
  static String dateShort(DateTime d) => _dayMonth.format(d);
  static String weekday(DateTime d) => _weekdayLong.format(d);
  static String weekdayShort(DateTime d) => _weekdayShort.format(d);
  static String monthYear(DateTime d) => _monthYear.format(d);

  /// The month on its own, for a sentence that already sits in one.
  static String monthName(DateTime d) => _monthName.format(d);
  static String monthShort(DateTime d) => _monthShort.format(d);
  static String time(DateTime d) => _time.format(d);
  static String dateTime(DateTime d) => _dateTime.format(d);

  /// "10:30 AM – 10:45 AM"
  static String timeRange(DateTime start, DateTime end) =>
      '${time(start)} – ${time(end)}';

  /// "26 Aug – 01 Sep 2026"
  static String dateRange(DateTime start, DateTime end) {
    if (start.year == end.year) {
      return '${_dayMonth.format(start)} – ${_dayMonthYear.format(end)}';
    }
    return '${_dayMonthYear.format(start)} – ${_dayMonthYear.format(end)}';
  }

  /// Calendar-day-aware relative label. Uses date boundaries rather than
  /// elapsed hours, so 11pm yesterday reads "Yesterday", not "10 hours ago".
  static String relativeDay(DateTime d, {DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    final target = _dateOnly(d);
    final days = target.difference(today).inDays;

    return switch (days) {
      0 => 'Today',
      1 => 'Tomorrow',
      -1 => 'Yesterday',
      _ when days > 1 && days < 7 => _weekdayLong.format(d),
      _ => _dayMonthYear.format(d),
    };
  }

  /// Compact "time ago" for chat and notification lists.
  static String timeAgo(DateTime d, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final diff = reference.difference(d);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return _dayMonth.format(d);
  }

  /// "45 min", "1h 20m"
  static String duration(Duration d) {
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  }

  /// Greeting used on Home. Split at conventional Indian office hours.
  static String greeting([DateTime? now]) {
    final hour = (now ?? DateTime.now()).hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// Initials for avatar fallbacks. Strips honorifics so "Dr. Anjali Sharma"
  /// yields "AS" rather than "DA".
  static String initials(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'^(Dr|Mr|Mrs|Ms|Prof)\.?\s+', caseSensitive: false), '')
        .trim();
    final parts = cleaned.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final single = parts.first;
      return (single.length >= 2 ? single.substring(0, 2) : single).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
