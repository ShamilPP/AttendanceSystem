import 'package:flutter/material.dart';

import 'qr_display_screen.dart';

/// Fullscreen QR display for the office entrance.
///
/// Sits outside the admin shell — no rail, no top bar, no destructive
/// actions — so the machine driving the lobby screen shows nothing but the
/// code employees need to scan. It has its own URL (`/kiosk`), so it can be
/// bookmarked or opened directly in a browser's fullscreen mode.
class KioskScreen extends StatelessWidget {
  const KioskScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: QrDisplayScreen(kiosk: true),
    );
  }
}
