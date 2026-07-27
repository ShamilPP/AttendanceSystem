import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_spacing.dart';
import 'fading_scroll_view.dart';

/// One sub-tab of a grouped section (Attendance, People).
class SectionTab {
  const SectionTab({
    required this.label,
    required this.icon,
    required this.route,
    this.badge,
  });

  final String label;
  final IconData icon;
  final String route;

  /// Optional count shown as a pill next to the label (0/null hides it).
  final int? badge;
}

/// Standard page chrome: a title row with optional description and trailing
/// actions, an optional sub-tab bar, then the page body.
///
/// Every section uses this so headers, paddings and the tab strip are
/// pixel-identical across the panel instead of each screen inventing its own.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.description,
    this.actions = const [],
    this.tabs = const [],
    this.currentRoute,
    this.fadeScroll = true,
    this.padding = const EdgeInsets.fromLTRB(
        AppSpacing.xxl, AppSpacing.xl, AppSpacing.xxl, AppSpacing.xxl),
  });

  final String title;
  final String? description;
  final List<Widget> actions;
  final List<SectionTab> tabs;
  final String? currentRoute;
  final EdgeInsets padding;

  /// Softens the scroll edges so content dissolves under the fixed header
  /// instead of being sliced mid-glyph. Turn off when the child manages its
  /// own scroll area (e.g. a page with a pinned footer that must not fade).
  final bool fadeScroll;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
              padding.left, padding.top, padding.right, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    if (description != null) ...[
                      const SizedBox(height: 2),
                      Text(description!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
        if (tabs.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: padding.left),
            child: _TabStrip(tabs: tabs, currentRoute: currentRoute),
          ),
        ],
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                padding.left, AppSpacing.lg, padding.right, padding.bottom),
            child: fadeScroll ? FadingScrollView(child: child) : child,
          ),
        ),
      ],
    );
  }
}

/// Pill-style segmented tabs that navigate by URL (so each sub-tab is
/// bookmarkable and the browser back button steps between them).
class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.tabs, required this.currentRoute});

  final List<SectionTab> tabs;
  final String? currentRoute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: AppRadius.buttonR,
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final tab in tabs)
            _TabChip(tab: tab, selected: tab.route == currentRoute),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.tab, required this.selected});

  final SectionTab tab;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = selected
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant;
    return Material(
      color: selected ? theme.colorScheme.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      elevation: selected ? 1 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: selected ? null : () => context.go(tab.route),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tab.icon, size: 17, color: fg),
              const SizedBox(width: 8),
              Text(
                tab.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: fg,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (tab.badge != null && tab.badge! > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${tab.badge}',
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
