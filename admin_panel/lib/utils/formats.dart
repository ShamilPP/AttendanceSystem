import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Formats a duration stored in minutes as `h:mm` (e.g. 508 -> `8:28`).
String formatMinutes(num? minutes) {
  if (minutes == null) return '—';
  final total = minutes.round();
  final h = total ~/ 60;
  final m = (total % 60).abs();
  return '$h:${m.toString().padLeft(2, '0')}';
}

/// Formats an ISO timestamp as local wall-clock time `HH:mm`.
String formatTime(DateTime? dt) {
  if (dt == null) return '—';
  return DateFormat('HH:mm').format(dt.toLocal());
}

/// Formats an ISO timestamp as `d MMM, HH:mm` local time.
String formatDateTime(DateTime? dt) {
  if (dt == null) return '—';
  return DateFormat('d MMM yyyy, HH:mm').format(dt.toLocal());
}

/// Formats a calendar-day string `YYYY-MM-DD` as `EEE, d MMM yyyy`.
String formatDay(String? day) {
  if (day == null || day.isEmpty) return '—';
  final parsed = DateTime.tryParse(day);
  if (parsed == null) return day;
  return DateFormat('EEE, d MMM yyyy').format(parsed);
}

/// `YYYY-MM-DD` for query params / request bodies.
String isoDay(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

/// `YYYY-MM` month param.
String isoMonth(DateTime date) => DateFormat('yyyy-MM').format(date);

/// Human month label, e.g. `July 2026`.
String monthLabel(DateTime date) => DateFormat('MMMM yyyy').format(date);

/// Combines a `YYYY-MM-DD` day and a local [TimeOfDay] into a UTC ISO string.
String? combineDayAndTime(String? day, TimeOfDay? time) {
  if (day == null || day.isEmpty || time == null) return null;
  final d = DateTime.tryParse(day);
  if (d == null) return null;
  final local = DateTime(d.year, d.month, d.day, time.hour, time.minute);
  return local.toUtc().toIso8601String();
}

/// `HH:mm` string for a [TimeOfDay] (used by office settings).
String timeOfDayToHHmm(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

/// Parses an `HH:mm` string into a [TimeOfDay]; null-tolerant.
TimeOfDay? parseHHmm(String? value) {
  if (value == null) return null;
  final parts = value.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
  return TimeOfDay(hour: h, minute: m);
}
