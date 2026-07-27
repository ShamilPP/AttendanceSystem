import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/attendance_request.dart';
import '../providers/attendance_provider.dart';
import '../services/api_client.dart';
import '../theme/app_spacing.dart';
import '../utils/formatters.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';

/// Form for a new attendance-regularization request.
class NewRequestScreen extends StatefulWidget {
  const NewRequestScreen({
    super.key,
    this.initialDate,
    this.initialType,
    this.initialCheckIn,
    this.initialCheckOut,
  });

  /// Pre-selects the day being corrected — set when the form is opened from a
  /// history record, so the employee never retypes a date they just tapped.
  final DateTime? initialDate;

  /// Pre-selects the request type.
  final String? initialType;

  /// Pre-fills the requested times. Used when recovering a scan that never
  /// reached the server: the moment they actually scanned is the moment that
  /// should be recorded, not whenever the form is finally submitted.
  final DateTime? initialCheckIn;
  final DateTime? initialCheckOut;

  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  late DateTime _date = widget.initialDate ?? DateTime.now();
  late String _type = widget.initialType ?? AttendanceRequestType.missedCheckIn;
  late TimeOfDay? _checkInTime = widget.initialCheckIn == null
      ? null
      : TimeOfDay.fromDateTime(widget.initialCheckIn!);
  late TimeOfDay? _checkOutTime = widget.initialCheckOut == null
      ? null
      : TimeOfDay.fromDateTime(widget.initialCheckOut!);
  bool _busy = false;
  String? _serverError;

  bool get _needsCheckIn =>
      _type == AttendanceRequestType.missedCheckIn ||
      _type == AttendanceRequestType.fullDay;

  bool get _needsCheckOut =>
      _type == AttendanceRequestType.missedCheckOut ||
      _type == AttendanceRequestType.fullDay;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      helpText: 'Date to regularize',
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickTime({required bool checkIn}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (checkIn ? _checkInTime : _checkOutTime) ??
          (checkIn
              ? const TimeOfDay(hour: 9, minute: 0)
              : const TimeOfDay(hour: 18, minute: 0)),
      helpText:
          checkIn ? 'Requested check-in time' : 'Requested check-out time',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (checkIn) {
        _checkInTime = picked;
      } else {
        _checkOutTime = picked;
      }
    });
  }

  DateTime _combine(TimeOfDay time) =>
      DateTime(_date.year, _date.month, _date.day, time.hour, time.minute);

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    String? timeError;
    if (_needsCheckIn && _checkInTime == null) {
      timeError = 'Please pick the requested check-in time.';
    } else if (_needsCheckOut && _checkOutTime == null) {
      timeError = 'Please pick the requested check-out time.';
    } else if (_type == AttendanceRequestType.fullDay &&
        _checkInTime != null &&
        _checkOutTime != null) {
      final inDt = _combine(_checkInTime!);
      final outDt = _combine(_checkOutTime!);
      if (!outDt.isAfter(inDt)) {
        timeError = 'Check-out time must be after check-in time.';
      }
    }
    if (timeError != null) {
      setState(() => _serverError = timeError);
      return;
    }

    setState(() {
      _busy = true;
      _serverError = null;
    });
    final provider = context.read<AttendanceProvider>();
    try {
      await provider.createRequest(
        date: _date,
        type: _type,
        requestedCheckIn: _needsCheckIn && _checkInTime != null
            ? _combine(_checkInTime!)
            : null,
        requestedCheckOut: _needsCheckOut && _checkOutTime != null
            ? _combine(_checkOutTime!)
            : null,
        reason: _reasonController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _serverError = e.errors.isNotEmpty
            ? e.errors.map((f) => f.message).join('\n')
            : e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('New Request')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_serverError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: AppRadius.fieldR,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded,
                            color: scheme.onErrorContainer),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _serverError!,
                            style: TextStyle(color: scheme.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                _Label('Request type'),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  items: [
                    for (final type in AttendanceRequestType.all)
                      DropdownMenuItem(
                        value: type,
                        child: Text(AttendanceRequestType.label(type)),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) {
                          if (value != null) setState(() => _type = value);
                        },
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _Label('Date'),
                _PickerField(
                  icon: Icons.event_rounded,
                  value: formatDayDate(_date),
                  onTap: _busy ? null : _pickDate,
                ),
                if (_needsCheckIn) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _Label('Requested check-in'),
                  _PickerField(
                    icon: Icons.login_rounded,
                    value: _checkInTime == null
                        ? 'Pick time'
                        : _checkInTime!.format(context),
                    placeholder: _checkInTime == null,
                    onTap: _busy ? null : () => _pickTime(checkIn: true),
                  ),
                ],
                if (_needsCheckOut) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _Label('Requested check-out'),
                  _PickerField(
                    icon: Icons.logout_rounded,
                    value: _checkOutTime == null
                        ? 'Pick time'
                        : _checkOutTime!.format(context),
                    placeholder: _checkOutTime == null,
                    onTap: _busy ? null : () => _pickTime(checkIn: false),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                _Label('Reason'),
                AppTextField(
                  label: 'Reason',
                  controller: _reasonController,
                  enabled: !_busy,
                  hint: 'Explain why this correction is needed…',
                  maxLines: 4,
                  maxLength: 500,
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'A reason is required';
                    if (v.length < 5) {
                      return 'Please provide a little more detail';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: _busy ? 'Submitting…' : 'Submit request',
                  icon: Icons.send_rounded,
                  loading: _busy,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.icon,
    required this.value,
    required this.onTap,
    this.placeholder = false,
  });

  final IconData icon;
  final String value;
  final VoidCallback? onTap;
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: AppRadius.fieldR,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.fieldR,
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: placeholder
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                    fontWeight: placeholder ? FontWeight.w400 : FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.expand_more_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
