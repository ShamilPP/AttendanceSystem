import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../models/attendance.dart';
import '../providers/attendance_provider.dart';
import '../services/api_client.dart';
import '../services/location_service.dart';

/// QR scanner for one attendance [AttendanceAction].
///
/// On first detection the camera stops, GPS is fetched, and the scan is
/// posted to the server. Pops with a [ScanOutcome] on success; shows the
/// server's error message (geofence / QR / state errors) with a retry
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
  bool _openSettingsOffered = false;
  String? _stage;
  String? _error;

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
      _error = null;
      _openSettingsOffered = false;
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
      setState(() {
        _busy = false;
        _stage = null;
        _error = e.message;
        _openSettingsOffered = e.canOpenSettings;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _stage = null;
        _error = e.message;
      });
    }
  }

  Future<void> _retry() async {
    setState(() {
      _error = null;
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Scan to ${widget.action.label}'),
        actions: [
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, state, _) {
              final torchOn = state.torchState == TorchState.on;
              return IconButton(
                tooltip: 'Toggle flashlight',
                onPressed: () => _controller.toggleTorch(),
                icon: Icon(
                  torchOn
                      ? Icons.flash_on_rounded
                      : Icons.flash_off_rounded,
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.no_photography_outlined,
                        color: Colors.white70, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      error.errorCode ==
                              MobileScannerErrorCode.permissionDenied
                          ? 'Camera permission denied. Allow camera access '
                              'in your device settings to scan the QR code.'
                          : 'Could not start the camera '
                              '(${error.errorCode.name}).',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Viewfinder frame
          IgnorePointer(
            child: Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _busy
                        ? scheme.primary
                        : Colors.white.withValues(alpha: 0.85),
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          // Bottom panel: instructions / progress / error
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: _buildPanel(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel(BuildContext context) {
    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFFF8A80), size: 32),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _retry,
                  child: const Text('Try again'),
                ),
              ),
            ],
          ),
          if (_openSettingsOffered) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => _location.openAppSettings(),
              child: const Text('Open settings',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ],
      );
    }

    if (_busy) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
                strokeWidth: 3, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            _stage ?? 'Processing…',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      );
    }

    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 28),
        SizedBox(height: 8),
        Text(
          'Point the camera at the office QR code.\n'
          'Your location will be verified automatically.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white),
        ),
      ],
    );
  }
}
