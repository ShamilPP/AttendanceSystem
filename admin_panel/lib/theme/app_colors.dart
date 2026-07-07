import 'package:flutter/material.dart';

/// Shared semantic colors for the NexCrew design system.
///
/// The seed drives the Material 3 [ColorScheme]; the status palette is used
/// verbatim for chips, stat accents and chart series so the admin panel and
/// the mobile app read as one product family.
class AppColors {
  AppColors._();

  /// Brand seed / primary — indigo.
  static const Color seed = Color(0xFF4F46E5);

  // Semantic status colors (identical in both apps).
  static const Color present = Color(0xFF16A34A); // green — success / check-in
  static const Color late = Color(0xFFD97706); // amber — warning
  static const Color absent = Color(0xFFDC2626); // red — danger / check-out
  static const Color onLeave = Color(0xFF2563EB); // blue — info
  static const Color halfDay = Color(0xFF0D9488); // teal
  static const Color checkedOut = Color(0xFF64748B); // slate — neutral done
  static const Color notIn = Color(0xFF64748B); // slate — idle / not in

  // Request lifecycle.
  static const Color pending = late;
  static const Color approved = present;
  static const Color rejected = absent;

  // Active/inactive employee badges.
  static const Color active = present;
  static const Color inactive = Color(0xFF64748B);

  /// Color for an attendance record status
  /// (`PRESENT | LATE | ABSENT | ON_LEAVE | HALF_DAY`).
  static Color forAttendanceStatus(String status) {
    switch (status) {
      case 'PRESENT':
        return present;
      case 'LATE':
        return late;
      case 'ABSENT':
        return absent;
      case 'ON_LEAVE':
        return onLeave;
      case 'HALF_DAY':
        return halfDay;
      default:
        return notIn;
    }
  }

  /// Color for a live status (`NOT_IN | WORKING | CHECKED_OUT | ON_LEAVE`).
  static Color forLiveStatus(String status) {
    switch (status) {
      case 'WORKING':
        return present;
      case 'CHECKED_OUT':
        return checkedOut;
      case 'ON_LEAVE':
        return onLeave;
      case 'NOT_IN':
        return notIn;
      default:
        return notIn;
    }
  }

  /// Color for a request status (`PENDING | APPROVED | REJECTED`).
  static Color forRequestStatus(String status) {
    switch (status) {
      case 'PENDING':
        return pending;
      case 'APPROVED':
        return approved;
      case 'REJECTED':
        return rejected;
      default:
        return notIn;
    }
  }

  /// A readable foreground tint of [base] for text/icons sitting on a soft
  /// tinted fill — brightened in dark mode, saturated in light mode.
  static Color onTint(Color base, Brightness brightness) =>
      brightness == Brightness.dark
          ? Color.lerp(base, Colors.white, 0.30)!
          : Color.lerp(base, Colors.black, 0.10)!;
}
