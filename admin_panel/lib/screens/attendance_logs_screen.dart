import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/attendance.dart';
import '../models/user.dart';
import '../providers/attendance_logs_provider.dart';
import '../services/api_client.dart';
import '../utils/formats.dart';
import '../widgets/app_feedback.dart';
import '../widgets/employee_autocomplete.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/picker_fields.dart';
import '../widgets/status_chip.dart';
import '../widgets/table_wrapper.dart';

const List<String> kAttendanceStatuses = [
  'PRESENT',
  'LATE',
  'ABSENT',
  'ON_LEAVE',
  'HALF_DAY',
];

/// Filterable, paginated attendance logs with Correct + Manual Entry actions.
class AttendanceLogsScreen extends StatefulWidget {
  const AttendanceLogsScreen({super.key});

  @override
  State<AttendanceLogsScreen> createState() => _AttendanceLogsScreenState();
}

class _AttendanceLogsScreenState extends State<AttendanceLogsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AttendanceLogsProvider>().fetch();
    });
  }

  Future<void> _openCorrect(Attendance record) async {
    final provider = context.read<AttendanceLogsProvider>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CorrectDialog(record: record, provider: provider),
    );
    if (saved == true && mounted) {
      showSuccessSnack(context, 'Attendance record corrected.');
    }
  }

  Future<void> _openManualEntry() async {
    final provider = context.read<AttendanceLogsProvider>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ManualEntryDialog(provider: provider),
    );
    if (saved == true && mounted) {
      showSuccessSnack(context, 'Manual attendance entry created.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceLogsProvider>();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 300,
                child: EmployeeAutocomplete(
                  key: ValueKey(provider.employee?.id ?? 'none'),
                  initial: provider.employee,
                  onSelected: (user) => provider.applyFilters(
                    employee: user,
                    from: provider.from,
                    to: provider.to,
                    status: provider.status,
                  ),
                ),
              ),
              SizedBox(
                width: 170,
                child: DatePickerField(
                  key: ValueKey('logs-from-${provider.from}'),
                  label: 'From',
                  value: provider.from,
                  allowClear: true,
                  onChanged: (d) => provider.applyFilters(
                    employee: provider.employee,
                    from: d,
                    to: provider.to,
                    status: provider.status,
                  ),
                ),
              ),
              SizedBox(
                width: 170,
                child: DatePickerField(
                  key: ValueKey('logs-to-${provider.to}'),
                  label: 'To',
                  value: provider.to,
                  allowClear: true,
                  onChanged: (d) => provider.applyFilters(
                    employee: provider.employee,
                    from: provider.from,
                    to: d,
                    status: provider.status,
                  ),
                ),
              ),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<String?>(
                  key: ValueKey('logs-status-${provider.status}'),
                  initialValue: provider.status,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('All statuses')),
                    for (final s in kAttendanceStatuses)
                      DropdownMenuItem<String?>(
                          value: s, child: Text(s)),
                  ],
                  onChanged: (s) => provider.applyFilters(
                    employee: provider.employee,
                    from: provider.from,
                    to: provider.to,
                    status: s,
                  ),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: const Text('Clear filters'),
                onPressed: () => provider.applyFilters(
                    employee: null, from: null, to: null, status: null),
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.post_add, size: 18),
                label: const Text('Manual Entry'),
                onPressed: _openManualEntry,
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
                            'No attendance records match the current filters.',
                        icon: Icons.receipt_long_outlined)
                    : TableWrapper(
                        child: DataTable(
                          headingTextStyle: theme.textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                          columns: const [
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Employee')),
                            DataColumn(label: Text('Check-in')),
                            DataColumn(label: Text('Check-out')),
                            DataColumn(label: Text('Work (h:mm)')),
                            DataColumn(label: Text('Break (h:mm)')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Flags')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: [
                            for (final r in provider.records)
                              DataRow(cells: [
                                DataCell(Text(r.date)),
                                DataCell(Text(r.employee == null
                                    ? '—'
                                    : '${r.employee!.employeeId} · ${r.employee!.name}')),
                                DataCell(Text(formatTime(r.checkIn))),
                                DataCell(Text(formatTime(r.checkOut))),
                                DataCell(Text(formatMinutes(r.workMinutes))),
                                DataCell(Text(formatMinutes(r.breakMinutes))),
                                DataCell(StatusChip.attendance(r.status)),
                                DataCell(_FlagIcons(record: r)),
                                DataCell(TextButton.icon(
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 16),
                                  label: const Text('Correct'),
                                  onPressed: () => _openCorrect(r),
                                )),
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
    );
  }
}

class _FlagIcons extends StatelessWidget {
  const _FlagIcons({required this.record});

  final Attendance record;

  @override
  Widget build(BuildContext context) {
    final icons = <Widget>[
      if (record.isLate)
        const Tooltip(
          message: 'Late arrival',
          child: Icon(Icons.schedule, size: 18, color: Color(0xFFCF7500)),
        ),
      if (record.isEarlyOut)
        const Tooltip(
          message: 'Early check-out',
          child:
              Icon(Icons.directions_run, size: 18, color: Color(0xFFCF7500)),
        ),
      if (record.correction != null)
        Tooltip(
          message:
              'Corrected by admin${record.correction!.note == null ? '' : ': ${record.correction!.note}'}',
          child: const Icon(Icons.edit_note, size: 18, color: Colors.grey),
        ),
    ];
    if (icons.isEmpty) return const Text('—');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < icons.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          icons[i],
        ],
      ],
    );
  }
}

