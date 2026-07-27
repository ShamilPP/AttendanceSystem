import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'app_card.dart';

/// Dashboard KPI tile: an accented icon chip, a large tabular value and a label
/// with an optional supporting line. The value fades/slides when it changes.
///
/// When [onTap] is set the tile becomes a link into the list behind the
/// number — a count on its own only tells an admin *how many*, and the next
/// question is always *who*.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
    this.subtitle,
    this.onTap,
    this.hint,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;
  final String? subtitle;

  /// Drill-down target. Null leaves the tile as a plain read-out.
  final VoidCallback? onTap;

  /// Short call-to-action shown in place of [subtitle] on a tappable tile.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      elevated: true,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const Spacer(),
              if (onTap != null)
                Icon(Icons.arrow_outward,
                    size: 16, color: theme.colorScheme.onSurfaceVariant)
              else
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: accentColor, shape: BoxShape.circle),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
                child: child,
              ),
            ),
            child: Text(
              value,
              key: ValueKey(value),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.05,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          else if (hint != null && onTap != null)
            Text(
              hint!,
              style: theme.textTheme.labelSmall?.copyWith(
                  color: accentColor, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}
