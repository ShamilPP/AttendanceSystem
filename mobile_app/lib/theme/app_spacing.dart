import 'package:flutter/widgets.dart';

/// Spacing scale, corner radii and elevation tokens.
///
/// Screen padding 16–20, gaps between cards 12–16. Use these constants
/// instead of scattering magic numbers through widgets.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Default horizontal screen padding.
  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: lg);

  /// Common inner padding for cards.
  static const EdgeInsets card = EdgeInsets.all(lg);
}

/// Corner radii from the design spec.
abstract final class AppRadius {
  static const double card = 20;
  static const double button = 14;
  static const double field = 12;
  static const double sheet = 28;
  static const double pill = 999;

  static const BorderRadius cardR = BorderRadius.all(Radius.circular(card));
  static const BorderRadius buttonR = BorderRadius.all(Radius.circular(button));
  static const BorderRadius fieldR = BorderRadius.all(Radius.circular(field));
  static const BorderRadius pillR = BorderRadius.all(Radius.circular(pill));
  static const BorderRadius sheetR =
      BorderRadius.vertical(top: Radius.circular(sheet));
}

/// Soft, low-contrast shadows — no heavy Material-2 drop shadows.
abstract final class AppShadows {
  static List<BoxShadow> soft(Brightness brightness) => [
        BoxShadow(
          color: brightness == Brightness.dark
              ? const Color(0x33000000)
              : const Color(0x0F000000), // black ~6%
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ];
}
