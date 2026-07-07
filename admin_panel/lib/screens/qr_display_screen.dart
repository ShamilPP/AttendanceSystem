import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/qr_info.dart';
import '../services/api_client.dart';
import '../widgets/app_feedback.dart';

/// Kiosk page: large QR from GET /qr/current, auto-refetched every
/// refreshSeconds with a countdown ring, plus a live date/time header.
class QrDisplayScreen extends StatefulWidget {
  const QrDisplayScreen({super.key});

  @override
  State<QrDisplayScreen> createState() => _QrDisplayScreenState();
}

class _QrDisplayScreenState extends State<QrDisplayScreen> {
  QrInfo? _info;
  DateTime _fetchedAt = DateTime.now();
  String? _error;
  bool _fetching = false;
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetch();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      if (_secondsLeft <= 0 && !_fetching && _error == null) {
        _fetch();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  DateTime get _expiry {
    final info = _info;
    if (info == null) return _fetchedAt;
    return info.expiresAt ??
        _fetchedAt.add(Duration(seconds: info.refreshSeconds));
  }

  int get _secondsLeft {
    if (_info == null) return 0;
    final left = _expiry.difference(_now).inMilliseconds / 1000;
    return left.ceil().clamp(0, 86400);
  }

  Future<void> _fetch() async {
    if (_fetching) return;
    setState(() => _fetching = true);
    try {
      final result = await ApiClient.instance.get('/qr/current');
      if (!mounted) return;
      setState(() {
        _info = QrInfo.fromJson(result.data);
        _fetchedAt = DateTime.now();
        _now = DateTime.now();
        _error = null;
        _fetching = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.fullMessage;
        _fetching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = _info;
    final refreshSeconds = info?.refreshSeconds ?? 30;
    final secondsLeft = _secondsLeft;
    final progress =
        refreshSeconds == 0 ? 0.0 : (secondsLeft / refreshSeconds).clamp(0.0, 1.0);

    return Container(
      color: theme.colorScheme.surfaceContainerLowest,
      alignment: Alignment.center,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.apartment, size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              'Office Attendance',
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('EEEE, d MMMM yyyy').format(_now),
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            Text(
              DateFormat('HH:mm:ss').format(_now),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 24),
            if (_error != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: ErrorBanner(message: _error!, onRetry: _fetch),
              )
            else if (info == null)
              const Padding(
                padding: EdgeInsets.all(60),
                child: CircularProgressIndicator(),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: theme.colorScheme.outlineVariant),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: info.qrData,
                  version: QrVersions.auto,
                  size: 340,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  fit: StackFit.expand,
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 5,
                      backgroundColor: theme.colorScheme.surfaceContainerHigh,
                    ),
                    Center(
                      child: Text(
                        '$secondsLeft',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'New code in $secondsLeft s',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Text(
                'Scan this code with the employee app to check in or out.',
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
