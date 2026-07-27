import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../utils/formats.dart';

/// Read-only field that opens a date picker on tap.
class DatePickerField extends StatelessWidget {
  const DatePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.allowClear = false,
    this.firstDate,
    this.lastDate,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool allowClear;
  final DateTime? firstDate;
  final DateTime? lastDate;

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime.now(),
      firstDate: firstDate ?? DateTime(2020),
      lastDate: lastDate ?? DateTime(2035),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(6),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: allowClear && value != null
              ? IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => onChanged(null),
                )
              : const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(
          value == null ? '—' : DateFormat('d MMM yyyy').format(value!),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

/// Read-only field that opens a time picker on tap.
class TimePickerField extends StatelessWidget {
  const TimePickerField({
    super.key,
    this.label,
    required this.value,
    required this.onChanged,
    this.allowClear = false,
    this.enabled = true,
  });

  /// Omit when the field already sits next to its own label (e.g. a
  /// `SettingRow`), so no empty label gutter is reserved above the value.
  final String? label;
  final TimeOfDay? value;
  final ValueChanged<TimeOfDay?> onChanged;
  final bool allowClear;
  final bool enabled;

  Future<void> _pick(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: value ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? () => _pick(context) : null,
      borderRadius: BorderRadius.circular(6),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: (label == null || label!.isEmpty) ? null : label,
          border: const OutlineInputBorder(),
          isDense: true,
          enabled: enabled,
          suffixIcon: allowClear && value != null && enabled
              ? IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => onChanged(null),
                )
              : const Icon(Icons.schedule_outlined, size: 18),
        ),
        child: Text(
          value == null ? '—' : timeOfDayToHHmm(value!),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: enabled ? null : Theme.of(context).disabledColor,
              ),
        ),
      ),
    );
  }
}

/// Month stepper (`< July 2026 >`) used by monthly reports.
class MonthField extends StatelessWidget {
  const MonthField({super.key, required this.value, required this.onChanged});

  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final atCurrentMonth = value.year == now.year && value.month == now.month;
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Month',
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Previous month',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: () =>
                onChanged(DateTime(value.year, value.month - 1)),
          ),
          Expanded(
            child: Text(
              monthLabel(value),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          IconButton(
            tooltip: 'Next month',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: atCurrentMonth
                ? null
                : () => onChanged(DateTime(value.year, value.month + 1)),
          ),
        ],
      ),
    );
  }
}
