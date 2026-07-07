import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/attendance.dart';
import '../providers/missing_checkouts_provider.dart';
import '../services/api_client.dart';
import '../utils/formats.dart';
import '../widgets/app_feedback.dart';
import '../widgets/picker_fields.dart';
import '../widgets/status_chip.dart';
import '../widgets/table_wrapper.dart';

/// Records with a check-in but no check-out; admin resolves each one.
class MissingCheckoutsScreen extends StatefulWidget {
  const MissingCheckoutsScreen({super.key});

  @override
  State<MissingCheckoutsScreen> createState() =>
      _MissingCheckoutsScreenState();
}

class _MissingCheckoutsScreenState extends State<MissingCheckoutsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<MissingCheckoutsProvider>().fetch();
    });
  }

  Future<void> _openResolve(Attendance record) async {
    final provider = context.read<MissingCheckoutsProvider>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ResolveDialog(record: record, provider: provider),
    );
    if (saved == true && mounted) {
      showSuccessSnack(context, 'Check-out resolved.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MissingCheckoutsProvider>();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 200,
                child: DatePickerField(
                  label: 'Date',
                  value: provider.date,
                  lastDate: DateTime.now(),
                  onChanged: (d) {
                    if (d != null) provider.setDate(d);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${provider.records.length} unresolved record${provider.records.length == 1 ? '' : 's'}',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: provider.loading ? null : () => provider.fetch(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (provider.error != null)
            ErrorBanner(
                message: provider.error!, onRetry: () => provider.fetch()),
          Expanded(
            child: provider.loading
                ? const Center(child: CircularProgressIndicator())
                : provider.records.isEmpty
                    ? const EmptyState(
                        message:
                            'No missing check-outs on this date. All records are complete.',
                        icon: Icons.task_alt)
                    : TableWrapper(
                        child: DataTable(
                          headingTextStyle: theme.textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                          columns: const [
                            DataColumn(label: Text('Employee')),
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Check-in')),
                            DataColumn(label: Text('Break (h:mm)')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: [
                            for (final r in provider.records)
                              DataRow(cells: [
                                DataCell(Text(r.employee == null
                                    ? '—'
                                    : '${r.employee!.employeeId} · ${r.employee!.name}')),
                                DataCell(Text(r.date)),
                                DataCell(Text(formatTime(r.checkIn))),
                                DataCell(Text(formatMinutes(r.breakMinutes))),
                                DataCell(StatusChip.attendance(r.status)),
                                DataCell(FilledButton.tonalIcon(
                                  icon: const Icon(Icons.done, size: 16),
                                  label: const Text('Resolve'),
                                  onPressed: () => _openResolve(r),
                                )),
                              ]),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

/// Dialog for `PUT /attendance/:id/resolve-checkout`.
class _ResolveDialog extends StatefulWidget {
  const _ResolveDialog({required this.record, required this.provider});

  final Attendance record;
  final MissingCheckoutsProvider provider;

  @override
  State<_ResolveDialog> createState() => _ResolveDialogState();
}

class _ResolveDialogState extends State<_ResolveDialog> {
  TimeOfDay _checkOut = const TimeOfDay(hour: 18, minute: 0);
  final _noteController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final note = _noteController.text.trim();
    if (note.isEmpty) {
      setState(() => _error = 'A note is required.');
      return;
    }
    final iso = combineDayAndTime(widget.record.date, _checkOut);
    if (iso == null) {
      setState(() => _error = 'Invalid date on this record.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.provider.resolve(widget.record.id, iso, note);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() {
        _saving = false;
        _error = e.fullMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    return AlertDialog(
      title: const Text('Resolve missing check-out'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${r.employee?.name ?? 'Employee'} · ${formatDay(r.date)}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text('Checked in at ${formatTime(r.checkIn)}',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            TimePickerField(
              label: 'Check-out time',
              value: _checkOut,
              onChanged: (t) =>
                  setState(() => _checkOut = t ?? _checkOut),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Note (required)',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Resolve'),
        ),
      ],
    );
  }
}
