import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../models/attendance.dart';
import '../providers/attendance_provider.dart';
import '../services/api_client.dart';
import '../services/location_service.dart';
import '../services/pending_scan_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_button.dart';

/// Full-screen QR scanner for a single attendance [AttendanceAction].
///
/// On first detection the camera stops, GPS is fetched, and the scan is
/// posted. Pops with a [ScanOutcome] on success (the caller shows the success
/// sheet); shows the server's error message in an error sheet with a Retry
/// option on failure. Guarded against double submissions.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, required this.action});

  final AttendanceAction action;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  final LocationService _location = const LocationService();

  bool _busy = false;
  String? _stage;

  Color get _accent => widget.action == AttendanceAction.checkIn
      ? AppColors.success
      : AppColors.danger;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    String? qrData;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) {
        qrData = raw;
        break;
      }
    }
    if (qrData == null) return;

    final provider = context.read<AttendanceProvider>();
    setState(() {
      _busy = true;
      _stage = 'QR detected — getting your location…';
    });

    try {
      await _controller.stop();
    } catch (_) {
      // Camera may already be stopped; submission continues regardless.
    }

    try {
      final position = await _location.getCurrentPosition();
      if (!mounted) return;
      setState(() => _stage = 'Recording ${widget.action.label}…');
      final outcome = await provider.scan(
        qrData: qrData,
        action: widget.action,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted) return;
      Navigator.of(context).pop(outcome);
    } on LocationException catch (e) {
      if (!mounted) return;
      await _showErrorSheet(e.message, canOpenSettings: e.canOpenSettings);
    } on ApiException catch (e) {
      // statusCode 0 means the request never reached the server, so the scan
      // itself was fine — the network was not. Remember it so the employee
      // can turn it into a correction request instead of losing the day.
      // Anything else is a real verdict (bad QR, geofence, wrong state).
      if (e.statusCode == 0) {
        await PendingScanService.instance.save(PendingScan(
          action: widget.action.apiValue,
          attemptedAt: DateTime.now(),
        ));
      }
      if (!mounted) return;
      await _showErrorSheet(
        e.statusCode == 0
            ? '${e.message}\n\nWe saved this scan attempt — open the app once '
                'you are back online to send it for approval.'
            : e.message,
      );
    }
  }

  Future<void> _showErrorSheet(String message,
      {bool canOpenSettings = false}) async {
    setState(() {
      _busy = false;
      _stage = null;
    });
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) => _ErrorSheet(
        message: message,
        canOpenSettings: canOpenSettings,
        onOpenSettings: () => _location.openAppSettings(),
        onCancel: () {
          Navigator.of(sheetContext).pop();
          Navigator.of(context).pop();
        },
        onRetry: () {
          Navigator.of(sheetContext).pop();
          _retry();
        },
      ),
    );
  }

  Future<void> _retry() async {
    setState(() {
      _busy = false;
      _stage = null;
    });
    try {
      await _controller.start();
    } catch (_) {
      // start() throws if already running; scanning resumes either way.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _CameraError(error: error),
          ),
          // Dimmed surround with a clear rounded scan window.
          const _ScannerOverlay(),
          // Top action header
          SafeArea(
            child: Column(
              children: [
                _Header(action: widget.action, accent: _accent,
                    onClose: () => Navigator.of(context).pop(),
                    controller: _controller),
                const Spacer(),
                if (_busy)
                  _ProcessingCard(stage: _stage ?? 'Processing…')
                else
                  const _HintCard(),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.action,
    required this.accent,
    required this.onClose,
    required this.controller,
  });

  final AttendanceAction action;
  final Color accent;
  final VoidCallback onClose;
  final MobileScannerController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          _CircleIconButton(icon: Icons.close_rounded, onTap: onClose),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: AppRadius.pillR,
                border: Border.all(color: accent.withValues(alpha: 0.6)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    action == AttendanceAction.checkIn
                        ? Icons.login_rounded
                        : Icons.logout_rounded,
                    color: accent,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Scanning to ${action.label}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          ValueListenableBuilder(
            valueListenable: controller,
            builder: (context, state, _) {
              final torchOn = state.torchState == TorchState.on;
              return _CircleIconButton(
                icon: torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                onTap: () => controller.toggleTorch(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard();

  @override
  Widget build(BuildContext context) {
    return _FrostPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 28),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Point the camera at the office QR code.\n'
            'Your location is verified automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ProcessingCard extends StatelessWidget {
  const _ProcessingCard({required this.stage});

  final String stage;

  @override
  Widget build(BuildContext context) {
    return _FrostPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child:
                CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            stage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _FrostPanel extends StatelessWidget {
  const _FrostPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: AppRadius.cardR,
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: child,
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined,
                color: Colors.white70, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(
              error.errorCode == MobileScannerErrorCode.permissionDenied
                  ? 'Camera permission denied. Allow camera access in your '
                      'device settings to scan the QR code.'
                  : 'Could not start the camera (${error.errorCode.name}).',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dimmed surround with a transparent rounded scan window + corner brackets.
class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth * 0.68;
        final rect = Rect.fromCenter(
          center: Offset(constraints.maxWidth / 2, constraints.maxHeight / 2),
          width: side,
          height: side,
        );
        return IgnorePointer(
          child: CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _OverlayPainter(rect),
          ),
        );
      },
    );
  }
}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter(this.window);

  final Rect window;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = Radius.circular(28);
    final rrect = RRect.fromRectAndRadius(window, radius);

    // Dim everything except the window.
    final overlay = Path()..addRect(Offset.zero & size);
    final hole = Path()..addRRect(rrect);
    final dim = Path.combine(PathOperation.difference, overlay, hole);
    canvas.drawPath(dim, Paint()..color = Colors.black.withValues(alpha: 0.6));

    // Window edge.
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.4),
    );

    // Corner brackets.
    final bracket = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;
    const len = 30.0;
    void corner(Offset o, Offset hx, Offset vy) {
      canvas.drawLine(o, o + hx, bracket);
      canvas.drawLine(o, o + vy, bracket);
    }

    corner(window.topLeft + const Offset(6, 6),
        const Offset(len, 0), const Offset(0, len));
    corner(window.topRight + const Offset(-6, 6),
        const Offset(-len, 0), const Offset(0, len));
    corner(window.bottomLeft + const Offset(6, -6),
        const Offset(len, 0), const Offset(0, -len));
    corner(window.bottomRight + const Offset(-6, -6),
        const Offset(-len, 0), const Offset(0, -len));
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) =>
      oldDelegate.window != window;
}

class _ErrorSheet extends StatelessWidget {
  const _ErrorSheet({
    required this.message,
    required this.canOpenSettings,
    required this.onOpenSettings,
    required this.onCancel,
    required this.onRetry,
  });

  final String message;
  final bool canOpenSettings;
  final VoidCallback onOpenSettings;
  final VoidCallback onCancel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl, 0, AppSpacing.xxl, AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: AppColors.tint),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  size: 44, color: AppColors.danger),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              "Couldn't record attendance",
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Cancel',
                    variant: AppButtonVariant.outline,
                    onPressed: onCancel,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppButton(
                    label: 'Try again',
                    icon: Icons.refresh_rounded,
                    onPressed: onRetry,
                  ),
                ),
              ],
            ),
            if (canOpenSettings) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('Open settings'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
