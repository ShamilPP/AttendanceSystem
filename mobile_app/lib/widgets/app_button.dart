import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Visual style of an [AppButton].
enum AppButtonVariant { filled, tonal, outline, danger }

/// The app's primary button. Full-width by default with a built-in loading
/// spinner that keeps the button height stable while busy.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.filled,
    this.loading = false,
    this.expand = true,
    this.height = 52,
    this.background,
    this.foreground,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final bool loading;
  final bool expand;
  final double height;

  /// Overrides for the filled/danger fill (e.g. the green Check-In button).
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null && !loading;

    late final Color fg;
    late final Color bg;
    late final BorderSide side;
    switch (variant) {
      case AppButtonVariant.filled:
        bg = background ?? scheme.primary;
        fg = foreground ?? scheme.onPrimary;
        side = BorderSide.none;
      case AppButtonVariant.danger:
        bg = background ?? scheme.error;
        fg = foreground ?? scheme.onError;
        side = BorderSide.none;
      case AppButtonVariant.tonal:
        bg = background ?? scheme.secondaryContainer;
        fg = foreground ?? scheme.onSecondaryContainer;
        side = BorderSide.none;
      case AppButtonVariant.outline:
        bg = Colors.transparent;
        fg = foreground ?? scheme.primary;
        side = BorderSide(color: scheme.outlineVariant);
    }

    final child = loading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.6, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );

    final button = FilledButton(
      onPressed: enabled ? onPressed : null,
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: variant == AppButtonVariant.outline
            ? Colors.transparent
            : scheme.onSurface.withValues(alpha: 0.12),
        disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
        elevation: 0,
        minimumSize: Size(0, height),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        side: side,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.buttonR),
      ),
      child: child,
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
