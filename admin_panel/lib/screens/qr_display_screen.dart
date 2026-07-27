import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/qr_info.dart';
import '../router/routes.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/formats.dart';
import '../widgets/app_button.dart';
import '../widgets/app_feedback.dart';
import '../widgets/states.dart';

/// The **permanent** attendance QR.
///
/// Fetches `GET /qr/current` once and renders `qrData` as a stable QR image —
/// no countdown, no auto-refresh. An admin can explicitly **Regenerate** the
/// code (`POST /qr/regenerate`), which mints a new one and invalidates the old.
///
/// In [kiosk] mode (the `/kiosk` route) the QR is rendered as large as the
/// display allows and the destructive Regenerate action is hidden — this is
/// the mode meant to be left running on a screen at the office entrance,
/// where a stray click must never invalidate everyone's code.
class QrDisplayScreen extends StatefulWidget {
  const QrDisplayScreen({super.key, this.kiosk = false});

  final bool kiosk;

  @override
  State<QrDisplayScreen> createState() => _QrDisplayScreenState();
}

class _QrDisplayScreenState extends State<QrDisplayScreen> {
  QrInfo? _info;
  String? _error;
  bool _loading = true;
  bool _regenerating = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ApiClient.instance.get('/qr/current');
      if (!mounted) return;
      setState(() {
        _info = QrInfo.fromJson(result.data);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.fullMessage;
        _loading = false;
      });
    }
  }

  Future<void> _regenerate() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Regenerate QR code?',
      icon: Icons.warning_amber_rounded,
      message:
          'This invalidates the current code — anyone using the old printed QR '
          'will need the new one. Print and post the new code at the entrance '
          'after regenerating.',
      confirmLabel: 'Regenerate',
      destructive: true,
    );
    if (!confirmed) return;
    setState(() => _regenerating = true);
    try {
      final result = await ApiClient.instance.post('/qr/regenerate');
      if (!mounted) return;
      setState(() {
        _info = QrInfo.fromJson(result.data);
        _regenerating = false;
      });
      showSuccessSnack(context, 'QR code regenerated. The old code no longer works.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _regenerating = false);
      showErrorSnack(context, e.fullMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  theme.colorScheme.surface,
                  Color.lerp(theme.colorScheme.surface, AppColors.seed, 0.14)!,
                ]
              : [
                  Color.lerp(Colors.white, AppColors.seed, 0.04)!,
                  Color.lerp(Colors.white, AppColors.seed, 0.12)!,
                ],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.all(60),
                  child: LoadingState(message: 'Loading QR code…'),
                )
              : _error != null
                  ? ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: ErrorState(message: _error!, onRetry: _fetch),
                    )
                  : _QrContent(
                      info: _info!,
                      kiosk: widget.kiosk,
                      regenerating: _regenerating,
                      onRegenerate: _regenerate,
                    ),
        ),
      ),
    );
  }
}

class _QrContent extends StatelessWidget {
  const _QrContent({
    required this.info,
    required this.kiosk,
    required this.regenerating,
    required this.onRegenerate,
  });

  final QrInfo info;
  final bool kiosk;
  final bool regenerating;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Fill the display in kiosk mode so the code stays scannable from across
    // the lobby; stay compact inside the admin shell.
    final size = MediaQuery.of(context).size;
    final qrSize = kiosk
        ? (size.shortestSide * 0.52).clamp(280.0, 620.0)
        : 340.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                Color.lerp(theme.colorScheme.primary, Colors.black, 0.25)!,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.apartment, color: Colors.white, size: 32),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Office Attendance',
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          'Scan this code with the NexCrew app to check in or out.',
          style: theme.textTheme.titleMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xxl),
        // The QR is always rendered on a white plate for reliable scanning,
        // even in dark mode.
        Container(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.colorScheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: QrImageView(
            data: info.qrData,
            version: QrVersions.auto,
            size: qrSize,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Color(0xFF0F172A),
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _VersionBadge(version: info.version),
            _MetaPill(
              icon: Icons.schedule,
              label: info.generatedAt == null
                  ? 'Permanent code'
                  : 'Generated ${formatDateTime(info.generatedAt)}',
            ),
            const _MetaPill(
              icon: Icons.push_pin_outlined,
              label: 'Stays valid until regenerated',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        if (kiosk)
          // Kiosk mode is display-only: the one action is leaving it.
          AppButton.outline(
            label: 'Exit kiosk',
            icon: Icons.close_fullscreen,
            onPressed: () => context.go(Routes.qr),
          )
        else ...[
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            alignment: WrapAlignment.center,
            children: [
              AppButton.outline(
                label: 'Open kiosk view',
                icon: Icons.open_in_full,
                onPressed: () => context.go(Routes.kiosk),
              ),
              AppButton(
                label: 'Regenerate QR',
                icon: Icons.autorenew,
                loading: regenerating,
                onPressed: onRegenerate,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Text(
              'Kiosk view fills the screen and hides every admin control — '
              'leave it running on a display at the entrance. Regenerating '
              'invalidates the current code immediately; only do this if the '
              'code was leaked or you are reprinting it.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }
}

class _VersionBadge extends StatelessWidget {
  const _VersionBadge({required this.version});

  final int version;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_outlined,
              size: 16, color: theme.colorScheme.onPrimaryContainer),
          const SizedBox(width: 6),
          Text('Version $version',
              style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label,
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
