import 'package:intl/intl.dart';

final DateFormat _timeFmt = DateFormat('h:mm a');
final DateFormat _dayDateFmt = DateFormat('EEE, d MMM yyyy');
final DateFormat _fullDateFmt = DateFormat('EEEE, d MMMM yyyy');
final DateFormat _monthFmt = DateFormat('MMMM yyyy');
final DateFormat _ymdFmt = DateFormat('yyyy-MM-dd');
final DateFormat _dateTimeFmt = DateFormat('d MMM yyyy, h:mm a');

/// `4:05 PM` in device-local time, or a placeholder when null.
String formatTime(DateTime? dt, {String placeholder = '--:--'}) =>
    dt == null ? placeholder : _timeFmt.format(dt.toLocal());

/// `Tue, 7 Jul 2026`.
String formatDayDate(DateTime dt) => _dayDateFmt.format(dt.toLocal());

/// `Tuesday, 7 July 2026`.
String formatFullDate(DateTime dt) => _fullDateFmt.format(dt.toLocal());

/// Formats a contract `YYYY-MM-DD` day string as `Tue, 7 Jul 2026`.
String formatDateString(String ymd) {
  final parsed = DateTime.tryParse(ymd);
  return parsed == null ? ymd : _dayDateFmt.format(parsed);
}

/// `7 Jul 2026, 4:05 PM` in device-local time.
String formatDateTime(DateTime? dt, {String placeholder = '—'}) =>
    dt == null ? placeholder : _dateTimeFmt.format(dt.toLocal());

/// `July 2026` label for a month.
String formatMonthLabel(DateTime month) => _monthFmt.format(month);

/// `2026-07` query value for a month.
String formatMonthParam(DateTime month) =>
    '${month.year}-${month.month.toString().padLeft(2, '0')}';

/// `2026-07-07` query value for a day.
String formatYmd(DateTime day) => _ymdFmt.format(day);

/// `508` minutes → `8h 28m`; under an hour → `45m`.
String formatMinutes(int minutes) {
  if (minutes <= 0) return '0m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}

/// Live-ticking duration: `5h 12m 33s`.
String formatLiveDuration(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  return '${h}h ${m.toString().padLeft(2, '0')}m '
      '${s.toString().padLeft(2, '0')}s';
}

/// Minutes → decimal hours label: `161.7 h`.
String formatMinutesAsHours(int minutes) =>
    '${(minutes / 60).toStringAsFixed(1)} h';

/// `123456` bytes → `120.6 KB`.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Time-of-day greeting.
String greetingFor(DateTime now) {
  final hour = now.hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

/// `ON_LEAVE` → `On Leave`.
String humanizeEnum(String value) => value
    .split('_')
    .where((w) => w.isNotEmpty)
    .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
    .join(' ');
