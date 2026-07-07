import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/attendance_request.dart';
import '../providers/attendance_provider.dart';
import '../services/api_client.dart';
import '../utils/formatters.dart';

/// Form for a new attendance-regularization request.
class NewRequestScreen extends StatefulWidget {
  const NewRequestScreen({super.key});

  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  DateTime _date = DateTime.now();
  String _type = AttendanceRequestType.missedCheckIn;
  TimeOfDay? _checkInTime;
  TimeOfDay? _checkOutTime;
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
      helpText: checkIn ? 'Requested check-in time' : 'Requested check-out time',
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
        requestedCheckIn:
            _needsCheckIn && _checkInTime != null ? _combine(_checkInTime!) : null,
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
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_serverError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _serverError!,
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Request type',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
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
                const SizedBox(height: 16),
                Text(
                  'Date',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickDate,
                  icon: const Icon(Icons.event_rounded),
                  label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(formatDayDate(_date)),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 16),
                  ),
                ),
                if (_needsCheckIn) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Requested check-in',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _pickTime(checkIn: true),
                    icon: const Icon(Icons.login_rounded),
                    label: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(_checkInTime == null
                          ? 'Pick time'
                          : _checkInTime!.format(context)),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 16),
                    ),
                  ),
                ],
                if (_needsCheckOut) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Requested check-out',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _pickTime(checkIn: false),
                    icon: const Icon(Icons.logout_rounded),
                    label: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(_checkOutTime == null
                          ? 'Pick time'
                          : _checkOutTime!.format(context)),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 16),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Reason',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _reasonController,
                  enabled: !_busy,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    hintText: 'Explain why this correction is needed…',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'A reason is required';
                    if (v.length < 5) {
                      return 'Please provide a little more detail';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_busy ? 'Submitting…' : 'Submit request'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
