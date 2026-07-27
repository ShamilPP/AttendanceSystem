import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../widgets/fading_scroll_view.dart';
import '../widgets/page_scaffold.dart';
import '../widgets/picker_fields.dart';
import '../widgets/setting_row.dart';
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

    return PageScaffold(
      title: 'Office settings',
      description:
          'The geofence and working hours every check-in is validated against.',
      // The form fades its own scroll area; the pinned save bar must not fade.
      fadeScroll: false,
      child: provider.loading && settings == null
          ? const LoadingState(message: 'Loading settings…')
          : settings == null
              ? const SizedBox.shrink()
              : _SettingsForm(
                  key: ValueKey(identityHashCode(settings)),
                  initial: settings,
                  banner: provider.error == null
                      ? null
                      : ErrorBanner(
                          message: provider.error!, onRetry: provider.load),
                ),
    );
  }
}

class _SettingsForm extends StatefulWidget {
  const _SettingsForm({super.key, required this.initial, this.banner});

  final OfficeSettings initial;
  final Widget? banner;

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

  List<TextEditingController> get _controllers => [
        _latitude, _longitude, _radius,
        _lateTolerance, _earlyTolerance, _timezone,
      ];

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
    // Drives both the live geofence preview and the unsaved-changes bar.
    for (final c in _controllers) {
      c.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.removeListener(_onChanged);
      c.dispose();
    }
    super.dispose();
  }

  void _onChanged() => setState(() {});

  /// True when anything differs from what is currently saved.
  bool get _dirty {
    final s = widget.initial;
    return _latitude.text.trim() != '${s.latitude}' ||
        _longitude.text.trim() != '${s.longitude}' ||
        _radius.text.trim() != '${s.radiusMeters}' ||
        _lateTolerance.text.trim() != '${s.lateToleranceMinutes}' ||
        _earlyTolerance.text.trim() != '${s.earlyLeaveToleranceMinutes}' ||
        _timezone.text.trim() != s.timezone ||
        timeOfDayToHHmm(_workStart) != s.workStartTime ||
        timeOfDayToHHmm(_workEnd) != s.workEndTime;
  }

  void _discard() {
    final s = widget.initial;
    _latitude.text = '${s.latitude}';
    _longitude.text = '${s.longitude}';
    _radius.text = '${s.radiusMeters}';
    _lateTolerance.text = '${s.lateToleranceMinutes}';
    _earlyTolerance.text = '${s.earlyLeaveToleranceMinutes}';
    _timezone.text = s.timezone;
    setState(() {
      _workStart =
          parseHHmm(s.workStartTime) ?? const TimeOfDay(hour: 9, minute: 0);
      _workEnd =
          parseHHmm(s.workEndTime) ?? const TimeOfDay(hour: 18, minute: 0);
    });
  }

  String? _doubleValidator(String? v, double min, double max, String label) {
    final parsed = double.tryParse(v?.trim() ?? '');
    if (parsed == null) return 'Must be a number';
    if (parsed < min || parsed > max) return 'Must be between $min and $max';
    return null;
  }

  String? _intValidator(String? v, int min, int max, String label) {
    final parsed = int.tryParse(v?.trim() ?? '');
    if (parsed == null) return 'Must be a whole number';
    if (parsed < min || parsed > max) return 'Must be between $min and $max';
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

  /// Current radius as typed, for the live preview (null while invalid).
  int? get _liveRadius => int.tryParse(_radius.text.trim());

  @override
  Widget build(BuildContext context) {
    final saving = context.watch<OfficeSettingsProvider>().saving;
    final workingMinutes = _workEnd.hour * 60 +
        _workEnd.minute -
        (_workStart.hour * 60 + _workStart.minute);

    return Column(
      children: [
        Expanded(
          child: FadingScrollView(
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
              children: [
                Center(
                  child: ConstrainedBox(
                    // Settings read as a list of decisions, not a data grid —
                    // a narrower measure keeps label and control together.
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ?widget.banner,
                          _LocationCard(
                            latitude: _latitude,
                            longitude: _longitude,
                            radius: _radius,
                            doubleValidator: _doubleValidator,
                            intValidator: _intValidator,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _HoursCard(
                            workStart: _workStart,
                            workEnd: _workEnd,
                            workingMinutes: workingMinutes,
                            onStart: (t) => setState(() => _workStart = t),
                            onEnd: (t) => setState(() => _workEnd = t),
                            lateTolerance: _lateTolerance,
                            earlyTolerance: _earlyTolerance,
                            intValidator: _intValidator,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _TimezoneCard(timezone: _timezone),
                          const SizedBox(height: AppSpacing.lg),
                          // Reads the *edited* values, so changing the radius
                          // updates the ring immediately. Previously this was
                          // bound to the saved settings and never moved.
                          _GeofencePreview(
                            latitude: double.tryParse(_latitude.text.trim()),
                            longitude: double.tryParse(_longitude.text.trim()),
                            radiusMeters: _liveRadius,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Pinned so saving never depends on scrolling to the bottom, and
        // absent entirely until something actually changed.
        _SaveBar(dirty: _dirty, saving: saving, onSave: _save, onDiscard: _discard),
      ],
    );
  }
}

/// Bottom bar that slides in only when there are unsaved changes.
class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.dirty,
    required this.saving,
    required this.onSave,
    required this.onDiscard,
  });

  final bool dirty;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: !dirty
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                border: Border(
                    top: BorderSide(color: theme.colorScheme.outlineVariant)),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined,
                          size: 18, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text('You have unsaved changes',
                            style: theme.textTheme.bodyMedium),
                      ),
                      AppButton(
                        label: 'Discard',
                        variant: AppButtonVariant.text,
                        onPressed: saving ? null : onDiscard,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      AppButton(
                        label: 'Save changes',
                        icon: Icons.save_outlined,
                        loading: saving,
                        onPressed: onSave,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.doubleValidator,
    required this.intValidator,
  });

  final TextEditingController latitude;
  final TextEditingController longitude;
  final TextEditingController radius;
  final String? Function(String?, double, double, String) doubleValidator;
  final String? Function(String?, int, int, String) intValidator;

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      icon: Icons.location_on_outlined,
      title: 'Office location & geofence',
      subtitle: 'A scan is only accepted inside this circle.',
      children: [
        SettingRow(
          label: 'Latitude',
          help: 'Decimal degrees, −90 to 90',
          child: NumberField(
            controller: latitude,
            width: 160,
            validator: (v) => doubleValidator(v, -90, 90, 'Latitude'),
          ),
        ),
        SettingRow(
          label: 'Longitude',
          help: 'Decimal degrees, −180 to 180',
          child: NumberField(
            controller: longitude,
            width: 160,
            validator: (v) => doubleValidator(v, -180, 180, 'Longitude'),
          ),
        ),
        SettingRow(
          label: 'Radius',
          help: 'How far from the centre a scan still counts',
          child: NumberField(
            controller: radius,
            width: 120,
            suffix: 'm',
            integer: true,
            validator: (v) => intValidator(v, 10, 100000, 'Radius'),
          ),
        ),
      ],
    );
  }
}

class _HoursCard extends StatelessWidget {
  const _HoursCard({
    required this.workStart,
    required this.workEnd,
    required this.workingMinutes,
    required this.onStart,
    required this.onEnd,
    required this.lateTolerance,
    required this.earlyTolerance,
    required this.intValidator,
  });

  final TimeOfDay workStart;
  final TimeOfDay workEnd;
  final int workingMinutes;
  final ValueChanged<TimeOfDay> onStart;
  final ValueChanged<TimeOfDay> onEnd;
  final TextEditingController lateTolerance;
  final TextEditingController earlyTolerance;
  final String? Function(String?, int, int, String) intValidator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valid = workingMinutes > 0;
    return SettingsCard(
      icon: Icons.schedule_outlined,
      title: 'Working hours',
      subtitle: 'Used to decide who is late and who left early.',
      children: [
        SettingRow(
          label: 'Work start',
          help: 'Local time in the office timezone',
          child: SizedBox(
            width: 150,
            child: TimePickerField(
              value: workStart,
              onChanged: (t) => onStart(t ?? workStart),
            ),
          ),
        ),
        SettingRow(
          label: 'Work end',
          // Not formatMinutes(): "9:00" next to a time picker reads as a
          // clock time, not a duration.
          help: valid
              ? 'A ${workingMinutes ~/ 60}h ${workingMinutes % 60}m working day'
              : 'Must be after the start time',
          helpIsError: !valid,
          child: SizedBox(
            width: 150,
            child: TimePickerField(
              value: workEnd,
              onChanged: (t) => onEnd(t ?? workEnd),
            ),
          ),
        ),
        const SettingsDivider(),
        SettingRow(
          label: 'Late tolerance',
          help: 'Grace period after work start before someone is marked late',
          child: NumberField(
            controller: lateTolerance,
            width: 120,
            suffix: 'min',
            integer: true,
            validator: (v) => intValidator(v, 0, 240, 'Late tolerance'),
          ),
        ),
        SettingRow(
          label: 'Early-leave tolerance',
          help: 'Grace period before work end before a check-out counts early',
          child: NumberField(
            controller: earlyTolerance,
            width: 120,
            suffix: 'min',
            integer: true,
            validator: (v) => intValidator(v, 0, 240, 'Early-leave tolerance'),
          ),
        ),
        if (!valid)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              'Work end must be later than work start.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ),
      ],
    );
  }
}

class _TimezoneCard extends StatelessWidget {
  const _TimezoneCard({required this.timezone});

  final TextEditingController timezone;

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      icon: Icons.public_outlined,
      title: 'Timezone',
      subtitle: 'All attendance times are calculated in this zone.',
      children: [
        SettingRow(
          label: 'Timezone',
          help: 'IANA name, e.g. Asia/Dubai',
          child: SizedBox(
            width: 220,
            child: TextFormField(
              controller: timezone,
              decoration: const InputDecoration(isDense: true),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Timezone is required'
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// Map-less geofence preview: a ring scaled to the configured radius, with the
/// coordinates echoed back. Bound to the live form values.
class _GeofencePreview extends StatelessWidget {
  const _GeofencePreview({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  final double? latitude;
  final double? longitude;
  final int? radiusMeters;

  /// Ring diameter, scaled logarithmically so both a 50 m office and a 2 km
  /// campus read sensibly inside the same 96px box.
  static double _ringSize(int meters) {
    const minM = 10.0, maxM = 2000.0;
    final v = meters.clamp(minM, maxM).toDouble();
    final t = (math.log(v) - math.log(minM)) /
        (math.log(maxM) - math.log(minM));
    return 30 + (90 - 30) * t.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCoords = latitude != null && longitude != null;
    final radius = radiusMeters;
    final ring = radius == null ? 60.0 : _ringSize(radius);

    return AppCard(
      child: Row(
        children: [
          SizedBox(
            width: 104,
            height: 104,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer reference ring = the maximum the preview shows.
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                        style: BorderStyle.solid),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  width: ring,
                  height: ring,
                  decoration: BoxDecoration(
                    color: AppColors.onLeave.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.onLeave.withValues(alpha: 0.55)),
                  ),
                ),
                const Icon(Icons.location_on, color: AppColors.onLeave, size: 22),
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
                  hasCoords
                      ? 'Centre ${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}'
                      : 'Enter valid coordinates to preview the area',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                Text(
                  radius == null
                      ? 'Enter a radius in metres'
                      : 'Any scan within $radius m of this point is accepted.',
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

/// Keyboard-friendly numeric input sized to its content instead of stretched
/// across the card. Unit lives in a suffix so labels stay short.
class NumberField extends StatelessWidget {
  const NumberField({
    super.key,
    required this.controller,
    required this.width,
    this.suffix,
    this.integer = false,
    this.validator,
  });

  final TextEditingController controller;
  final double width;
  final String? suffix;
  final bool integer;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(
            decimal: !integer, signed: !integer),
        inputFormatters: integer
            ? [FilteringTextInputFormatter.digitsOnly]
            : [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))],
        decoration: InputDecoration(isDense: true, suffixText: suffix),
        validator: validator,
      ),
    );
  }
}
