import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/catalog_provider.dart';
import '../providers/reports_provider.dart';
import '../services/api_client.dart';
import '../services/file_download.dart';
import '../theme/app_spacing.dart';
import '../utils/formats.dart';
import '../utils/json_utils.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_feedback.dart';
import '../widgets/picker_fields.dart';
import '../widgets/states.dart';
import '../widgets/table_wrapper.dart';

/// Report builder: 6 report types, per-type date controls, results table,
/// and an Excel export of the same query.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CatalogProvider>().ensureLoaded();
    });
  }

  Future<void> _export() async {
    final provider = context.read<ReportsProvider>();
    try {
      final download = await provider.exportXlsx();
      downloadFileBytes(
        bytes: download.bytes,
        filename: download.filename,
        mimeType: xlsxMimeType,
      );
      if (mounted) {
        showSuccessSnack(context, 'Downloading ${download.filename}…');
      }
    } on ApiException catch (e) {
      if (mounted) showErrorSnack(context, e.fullMessage);
    }
  }

  bool _isAttendanceType(ReportType type) =>
      type == ReportType.daily ||
      type == ReportType.weekly ||
      type == ReportType.monthly;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportsProvider>();
    final catalog = context.watch<CatalogProvider>();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final type in ReportType.values)
                      ChoiceChip(
                        label: Text(type.label),
                        selected: provider.type == type,
                        onSelected: (selected) {
                          if (selected) provider.setType(type);
                        },
                      ),
                  ],
                ),
                const Divider(height: AppSpacing.xxl),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (provider.type == ReportType.daily)
                      SizedBox(
                        width: 190,
                        child: DatePickerField(
                          label: 'Date',
                          value: provider.date,
                          lastDate: DateTime.now(),
                          onChanged: (d) {
                            if (d != null) provider.setParams(date: d);
                          },
                        ),
                      ),
                    if (provider.type == ReportType.weekly ||
                        provider.type == ReportType.lateArrivals ||
                        provider.type == ReportType.earlyCheckouts) ...[
                      SizedBox(
                        width: 180,
                        child: DatePickerField(
                          label: 'From',
                          value: provider.from,
                          onChanged: (d) {
                            if (d != null) provider.setParams(from: d);
                          },
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: DatePickerField(
                          label: 'To',
                          value: provider.to,
                          onChanged: (d) {
                            if (d != null) provider.setParams(to: d);
                          },
                        ),
                      ),
                    ],
                    if (provider.type == ReportType.monthly ||
                        provider.type == ReportType.workingHours)
                      SizedBox(
                        width: 230,
                        child: MonthField(
                          value: provider.month,
                          onChanged: (m) => provider.setParams(month: m),
                        ),
                      ),
                    if (_isAttendanceType(provider.type))
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<String?>(
                          key: ValueKey('report-dept-${provider.departmentId}'),
                          initialValue: provider.departmentId,
                          decoration:
                              const InputDecoration(labelText: 'Department'),
                          items: [
                            const DropdownMenuItem<String?>(
                                value: null, child: Text('All departments')),
                            for (final d in catalog.departments)
                              DropdownMenuItem<String?>(
                                  value: d.id, child: Text(d.name)),
                          ],
                          onChanged: (v) => provider.setParams(
                              departmentId: v, clearDepartment: v == null),
                        ),
                      ),
                    AppButton(
                      label: 'Run report',
                      icon: Icons.play_arrow,
                      loading: provider.loading,
                      onPressed: () => provider.run(),
                    ),
                    AppButton.outline(
                      label: 'Export Excel',
                      icon: Icons.download,
                      loading: provider.exporting,
                      onPressed: _export,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (provider.error != null)
            ErrorBanner(message: provider.error!, onRetry: () => provider.run()),
          Expanded(
            child: provider.loading
                ? const LoadingState(message: 'Running report…')
                : !provider.hasRun
                    ? const EmptyState(
                        title: 'Build a report',
                        message:
                            'Pick a report type and date range, then press "Run report".',
                        icon: Icons.insert_chart_outlined)
                    : provider.rows.isEmpty
                        ? const EmptyState(
                            title: 'No rows',
                            message: 'The report returned no data.',
                            icon: Icons.search_off)
                        : AppCard(
                            padding: EdgeInsets.zero,
                            child: ClipRRect(
                              borderRadius: AppRadius.cardR,
                              child: _ReportTable(
                                  type: provider.type, rows: provider.rows),
                            ),
                          ),
          ),
          if (provider.hasRun && provider.rows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                '${provider.rows.length} row${provider.rows.length == 1 ? '' : 's'} · durations shown as h:mm',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReportColumn {
  const _ReportColumn(this.label, this.cell, {this.numeric = false});

  final String label;
  final String Function(Map<String, dynamic> row) cell;
  final bool numeric;
}

/// Renders the rows of the active report type with tolerant field access
/// (handles both flat rows and rows with a nested `employee` object).
class _ReportTable extends StatelessWidget {
  const _ReportTable({required this.type, required this.rows});

  final ReportType type;
  final List<Map<String, dynamic>> rows;

  static String _text(dynamic value) {
    if (value == null) return '—';
    final s = value.toString();
    return s.isEmpty ? '—' : s;
  }

  static Map<String, dynamic> _employee(Map<String, dynamic> row) =>
      row['employee'] is Map ? jsonMap(row['employee']) : row;

  static String _employeeId(Map<String, dynamic> row) =>
      _text(_employee(row)['employeeId']);

  static String _name(Map<String, dynamic> row) =>
      _text(_employee(row)['name']);

  static String _department(Map<String, dynamic> row) {
    final value = row['department'] ?? _employee(row)['department'];
    if (value is Map) return _text(value['name']);
    return _text(value);
  }

  static String _time(Map<String, dynamic> row, String key) =>
      formatTime(jsonDateTime(row[key]));

  static String _duration(Map<String, dynamic> row, String key) =>
      row[key] == null ? '—' : formatMinutes(jsonInt(row[key]));

  static String _count(Map<String, dynamic> row, String key) =>
      '${jsonInt(row[key])}';

  List<_ReportColumn> get _columns {
    switch (type) {
      case ReportType.daily:
        return [
          _ReportColumn('Employee ID', _employeeId),
          _ReportColumn('Name', _name),
          _ReportColumn('Department', _department),
          _ReportColumn('Status', (r) => _text(r['status'])),
          _ReportColumn('Check-in', (r) => _time(r, 'checkIn')),
          _ReportColumn('Check-out', (r) => _time(r, 'checkOut')),
          _ReportColumn('Work (h:mm)', (r) => _duration(r, 'workMinutes'),
              numeric: true),
        ];
      case ReportType.weekly:
      case ReportType.monthly:
        return [
          _ReportColumn('Employee ID', _employeeId),
          _ReportColumn('Name', _name),
          _ReportColumn('Department', _department),
          _ReportColumn('Present', (r) => _count(r, 'presentDays'),
              numeric: true),
          _ReportColumn('Late', (r) => _count(r, 'lateDays'), numeric: true),
          _ReportColumn('Absent', (r) => _count(r, 'absentDays'),
              numeric: true),
          _ReportColumn('Leave', (r) => _count(r, 'leaveDays'), numeric: true),
          _ReportColumn(
              'Work (h:mm)', (r) => _duration(r, 'totalWorkMinutes'),
              numeric: true),
        ];
      case ReportType.workingHours:
        return [
          _ReportColumn('Employee ID', _employeeId),
          _ReportColumn('Name', _name),
          _ReportColumn('Department', _department),
          _ReportColumn('Days worked', (r) => _count(r, 'daysWorked'),
              numeric: true),
          _ReportColumn(
              'Total work (h:mm)', (r) => _duration(r, 'totalWorkMinutes'),
              numeric: true),
          _ReportColumn(
              'Avg/day (h:mm)', (r) => _duration(r, 'averageWorkMinutes'),
              numeric: true),
        ];
      case ReportType.lateArrivals:
        return [
          _ReportColumn('Employee ID', _employeeId),
          _ReportColumn('Name', _name),
          _ReportColumn('Department', _department),
          _ReportColumn('Date', (r) => _text(r['date'])),
          _ReportColumn('Check-in', (r) => _time(r, 'checkIn')),
          _ReportColumn('Late by (h:mm)', (r) => _duration(r, 'minutesLate'),
              numeric: true),
        ];
      case ReportType.earlyCheckouts:
        return [
          _ReportColumn('Employee ID', _employeeId),
          _ReportColumn('Name', _name),
          _ReportColumn('Department', _department),
          _ReportColumn('Date', (r) => _text(r['date'])),
          _ReportColumn('Check-out', (r) => _time(r, 'checkOut')),
          _ReportColumn(
              'Early by (h:mm)', (r) => _duration(r, 'minutesEarly'),
              numeric: true),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final columns = _columns;
    return TableWrapper(
      child: DataTable(
        columns: [
          for (final c in columns)
            DataColumn(label: Text(c.label), numeric: c.numeric),
        ],
        rows: [
          for (final row in rows)
            DataRow(cells: [
              for (final c in columns) DataCell(Text(c.cell(row))),
            ]),
        ],
      ),
    );
  }
}
