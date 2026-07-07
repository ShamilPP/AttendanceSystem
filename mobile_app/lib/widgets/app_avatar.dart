import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A circular avatar showing a person's initials on a tinted background.
///
/// The tint is derived deterministically from the name so each person keeps a
/// stable color. Pass [onGradient] on dark/gradient headers for a translucent
/// white treatment.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.radius = 24,
    this.onGradient = false,
  });

  final String name;
  final double radius;
  final bool onGradient;

  static const List<Color> _palette = [
    AppColors.seed,
    AppColors.info,
    AppColors.teal,
    AppColors.success,
    AppColors.warning,
    Color(0xFF7C3AED),
    Color(0xFFDB2777),
  ];

  String get _initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  Color get _accent {
    if (name.isEmpty) return AppColors.slate;
    final hash = name.codeUnits.fold<int>(0, (a, b) => a + b);
    return _palette[hash % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (onGradient) {
      bg = Colors.white.withValues(alpha: 0.22);
      fg = Colors.white;
    } else {
      final accent = _accent;
      bg = accent.withValues(alpha: 0.16);
      fg = accent;
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: radius * 0.72,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
