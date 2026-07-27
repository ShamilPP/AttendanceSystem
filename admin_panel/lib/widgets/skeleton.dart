import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'app_card.dart';

/// A softly pulsing placeholder block.
///
/// Skeletons beat a centered spinner for anything with a known shape: the
/// layout does not jump when data lands, and the admin can already see how
/// much is coming.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: base.withValues(alpha: 0.05 + 0.05 * _controller.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Placeholder grid matching the dashboard's stat tiles.
class StatGridSkeleton extends StatelessWidget {
  const StatGridSkeleton({super.key, this.count = 8});

  final int count;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = (constraints.maxWidth / 240).floor().clamp(1, 4);
      final width =
          (constraints.maxWidth - (columns - 1) * AppSpacing.lg) / columns;
      return Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.lg,
        children: [
          for (var i = 0; i < count; i++)
            SizedBox(
              width: width,
              child: const AppCard(
                elevated: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Skeleton(width: 42, height: 42, radius: 12),
                    SizedBox(height: AppSpacing.lg),
                    Skeleton(width: 64, height: 28),
                    SizedBox(height: AppSpacing.sm),
                    Skeleton(width: 100, height: 12),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}

/// Placeholder rows matching a data table, including the header strip.
class TableSkeleton extends StatelessWidget {
  const TableSkeleton({super.key, this.rows = 8, this.columns = 5});

  final int rows;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Deterministic, uneven widths read as text far better than equal bars.
    const widths = [0.9, 0.6, 0.75, 0.5, 0.8, 0.65];

    Widget cell(int i, {double height = 12}) => Expanded(
          flex: ((widths[i % widths.length]) * 100).round(),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: widths[i % widths.length],
              child: Skeleton(height: height),
            ),
          ),
        );

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.5),
            child: Row(
              children: [
                for (var c = 0; c < columns; c++) ...[
                  cell(c, height: 10),
                  if (c < columns - 1) const SizedBox(width: AppSpacing.lg),
                ],
              ],
            ),
          ),
          for (var r = 0; r < rows; r++) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
              child: Row(
                children: [
                  for (var c = 0; c < columns; c++) ...[
                    cell(c + r),
                    if (c < columns - 1) const SizedBox(width: AppSpacing.lg),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
