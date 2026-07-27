import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/attendance.dart';
import '../providers/attendance_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/attendance_success_sheet.dart';
import 'activity_tab.dart';
import 'home_tab.dart';
import 'profile_tab.dart';
import 'requests_tab.dart';
import 'scan_screen.dart';

/// Bottom-navigation shell: Home, Activity, Requests, Profile — with a
/// persistent scan button in the centre.
///
/// Scanning is the one thing every employee opens this app to do, and it used
/// to be reachable only from a button inside Home. The docked FAB makes it a
/// single tap from anywhere, and it is context-aware: it offers Check In,
/// then Check Out, then hides itself once the day is complete rather than
/// sitting there inviting a scan that would only be rejected.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _tabs = [
    HomeTab(),
    ActivityTab(),
    RequestsTab(),
    ProfileTab(),
  ];

  Future<void> _scan(AttendanceAction action) async {
    final outcome = await Navigator.of(context).push<ScanOutcome>(
      MaterialPageRoute(builder: (_) => ScanScreen(action: action)),
    );
    if (outcome == null || !mounted) return;
    await showAttendanceSuccessSheet(context, action, outcome);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final action = context.watch<AttendanceProvider>().nextAction;

    // Home already carries the full-width hero button; a FAB on top of it
    // would be the same action twice on one screen.
    final showFab = _index != 0 && action != null;

    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      floatingActionButton: !showFab
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _scan(action),
              backgroundColor: action == AttendanceAction.checkIn
                  ? AppColors.success
                  : AppColors.danger,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: Text(action.label),
            ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.event_note_outlined),
              selectedIcon: Icon(Icons.event_note_rounded),
              label: 'Activity',
            ),
            NavigationDestination(
              icon: Icon(Icons.pending_actions_outlined),
              selectedIcon: Icon(Icons.pending_actions_rounded),
              label: 'Requests',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
