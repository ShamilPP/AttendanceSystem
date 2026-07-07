import 'package:flutter/material.dart';

/// Circular initials avatar on a tinted background derived from the name, so
/// each person gets a stable, recognisable color.
class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, required this.name, this.radius = 18});

  final String name;
  final double radius;

  static const List<Color> _palette = [
    Color(0xFF4F46E5), // indigo
    Color(0xFF0D9488), // teal
    Color(0xFF2563EB), // blue
    Color(0xFFD97706), // amber
    Color(0xFF16A34A), // green
    Color(0xFF9333EA), // violet
    Color(0xFFDB2777), // pink
    Color(0xFF0891B2), // cyan
  ];

  String get _initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final p = parts.first;
      return p.substring(0, p.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Color get _color {
    if (name.isEmpty) return _palette.first;
    var hash = 0;
    for (final code in name.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return _palette[hash % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.16),
      child: Text(
        _initials,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.72,
        ),
      ),
    );
  }
}

/// Employee identity cell: avatar + name (+ optional id/subtitle) for tables.
class EmployeeCell extends StatelessWidget {
  const EmployeeCell({
    super.key,
    required this.name,
    this.subtitle,
    this.badge,
  });

  final String name;
  final String? subtitle;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppAvatar(name: name, radius: 16),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                if (badge != null) ...[const SizedBox(width: 6), badge!],
              ],
            ),
            if (subtitle != null && subtitle!.isNotEmpty)
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
          ],
        ),
      ],
    );
  }
}
