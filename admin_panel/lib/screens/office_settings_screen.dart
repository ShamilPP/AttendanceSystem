import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/office_settings.dart';
import '../providers/office_settings_provider.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/formats.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_feedback.dart';
import '../widgets/picker_fields.dart';
import '../widgets/states.dart';

/// Geofence + working hours + timezone configuration (no QR refresh in v2).
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

    if (provider.error != null && settings == null && !provider.loading) {
      return ErrorState(message: provider.error!, onRetry: provider.load);
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        if (provider.error != null && settings != null)
          ErrorBanner(message: provider.error!, onRetry: provider.load),
        if (provider.loading && settings == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: LoadingState(),
          )
        else if (settings != null)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: _SettingsForm(
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
    _lateTolerance = TextEditingController(text: '${s.lateToleranceMinutes}');
    _earlyTolerance =
        TextEditingController(text: '${s.earlyLeaveToleranceMinutes}');
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
      timezone: _timezone.text.trim(),
    );
    try {
      await provider.save(value);
      if (mounted) showSuccessSnack(context, 'Office settings saved.');
    } on ApiException catch (e) {
      if (mounted) showErrorSnack(context, e.fullMessage);
    }
  }

  Widget _sectionTitle(String text, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Row(children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Text(text,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final saving = context.watch<OfficeSettingsProvider>().saving;

    return Column(
      children: [
        AppCard(
          elevated: true,
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionTitle(
                    'Office location & geofence', Icons.location_on_outlined),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latitude,
                      decoration: const InputDecoration(labelText: 'Latitude'),
                      validator: (v) =>
                          _doubleValidator(v, -90, 90, 'Latitude'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextFormField(
                      controller: _longitude,
                      decoration:
                          const InputDecoration(labelText: 'Longitude'),
                      validator: (v) =>
                          _doubleValidator(v, -180, 180, 'Longitude'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextFormField(
                      controller: _radius,
                      decoration: const InputDecoration(
                        labelText: 'Radius (meters)',
                        helperText: 'Allowed attendance area',
                      ),
                      validator: (v) => _intValidator(v, 10, 100000, 'Radius'),
                    ),
                  ),
                ]),
                const SizedBox(height: AppSpacing.xl),
                _sectionTitle('Working hours', Icons.schedule_outlined),
                Row(children: [
                  Expanded(
                    child: TimePickerField(
                      label: 'Work start time',
                      value: _workStart,
                      onChanged: (t) =>
                          setState(() => _workStart = t ?? _workStart),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TimePickerField(
                      label: 'Work end time',
                      value: _workEnd,
                      onChanged: (t) =>
                          setState(() => _workEnd = t ?? _workEnd),
                    ),
                  ),
                ]),
                const SizedBox(height: AppSpacing.md),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _lateTolerance,
                      decoration: const InputDecoration(
                        labelText: 'Late tolerance (minutes)',
                        helperText: 'Grace period after work start',
                      ),
                      validator: (v) =>
                          _intValidator(v, 0, 240, 'Late tolerance'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextFormField(
                      controller: _earlyTolerance,
                      decoration: const InputDecoration(
                        labelText: 'Early-leave tolerance (minutes)',
                        helperText: 'Grace period before work end',
                      ),
                      validator: (v) =>
                          _intValidator(v, 0, 240, 'Early-leave tolerance'),
                    ),
                  ),
                ]),
                const SizedBox(height: AppSpacing.xl),
                _sectionTitle('Timezone', Icons.public_outlined),
                TextFormField(
                  controller: _timezone,
                  decoration: const InputDecoration(
                    labelText: 'Timezone',
                    helperText: 'IANA name, e.g. Asia/Dubai',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Timezone is required'
                      : null,
                ),
                const SizedBox(height: AppSpacing.xxl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppButton(
                      label: 'Save settings',
                      icon: Icons.save_outlined,
                      loading: saving,
                      onPressed: _save,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _GeofencePreview(
          latitude: widget.initial.latitude,
          longitude: widget.initial.longitude,
          radiusMeters: widget.initial.radiusMeters,
        ),
      ],
    );
  }
}

/// A small map-less "geofence preview": echoes the coordinates and draws a
/// simple radius disc so admins can sanity-check the configured area.
class _GeofencePreview extends StatelessWidget {
  const _GeofencePreview({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  final double latitude;
  final double longitude;
  final int radiusMeters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.onLeave.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.onLeave.withValues(alpha: 0.35)),
                  ),
                ),
                const Icon(Icons.location_on,
                    color: AppColors.onLeave, size: 28),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Geofence preview',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'Center: ${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                Text(
                  'Any scan within $radiusMeters m of this point is accepted.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
