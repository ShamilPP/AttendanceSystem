import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
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

/// Authenticated layout: left navigation rail + top bar + section body.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final section = _sections[_index];

    return Scaffold(
      appBar: AppBar(
        title: Text(section.label),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.colorScheme.surface,
        actions: [
          Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  auth.user?.name.isNotEmpty == true
                      ? auth.user!.name.substring(0, 1).toUpperCase()
                      : 'A',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onPrimaryContainer),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(auth.user?.name ?? 'Admin',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  Text('Administrator',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final extended = MediaQuery.of(context).size.width >= 1280;
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: NavigationRail(
                      selectedIndex: _index,
                      extended: extended,
                      minExtendedWidth: 210,
                      labelType: extended
                          ? NavigationRailLabelType.none
                          : NavigationRailLabelType.all,
                      onDestinationSelected: (i) =>
                          setState(() => _index = i),
                      destinations: [
                        for (final s in _sections)
                          NavigationRailDestination(
                            icon: Icon(s.icon),
                            selectedIcon: Icon(s.selectedIcon),
                            label: Text(
                              s.label,
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: section.builder(context)),
        ],
      ),
    );
  }
}
