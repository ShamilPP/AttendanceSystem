import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'app_card.dart';

/// A grouped card of settings with an icon, title and supporting line.
class SettingsCard extends StatelessWidget {
  const SettingsCard({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      elevated: true,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...children,
        ],
      ),
    );
  }
}

/// One setting: an explanatory label on the left, a control sized to its
/// content on the right.
///
/// This replaces the old pattern of wrapping every input in `Expanded`, which
/// stretched a two-character minutes field across half the card and left rows
/// misaligned whenever one field had helper text and its neighbour did not.
/// The control keeps its natural width; the label column absorbs the slack.
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.label,
    required this.child,
    this.help,
    this.helpIsError = false,
  });

  final String label;
  final String? help;
  final bool helpIsError;
  final Widget child;

  /// Below this the label stacks above the control instead of sitting beside
  /// it — side-by-side stops working once the label column gets squeezed.
  static const double _stackBelow = 520;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final labelBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        if (help != null) ...[
          const SizedBox(height: 2),
          Text(
            help!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: helpIsError
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < _stackBelow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              labelBlock,
              const SizedBox(height: AppSpacing.sm),
              Align(alignment: Alignment.centerLeft, child: child),
            ],
          );
        }
        return Row(
          // Top-aligned so a row whose neighbour has help text never floats
          // out of line with the rest of the column.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: labelBlock,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            child,
          ],
        );
      }),
    );
  }
}

/// Hairline between groups of rows inside a [SettingsCard].
class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Divider(height: 1),
      );
}