/// Dialog for `PUT /attendance/:id/correct` — note is required.
class _CorrectDialog extends StatefulWidget {
  const _CorrectDialog({required this.record, required this.provider});

  final Attendance record;
  final AttendanceLogsProvider provider;

  @override
  State<_CorrectDialog> createState() => _CorrectDialogState();
}

class _CorrectDialogState extends State<_CorrectDialog> {
  late TimeOfDay? _checkIn;
  late TimeOfDay? _checkOut;
  late String _status;
  final _noteController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    _checkIn = r.checkIn == null
        ? null
        : TimeOfDay.fromDateTime(r.checkIn!.toLocal());
    _checkOut = r.checkOut == null
        ? null
        : TimeOfDay.fromDateTime(r.checkOut!.toLocal());
    _status = kAttendanceStatuses.contains(r.status) ? r.status : 'PRESENT';
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final note = _noteController.text.trim();
    if (note.isEmpty) {
      setState(() => _error = 'A correction note is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = <String, dynamic>{
      if (_checkIn != null)
        'checkIn': combineDayAndTime(widget.record.date, _checkIn),
      if (_checkOut != null)
        'checkOut': combineDayAndTime(widget.record.date, _checkOut),
      'status': _status,
      'note': note,
    };
    try {
      await widget.provider.correct(widget.record.id, body);
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
      title: const Text('Correct attendance'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
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
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: TimePickerField(
                    label: 'Check-in',
                    value: _checkIn,
                    allowClear: true,
                    onChanged: (t) => setState(() => _checkIn = t),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TimePickerField(
                    label: 'Check-out',
                    value: _checkOut,
                    allowClear: true,
                    onChanged: (t) => setState(() => _checkOut = t),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final s in kAttendanceStatuses)
                    DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: (s) =>
                    setState(() => _status = s ?? _status),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Correction note (required)',
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
              : const Text('Save correction'),
        ),
      ],
    );
  }
}

/// Dialog for `POST /attendance/manual`.
class _ManualEntryDialog extends StatefulWidget {
  const _ManualEntryDialog({required this.provider});

  final AttendanceLogsProvider provider;

  @override
  State<_ManualEntryDialog> createState() => _ManualEntryDialogState();
}

class _ManualEntryDialogState extends State<_ManualEntryDialog> {
  User? _employee;
  DateTime _date = DateTime.now();
  String _status = 'PRESENT';
  TimeOfDay? _checkIn = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay? _checkOut;
  final _noteController = TextEditingController();
  bool _saving = false;
  String? _error;

  bool get _timesDisabled => _status == 'ON_LEAVE' || _status == 'ABSENT';

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final note = _noteController.text.trim();
    if (_employee == null) {
      setState(() => _error = 'Pick an employee first.');
      return;
    }
    if (note.isEmpty) {
      setState(() => _error = 'A note is required.');
      return;
    }
    if (!_timesDisabled && _checkIn == null) {
      setState(() =>
          _error = 'Set a check-in time, or use the ON_LEAVE / ABSENT status.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final day = isoDay(_date);
    final body = <String, dynamic>{
      'employeeId': _employee!.employeeId,
      'date': day,
      if (!_timesDisabled && _checkIn != null)
        'checkIn': combineDayAndTime(day, _checkIn),
      if (!_timesDisabled && _checkOut != null)
        'checkOut': combineDayAndTime(day, _checkOut),
      'status': _status,
      'note': note,
    };
    try {
      await widget.provider.manualEntry(body);
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
    return AlertDialog(
      title: const Text('Manual attendance entry'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EmployeeAutocomplete(
                onSelected: (u) => setState(() => _employee = u),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: DatePickerField(
                    label: 'Date',
                    value: _date,
                    lastDate: DateTime.now(),
                    onChanged: (d) =>
                        setState(() => _date = d ?? _date),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final s in kAttendanceStatuses)
                        DropdownMenuItem(value: s, child: Text(s)),
                    ],
                    onChanged: (s) =>
                        setState(() => _status = s ?? _status),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: TimePickerField(
                    label: 'Check-in',
                    value: _timesDisabled ? null : _checkIn,
                    enabled: !_timesDisabled,
                    allowClear: true,
                    onChanged: (t) => setState(() => _checkIn = t),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TimePickerField(
                    label: 'Check-out (optional)',
                    value: _timesDisabled ? null : _checkOut,
                    enabled: !_timesDisabled,
                    allowClear: true,
                    onChanged: (t) => setState(() => _checkOut = t),
                  ),
                ),
              ]),
              if (_timesDisabled)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Times are not recorded for $_status entries.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
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
              : const Text('Create entry'),
        ),
      ],
    );
  }
}
