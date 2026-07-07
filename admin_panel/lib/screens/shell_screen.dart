import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_avatar.dart';
import 'attendance_logs_screen.dart';
import 'catalog_screen.dart';
import 'dashboard_screen.dart';
import 'employees_screen.dart';
import 'live_attendance_screen.dart';
import 'missing_checkouts_screen.dart';
import 'office_settings_screen.dart';
import 'qr_display_screen.dart';
import 'reports_screen.dart';
import 'requests_screen.dart';

class _Section {
  const _Section(this.label, this.icon, this.selectedIcon, this.builder);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final WidgetBuilder builder;
}

/// Authenticated layout: responsive navigation (extended rail → icon rail →
/// drawer) + a top bar with the page title and today's date.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _index = 0;

  static final List<_Section> _sections = [
    _Section('Dashboard', Icons.dashboard_outlined, Icons.dashboard,
        (_) => const DashboardScreen()),
    _Section('Live Attendance', Icons.sensors_outlined, Icons.sensors,
        (_) => const LiveAttendanceScreen()),
    _Section('Attendance Logs', Icons.receipt_long_outlined, Icons.receipt_long,
        (_) => const AttendanceLogsScreen()),
    _Section('Requests', Icons.pending_actions_outlined, Icons.pending_actions,
        (_) => const RequestsScreen()),
    _Section('Missing Check-outs', Icons.timer_off_outlined, Icons.timer_off,
        (_) => const MissingCheckoutsScreen()),
    _Section('Employees', Icons.people_alt_outlined, Icons.people_alt,
        (_) => const EmployeesScreen()),
    _Section('Departments', Icons.account_tree_outlined, Icons.account_tree,
        (_) => const CatalogScreen()),
    _Section('Office Settings', Icons.settings_outlined, Icons.settings,
        (_) => const OfficeSettingsScreen()),
    _Section('QR Display', Icons.qr_code_2_outlined, Icons.qr_code_2,
        (_) => const QrDisplayScreen()),
    _Section('Reports', Icons.insert_chart_outlined, Icons.insert_chart,
        (_) => const ReportsScreen()),
  ];

  void _select(int i) {
    setState(() => _index = i);
    // Close the drawer if it is open (compact layout).
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      _scaffoldKey.currentState?.closeDrawer();
    }
  }

  Future<void> _logout() => context.read<AuthProvider>().logout();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < AppBreakpoints.compact;
    final extended = width >= AppBreakpoints.railExtended;
    final section = _sections[_index];
    final theme = Theme.of(context);

    return Scaffold(
      key: _scaffoldKey,
      drawer: compact
          ? Drawer(
              child: _NavContent(
                sections: _sections,
                selectedIndex: _index,
                extended: true,
                onSelect: _select,
                onLogout: _logout,
              ),
            )
          : null,
      appBar: _TopBar(
        title: section.label,
        scaffoldKey: _scaffoldKey,
        showMenuButton: compact,
      ),
      body: Row(
        children: [
          if (!compact)
            _NavRail(
              sections: _sections,
              selectedIndex: _index,
              extended: extended,
              onSelect: (i) => setState(() => _index = i),
              onLogout: _logout,
            ),
          if (!compact)
            VerticalDivider(width: 1, thickness: 1, color: theme.colorScheme.outlineVariant),
          Expanded(
            child: ColoredBox(
              color: theme.scaffoldBackgroundColor,
              child: section.builder(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Top bar: (menu on compact) + page title + today's date.
class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  const _TopBar({
    required this.title,
    required this.showMenuButton,
    required this.scaffoldKey,
  });

  final String title;
  final bool showMenuButton;
  final GlobalKey<ScaffoldState> scaffoldKey;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final today = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());

    return AppBar(
      toolbarHeight: 64,
      titleSpacing: showMenuButton ? 0 : 24,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          Text(today,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
      actions: [
        if (showMenuButton)
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
          )
        else
          const SizedBox(width: 12),
      ],
      leading: showMenuButton
          ? IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => scaffoldKey.currentState?.openDrawer(),
            )
          : null,
    );
  }
}

/// The scrolling navigation rail used on tablet/desktop widths.
class _NavRail extends StatelessWidget {
  const _NavRail({
    required this.sections,
    required this.selectedIndex,
    required this.extended,
    required this.onSelect,
    required this.onLogout,
  });

  final List<_Section> sections;
  final int selectedIndex;
  final bool extended;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: _NavContent(
              sections: sections,
              selectedIndex: selectedIndex,
              extended: extended,
              onSelect: onSelect,
              onLogout: onLogout,
              rail: true,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared navigation body used by both the rail and the drawer.
class _NavContent extends StatelessWidget {
  const _NavContent({
    required this.sections,
    required this.selectedIndex,
    required this.extended,
    required this.onSelect,
    required this.onLogout,
    this.rail = false,
  });

  final List<_Section> sections;
  final int selectedIndex;
  final bool extended;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;
  final bool rail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();

    Widget brand() => Padding(
          padding: EdgeInsets.fromLTRB(
              extended ? 20 : 12, 20, extended ? 20 : 12, 12),
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
                child: const Icon(Icons.fingerprint,
                    color: Colors.white, size: 22),
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
                      Text('Attendance Admin',
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );

    Widget navItem(int i, _Section s) {
      final selected = i == selectedIndex;
      final content = Container(
        margin: EdgeInsets.symmetric(
            horizontal: extended ? 12 : 8, vertical: 2),
        padding: EdgeInsets.symmetric(
            horizontal: extended ? 14 : 0, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primaryContainer : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment:
              extended ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            Icon(
              selected ? s.selectedIcon : s.icon,
              size: 22,
              color: selected
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurfaceVariant,
            ),
            if (extended) ...[
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  s.label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
      return Tooltip(
        message: extended ? '' : s.label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onSelect(i),
            child: content,
          ),
        ),
      );
    }

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
                      onPressed: onLogout,
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
                      onPressed: onLogout,
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
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (var i = 0; i < sections.length; i++)
                    navItem(i, sections[i]),
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
