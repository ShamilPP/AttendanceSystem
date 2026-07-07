import 'package:flutter/widgets.dart';

/// Spacing scale (4 · 8 · 12 · 16 · 20 · 24 · 32). Use these constants instead
/// of hard-coded margins so every screen breathes to the same rhythm.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Standard screen padding.
  static const EdgeInsets screen = EdgeInsets.all(xl);

  /// Standard card padding.
  static const EdgeInsets card = EdgeInsets.all(lg);
}

/// Corner radii from the design spec.
class AppRadius {
  AppRadius._();

  static const double card = 20;
  static const double button = 14;
  static const double pill = 999;
  static const double field = 12;
  static const double sheet = 28;

  static const BorderRadius cardR = BorderRadius.all(Radius.circular(card));
  static const BorderRadius buttonR = BorderRadius.all(Radius.circular(button));
  static const BorderRadius fieldR = BorderRadius.all(Radius.circular(field));
  static const BorderRadius pillR = BorderRadius.all(Radius.circular(pill));
}

/// Responsive breakpoints for the admin shell.
class AppBreakpoints {
  AppBreakpoints._();

  /// Below this the shell uses a drawer instead of a rail.
  static const double compact = 760;

  /// At/above this the rail is extended (labels visible).
  static const double railExtended = 1100;
}
