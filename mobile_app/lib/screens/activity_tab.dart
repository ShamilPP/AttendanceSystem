import 'package:flutter/material.dart';

import 'history_tab.dart';
import 'summary_screen.dart';

/// Your attendance record, at two zoom levels.
///
/// History (day by day) and the monthly summary are the same data — one
/// itemised, one aggregated. They used to live in different places: History
/// was a bottom-nav tab while Summary was a pushed route reachable from two
/// separate buttons on Home. Same question, three doors. Now it is one tab
/// with two views.
class ActivityTab extends StatelessWidget {
  const ActivityTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My activity'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.event_note_rounded), text: 'History'),
              Tab(icon: Icon(Icons.insights_rounded), text: 'Summary'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            HistoryView(),
            SummaryView(),
          ],
        ),
      ),
    );
  }
}
