import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/attendance_request.dart';
import '../providers/requests_provider.dart';
import '../services/api_client.dart';
import '../utils/formats.dart';
import '../widgets/app_feedback.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/status_chip.dart';
import '../widgets/table_wrapper.dart';

/// Attendance regularization requests with PENDING/APPROVED/REJECTED tabs.
class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = ['PENDING', 'APPROVED', 'REJECTED'];
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<RequestsProvider>();
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex:
          _tabs.contains(provider.status) ? _tabs.indexOf(provider.status) : 0,
    );
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      context
          .read<RequestsProvider>()
          .fetch(toStatus: _tabs[_tabController.index], toPage: 1);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context
            .read<RequestsProvider>()
            .fetch(toStatus: _tabs[_tabController.index]);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _review(AttendanceRequest request, String decision) async {
    final provider = context.read<RequestsProvider>();
    final note = await showDialog<String?>(
      context: context,
      builder: (_) => _ReviewDialog(request: request, decision: decision),
    );
    if (note == null) return; // cancelled
    try {
      await provider.review(request.id, decision, note.isEmpty ? null : note);
      if (mounted) {
        showSuccessSnack(
            context,
            decision == 'APPROVED'
                ? 'Request approved and applied to attendance.'
                : 'Request rejected.');
      }
    } on ApiException catch (e) {
      if (mounted) showErrorSnack(context, e.fullMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestsProvider>();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: theme.colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'Pending'),
              Tab(text: 'Approved'),
              Tab(text: 'Rejected'),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (provider.error != null)
                  ErrorBanner(
                      message: provider.error!,
                      onRetry: () => provider.fetch()),
                Expanded(
                  child: provider.loading
                      ? const Center(child: CircularProgressIndicator())
                      : provider.records.isEmpty
                          ? EmptyState(
                              message:
                                  'No ${provider.status.toLowerCase()} requests.',
                              icon: Icons.pending_actions_outlined)
                          : TableWrapper(
                              child: DataTable(
                                headingTextStyle: theme.textTheme.bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                                columns: [
                                  const DataColumn(label: Text('Employee')),
                                  const DataColumn(label: Text('Date')),
                                  const DataColumn(label: Text('Type')),
                                  const DataColumn(
                                      label: Text('Requested in')),
                                  const DataColumn(
                                      label: Text('Requested out')),
                                  const DataColumn(label: Text('Reason')),
                                  const DataColumn(label: Text('Status')),
                                  if (provider.status == 'PENDING')
                                    const DataColumn(label: Text('Actions'))
                                  else
                                    const DataColumn(
                                        label: Text('Review note')),
                                ],
                                rows: [
                                  for (final r in provider.records)
                                    DataRow(cells: [
                                      DataCell(Text(r.employee == null
                                          ? '—'
                                          : '${r.employee!.employeeId} · ${r.employee!.name}')),
                                      DataCell(Text(r.date)),
                                      DataCell(Text(r.typeLabel)),
                                      DataCell(Text(
                                          formatTime(r.requestedCheckIn))),
                                      DataCell(Text(
                                          formatTime(r.requestedCheckOut))),
                                      DataCell(
                                        Tooltip(
                                          message: r.reason,
                                          child: SizedBox(
                                            width: 180,
                                            child: Text(
                                              r.reason,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(StatusChip.request(r.status)),
                                      if (provider.status == 'PENDING')
                                        DataCell(Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TextButton(
                                              onPressed: () =>
                                                  _review(r, 'APPROVED'),
                                              child: const Text('Approve'),
                                            ),
                                            const SizedBox(width: 4),
                                            TextButton(
                                              style: TextButton.styleFrom(
                                                  foregroundColor: theme
                                                      .colorScheme.error),
                                              onPressed: () =>
                                                  _review(r, 'REJECTED'),
                                              child: const Text('Reject'),
                                            ),
                                          ],
                                        ))
                                      else
                                        DataCell(Text(r.reviewNote ?? '—')),
                                    ]),
                                ],
                              ),
                            ),
                ),
                PaginationBar(
                  pagination: provider.pagination,
                  onPageChanged: (page) => provider.fetch(toPage: page),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Collects an optional review note; pops null on cancel, the note on submit.
class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({required this.request, required this.decision});

  final AttendanceRequest request;
  final String decision;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final approve = widget.decision == 'APPROVED';
    final r = widget.request;
    return AlertDialog(
      title: Text(approve ? 'Approve request' : 'Reject request'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${r.employee?.name ?? 'Employee'} · ${r.typeLabel} · ${formatDay(r.date)}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text('Reason: ${r.reason}',
                style: Theme.of(context).textTheme.bodySmall),
            if (approve) ...[
              const SizedBox(height: 6),
              Text(
                'Approving applies the requested times to the attendance record.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Review note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: approve
              ? null
              : FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: () =>
              Navigator.of(context).pop(_noteController.text.trim()),
          child: Text(approve ? 'Approve' : 'Reject'),
        ),
      ],
    );
  }
}
