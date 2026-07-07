import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/office_settings.dart';
import '../providers/office_settings_provider.dart';
import '../services/api_client.dart';
import '../utils/formats.dart';
import '../widgets/app_feedback.dart';
import '../widgets/picker_fields.dart';

/// Geofence + working hours + QR refresh configuration.
class OfficeSettingsScreen extends StatefulWidget {
  const OfficeSettingsScreen({super.key});

  @override
  State<OfficeSettingsScreen> createState() => _OfficeSettingsScreenState();
}

class _OfficeSettingsScreenState extends State<OfficeSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<OfficeSettingsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OfficeSettingsProvider>();
    final settings = provider.settings;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (provider.error != null)
          ErrorBanner(
              message: provider.error!, onRetry: () => provider.load()),
        if (provider.loading && settings == null)
          const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (settings != null)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: _SettingsForm(
                // Recreate the form whenever a fresh copy is loaded.
                key: ValueKey(identityHashCode(settings)),
                initial: settings,
              ),
            ),
          ),
      ],
    );
  }
}

class _SettingsForm extends StatefulWidget {
  const _SettingsForm({super.key, required this.initial});

  final OfficeSettings initial;

  @override
  State<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<_SettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  late final TextEditingController _radius;
  late final TextEditingController _lateTolerance;
  late final TextEditingController _earlyTolerance;
  late final TextEditingController _qrRefresh;
  late final TextEditingController _timezone;
  late TimeOfDay _workStart;
  late TimeOfDay _workEnd;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _latitude = TextEditingController(text: '${s.latitude}');
    _longitude = TextEditingController(text: '${s.longitude}');
    _radius = TextEditingController(text: '${s.radiusMeters}');
    _lateTolerance =
        TextEditingController(text: '${s.lateToleranceMinutes}');
    _earlyTolerance =
        TextEditingController(text: '${s.earlyLeaveToleranceMinutes}');
    _qrRefresh = TextEditingController(text: '${s.qrRefreshSeconds}');
    _timezone = TextEditingController(text: s.timezone);
    _workStart =
        parseHHmm(s.workStartTime) ?? const TimeOfDay(hour: 9, minute: 0);
    _workEnd =
        parseHHmm(s.workEndTime) ?? const TimeOfDay(hour: 18, minute: 0);
  }

  @override
  void dispose() {
    _latitude.dispose();
    _longitude.dispose();
    _radius.dispose();
    _lateTolerance.dispose();
    _earlyTolerance.dispose();
    _qrRefresh.dispose();
    _timezone.dispose();
    super.dispose();
  }

  String? _doubleValidator(String? v, double min, double max, String label) {
    final parsed = double.tryParse(v?.trim() ?? '');
    if (parsed == null) return '$label must be a number';
    if (parsed < min || parsed > max) {
      return '$label must be between $min and $max';
    }
    return null;
  }

  String? _intValidator(String? v, int min, int max, String label) {
    final parsed = int.tryParse(v?.trim() ?? '');
    if (parsed == null) return '$label must be a whole number';
    if (parsed < min || parsed > max) {
      return '$label must be between $min and $max';
    }
    return null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final provider = context.read<OfficeSettingsProvider>();
    final value = OfficeSettings(
      latitude: double.parse(_latitude.text.trim()),
      longitude: double.parse(_longitude.text.trim()),
      radiusMeters: int.parse(_radius.text.trim()),
      workStartTime: timeOfDayToHHmm(_workStart),
      workEndTime: timeOfDayToHHmm(_workEnd),
      lateToleranceMinutes: int.parse(_lateTolerance.text.trim()),
      earlyLeaveToleranceMinutes: int.parse(_earlyTolerance.text.trim()),
      qrRefreshSeconds: int.parse(_qrRefresh.text.trim()),
      timezone: _timezone.text.trim(),
    );
    try {
      await provider.save(value);
      if (mounted) {
        showSuccessSnack(context, 'Office settings saved.');
      }
    } on ApiException catch (e) {
      if (mounted) showErrorSnack(context, e.fullMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final saving = context.watch<OfficeSettingsProvider>().saving;

    Widget sectionTitle(String text, IconData icon) => Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 14),
          child: Row(children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(text,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ]),
        );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              sectionTitle('Office location & geofence',
                  Icons.location_on_outlined),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _latitude,
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) =>
                        _doubleValidator(v, -90, 90, 'Latitude'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _longitude,
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) =>
                        _doubleValidator(v, -180, 180, 'Longitude'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _radius,
                    decoration: const InputDecoration(
                      labelText: 'Radius (meters)',
                      helperText: 'Allowed attendance area',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) =>
                        _intValidator(v, 10, 100000, 'Radius'),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              sectionTitle('Working hours', Icons.schedule_outlined),
              Row(children: [
                Expanded(
                  child: TimePickerField(
                    label: 'Work start time',
                    value: _workStart,
                    onChanged: (t) =>
                        setState(() => _workStart = t ?? _workStart),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TimePickerField(
                    label: 'Work end time',
                    value: _workEnd,
                    onChanged: (t) =>
                        setState(() => _workEnd = t ?? _workEnd),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _lateTolerance,
                    decoration: const InputDecoration(
                      labelText: 'Late tolerance (minutes)',
                      helperText: 'Grace period after work start',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) =>
                        _intValidator(v, 0, 240, 'Late tolerance'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _earlyTolerance,
                    decoration: const InputDecoration(
                      labelText: 'Early-leave tolerance (minutes)',
                      helperText: 'Grace period before work end',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) =>
                        _intValidator(v, 0, 240, 'Early-leave tolerance'),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              sectionTitle('QR & timezone', Icons.qr_code_2),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _qrRefresh,
                    decoration: const InputDecoration(
                      labelText: 'QR refresh (seconds)',
                      helperText: 'How often the kiosk QR rotates',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) =>
                        _intValidator(v, 5, 3600, 'QR refresh'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _timezone,
                    decoration: const InputDecoration(
                      labelText: 'Timezone',
                      helperText: 'IANA name, e.g. Asia/Dubai',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Timezone is required'
                        : null,
                  ),
                ),
              ]),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton.icon(
                    icon: saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Save settings'),
                    onPressed: saving ? null : _save,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
