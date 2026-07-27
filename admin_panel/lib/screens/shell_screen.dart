import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/attention_provider.dart';
import '../providers/auth_provider.dart';
import '../router/routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_avatar.dart';

/// A top-level navigation entry.
class _NavItem {
  const _NavItem(
    this.label,
    this.icon,
    this.selectedIcon,
    this.route, {
    this.badge,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// The route this item navigates to.
  final String route;

  /// Reads a live count off [AttentionProvider] for the badge, when relevant.
  final int Function(AttentionProvider)? badge;

  /// A route belongs to this item when it is the item's route or nested below
  /// it, so `/attendance/logs` keeps "Attendance" highlighted.
  bool matches(String location) =>
      route == Routes.overview
          ? location == Routes.overview
          : location == route || location.startsWith('$route/');
}

/// Primary work: the daily loop of an attendance admin.
const _primaryNav = <_NavItem>[
  _NavItem('Overview', Icons.dashboard_outlined, Icons.dashboard,
      Routes.overview),
  _NavItem(
    'Attendance',
    Icons.fact_check_outlined,
    Icons.fact_check,
    Routes.attendance,
    badge: _missingBadge,
  ),
  _NavItem(
    'Requests',
    Icons.pending_actions_outlined,
    Icons.pending_actions,
    Routes.requests,
    badge: _pendingBadge,
  ),
  _NavItem('People', Icons.people_alt_outlined, Icons.people_alt,
      Routes.people),
  _NavItem('Reports', Icons.insert_chart_outlined, Icons.insert_chart,
      Routes.reports),
];

/// Setup: touched rarely, so it is visually separated from the daily loop.
const _secondaryNav = <_NavItem>[
  _NavItem('QR code', Icons.qr_code_2_outlined, Icons.qr_code_2, Routes.qr),
  _NavItem('Settings', Icons.settings_outlined, Icons.settings,
      Routes.settings),
];

int _missingBadge(AttentionProvider a) => a.missingCheckouts;
int _pendingBadge(AttentionProvider a) => a.pendingRequests;

/// Authenticated layout: responsive navigation (extended rail → icon rail →
/// drawer) around the routed [child].
///
/// The shell is built once by the `ShellRoute`, so switching sections no
/// longer rebuilds — and reset the filters and scroll position of — the
/// screen being left.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key, required this.child});

  final Widget child;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AttentionProvider>().start();
    });
  }

  @override
  void dispose() {
    // The shell only unmounts on logout; stop polling so the timer does not
    // keep firing 401s against a cleared token.
    context.read<AttentionProvider>().stop();
    super.dispose();
  }

  void _go(String route) {
    context.go(route);
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      _scaffoldKey.currentState?.closeDrawer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < AppBreakpoints.compact;
    final extended = width >= AppBreakpoints.railExtended;
    final location = GoRouterState.of(context).uri.path;
    final theme = Theme.of(context);

    return Scaffold(
      key: _scaffoldKey,
      drawer: compact
          ? Drawer(
              child: _NavContent(
                location: location,
                extended: true,
                onSelect: _go,
              ),
            )
          : null,
      appBar: compact
          ? _CompactTopBar(scaffoldKey: _scaffoldKey)
          : null,
      body: Row(
        children: [
          if (!compact)
            _NavContent(
              location: location,
              extended: extended,
              onSelect: _go,
            ),
          if (!compact)
            VerticalDivider(
                width: 1, thickness: 1, color: theme.colorScheme.outlineVariant),
          Expanded(
            child: ColoredBox(
              color: theme.scaffoldBackgroundColor,
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Slim app bar used only on narrow screens (each page renders its own title
/// via `PageScaffold`, so the bar just carries the menu button and account).
class _CompactTopBar extends StatelessWidget implements PreferredSizeWidget {
  const _CompactTopBar({required this.scaffoldKey});

  final GlobalKey<ScaffoldState> scaffoldKey;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return AppBar(
      toolbarHeight: 56,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () => scaffoldKey.currentState?.openDrawer(),
      ),
      title: Text('NexCrew',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800)),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: PopupMenuButton<String>(
            tooltip: 'Account',
            offset: const Offset(0, 48),
            onSelected: (v) {
              if (v == 'logout') context.read<AuthProvider>().logout();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'logout',
                child: Row(children: [
                  Icon(Icons.logout, size: 18),
                  SizedBox(width: 10),
                  Text('Log out'),
                ]),
              ),
            ],
            child: AppAvatar(name: auth.user?.name ?? 'Admin', radius: 16),
          ),
        ),
      ],
    );
  }
}

/// Navigation body shared by the rail and the drawer.
class _NavContent extends StatelessWidget {
  const _NavContent({
    required this.location,
    required this.extended,
    required this.onSelect,
  });

  final String location;
  final bool extended;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final attention = context.watch<AttentionProvider>();
    final today = DateFormat('EEE, d MMM').format(DateTime.now());

    Widget brand() => Padding(
          padding: EdgeInsets.fromLTRB(
              extended ? 20 : 12, 20, extended ? 20 : 12, 14),
          child: Row(
            mainAxisAlignment:
                extended ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      Color.lerp(theme.colorScheme.primary, Colors.black, 0.2)!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child:
                    const Icon(Icons.fingerprint, color: Colors.white, size: 22),
              ),
              if (extended) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('NexCrew',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      Text(today,
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );

    Widget navItem(_NavItem item) {
      final selected = item.matches(location);
      final count = item.badge?.call(attention) ?? 0;
      final fg = selected
          ? theme.colorScheme.onSurface
          : theme.colorScheme.onSurfaceVariant;

      final badge = count == 0
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              constraints: const BoxConstraints(minWidth: 20),
              decoration: BoxDecoration(
                color: AppColors.late,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
            );

      final content = Container(
        margin:
            EdgeInsets.symmetric(horizontal: extended ? 12 : 8, vertical: 2),
        padding:
            EdgeInsets.symmetric(horizontal: extended ? 14 : 0, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primaryContainer : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment:
              extended ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            // Collapsed rail has no room for a label, so the badge rides the
            // icon instead of sitting beside it.
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 22,
                  color: selected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
                if (!extended && badge != null)
                  Positioned(right: -8, top: -6, child: badge),
              ],
            ),
            if (extended) ...[
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: fg,
                  ),
                ),
              ),
              ?badge,
            ],
          ],
        ),
      );

      return Tooltip(
        message: extended
            ? ''
            : (count > 0 ? '${item.label} ($count)' : item.label),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onSelect(item.route),
            child: content,
          ),
        ),
      );
    }

    Widget groupLabel(String text) => extended
        ? Padding(
            padding: const EdgeInsets.fromLTRB(26, 16, 20, 6),
            child: Text(
              text.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        : const SizedBox(height: 14);

    Widget footer() => Padding(
          padding: EdgeInsets.all(extended ? 12 : 8),
          child: extended
              ? Row(
                  children: [
                    AppAvatar(name: auth.user?.name ?? 'Admin', radius: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(auth.user?.name ?? 'Admin',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          Text('Administrator',
                              style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Log out',
                      icon: const Icon(Icons.logout, size: 20),
                      onPressed: () => context.read<AuthProvider>().logout(),
                    ),
                  ],
                )
              : Column(
                  children: [
                    AppAvatar(name: auth.user?.name ?? 'Admin', radius: 16),
                    const SizedBox(height: 8),
                    IconButton(
                      tooltip: 'Log out',
                      icon: const Icon(Icons.logout, size: 20),
                      onPressed: () => context.read<AuthProvider>().logout(),
                    ),
                  ],
                ),
        );

    return Container(
      width: extended ? 248 : 76,
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          brand(),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.sm),
                  for (final item in _primaryNav) navItem(item),
                  groupLabel('Setup'),
                  for (final item in _secondaryNav) navItem(item),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          footer(),
        ],
      ),
    );
  }
}
