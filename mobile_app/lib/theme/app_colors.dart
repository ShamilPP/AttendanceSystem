import 'package:flutter/material.dart';

/// Brand seed and semantic status colors shared across the app.
///
/// These are the single source of truth for color; screens and widgets read
/// from here (or from `Theme.of(context).colorScheme`) — never hard-code hex.
abstract final class AppColors {
  /// Brand seed / primary — Indigo.
  static const Color seed = Color(0xFF4F46E5);

  // --- Semantic status colors (identical in both apps) ----------------------

  /// Present / success / Check-In ready.
  static const Color success = Color(0xFF16A34A);

  /// Late / warning.
  static const Color warning = Color(0xFFD97706);

  /// Absent / danger / Check-Out.
  static const Color danger = Color(0xFFDC2626);

  /// On leave / info.
  static const Color info = Color(0xFF2563EB);

  /// Half day.
  static const Color teal = Color(0xFF0D9488);

  /// Checked-out / neutral-done.
  static const Color slate = Color(0xFF64748B);

  /// Ink used for text on light colored fills where `onXxx` is unsuitable.
  static const Color ink = Color(0xFF0F172A);

  /// Opacity used for soft tinted chip / accent backgrounds.
  static const double tint = 0.12;

  /// Returns a readable foreground (dark ink or white) for [background]
  /// using a simple luminance check (WCAG-ish).
  static Color onColor(Color background) =>
      background.computeLuminance() > 0.55 ? ink : Colors.white;

  /// The brand gradient used on the splash, login background and the Home
  /// app-bar header.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4F46E5), Color(0xFF6366F1), Color(0xFF7C3AED)],
  );
}
