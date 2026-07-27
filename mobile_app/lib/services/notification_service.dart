import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local reminders so employees stop losing days to a forgotten check-out.
///
/// The admin panel has a whole "Missing check-outs" screen whose entire
/// purpose is cleaning up after people who walked out without tapping Check
/// Out. That queue is a symptom: nothing ever reminded them. A local
/// notification at the end of the working day fixes it at the source — no
/// server, no push infrastructure, no extra permissions beyond notifications.
///
/// Everything here degrades quietly. If the platform denies permission, or
/// exact alarms are unavailable, reminders simply do not fire; attendance
/// itself is never affected.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int _checkOutId = 1001;
  static const int _checkInId = 1002;
  static const String _prefsEnabledKey = 'reminders_enabled';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _available = false;

  /// True when the plugin initialised and the platform accepted us.
  bool get isAvailable => _available;

  /// Loads the timezone database and initialises the plugin. Safe to call
  /// more than once.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      tzdata.initializeTimeZones();
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Permission is requested later, tied to the user enabling
          // reminders — never as a surprise on first launch.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(settings);
      _available = true;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
      _available = false;
    }
  }

  /// Asks the platform for notification permission. Returns false when the
  /// user declines or the platform has no such concept.
  Future<bool> requestPermission() async {
    await init();
    if (!_available) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      }
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
    return false;
  }

  Future<bool> remindersEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefsEnabledKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setRemindersEnabled(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsEnabledKey, value);
    } catch (_) {
      // A failed write only means the toggle does not survive a restart.
    }
    if (!value) await cancelAll();
  }

  /// Schedules the daily reminders around the office working day.
  ///
  /// [workStart] / [workEnd] are `HH:mm` from office settings. The check-out
  /// reminder fires [graceMinutes] after the end of the day — late enough not
  /// to nag someone still working, early enough that they are usually still
  /// on site and can actually scan.
  Future<void> scheduleDailyReminders({
    required String workStart,
    required String workEnd,
    bool checkInReminder = true,
    int graceMinutes = 15,
  }) async {
    await init();
    if (!_available || !await remindersEnabled()) return;

    final start = _parseHHmm(workStart);
    final end = _parseHHmm(workEnd);
    if (end == null) return;

    await cancelAll();

    if (checkInReminder && start != null) {
      // Ten minutes before the day starts: enough time to walk in and scan.
      final minutes = (start.$1 * 60 + start.$2) - 10;
      if (minutes >= 0) {
        await _scheduleDaily(
          id: _checkInId,
          hour: minutes ~/ 60,
          minute: minutes % 60,
          title: 'Good morning',
          body: 'Remember to scan the office QR to check in.',
        );
      }
    }

    final endMinutes = end.$1 * 60 + end.$2 + graceMinutes;
    if (endMinutes < 24 * 60) {
      await _scheduleDaily(
        id: _checkOutId,
        hour: endMinutes ~/ 60,
        minute: endMinutes % 60,
        title: "Don't forget to check out",
        body: 'Scan the office QR before you leave, or your day stays open.',
      );
    }
  }

  Future<void> cancelAll() async {
    if (!_available) return;
    try {
      await _plugin.cancel(_checkInId);
      await _plugin.cancel(_checkOutId);
    } catch (e) {
      debugPrint('Failed to cancel reminders: $e');
    }
  }

  Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        _nextInstanceOf(hour, minute),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'attendance_reminders',
            'Attendance reminders',
            channelDescription:
                'Daily reminders to check in and check out of the office.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      // Exact-alarm restrictions and OEM battery savers can reject this.
      // A missing reminder must never break the app.
      debugPrint('Failed to schedule reminder $id: $e');
    }
  }

  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Parses `HH:mm` into (hour, minute).
  static (int, int)? _parseHHmm(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return (h, m);
  }
}
