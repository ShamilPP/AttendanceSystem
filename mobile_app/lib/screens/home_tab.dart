import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/attendance.dart';
import '../providers/attendance_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/formatters.dart';
import '../widgets/app_avatar.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/status_chip.dart';
import 'scan_screen.dart';
import 'summary_screen.dart';

/// The hero screen: gradient greeting header, a live attendance status card,
/// the single context-aware action button, and a check-in/out timeline.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AttendanceProvider>().loadToday();
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && context.read<AttendanceProvider>().today?.isWorking == true) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _startAction(AttendanceAction action) async {
    final outcome = await Navigator.of(context).push<ScanOutcome>(
      MaterialPageRoute(builder: (_) => ScanScreen(action: action)),
    );
    if (outcome == null || !mounted) return;
    await _showSuccessSheet(action, outcome);
  }

  Future<void> _showSuccessSheet(
      AttendanceAction action, ScanOutcome outcome) async {
    final attendance = outcome.attendance;
    final DateTime when = (action == AttendanceAction.checkIn
            ? attendance?.checkIn
            : attendance?.checkOut) ??
        DateTime.now();
    final accent = action == AttendanceAction.checkIn
        ? AppColors.success
        : AppColors.danger;

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl, 0, AppSpacing.xxl, AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: AppColors.tint),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_rounded, size: 46, color: accent),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '${action.label} successful',
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  formatDateTime(when),
                  style: Theme.of(sheetContext)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.md),
                if (attendance != null)
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    alignment: WrapAlignment.center,
                    children: [
                      StatusChip.attendance(attendance.status),
                      if (attendance.isLate &&
                          action == AttendanceAction.checkIn)
                        const StatusChip(
                            label: 'Marked late',
                            color: AppColors.warning,
                            icon: Icons.warning_amber_rounded),
                      if (attendance.isEarlyOut &&
                          action == AttendanceAction.checkOut)
                        const StatusChip(
                            label: 'Early check-out',
                            color: AppColors.warning,
                            icon: Icons.warning_amber_rounded),
                      if (action == AttendanceAction.checkOut)
                        StatusChip(
                            label: 'Worked ${formatMinutes(attendance.workMinutes)}',
                            color: AppColors.info,
                            icon: Icons.timer_outlined),
                    ],
                  ),
                if (outcome.message.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    outcome.message,
                    textAlign: TextAlign.center,
                    style: Theme.of(sheetContext).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Done',
                  onPressed: () => Navigator.of(sheetContext).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final attendance = context.watch<AttendanceProvider>();
    final now = DateTime.now();
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => context.read<AttendanceProvider>().loadToday(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            _GreetingHeader(
              name: auth.user?.firstName ?? 'there',
              fullName: auth.user?.name ?? '',
              now: now,
              topInset: topInset,
              onSummary: _openSummary,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusCard(provider: attendance, now: now),
                  const SizedBox(height: AppSpacing.lg),
                  _ActionSection(
                    provider: attendance,
                    onAction: _startAction,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppCard(
                    onTap: _openSummary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color:
                                AppColors.seed.withValues(alpha: AppColors.tint),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.insights_rounded,
                              color: AppColors.seed),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Monthly summary',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                'Working days, hours & attendance stats',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSummary() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SummaryScreen()),
    );
  }
}

/// Gradient header with greeting, date and avatar.
class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({
    required this.name,
    required this.fullName,
    required this.now,
    required this.topInset,
    required this.onSummary,
  });

  final String name;
  final String fullName;
  final DateTime now;
  final double topInset;
  final VoidCallback onSummary;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          AppSpacing.xl, topInset + AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${greetingFor(now)},',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                ),
                Text(
                  name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 14, color: Colors.white.withValues(alpha: 0.85)),
                    const SizedBox(width: 6),
                    Text(
                      formatFullDate(now),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Monthly summary',
            onPressed: onSummary,
            icon: const Icon(Icons.insights_rounded, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.xs),
          AppAvatar(name: fullName, radius: 26, onGradient: true),
        ],
      ),
    );
  }
}

/// Large attendance status card with a live-ticking worked duration.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.provider, required this.now});

  final AttendanceProvider provider;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (provider.todayLoading && !provider.todayLoaded) {
      return const AppCard(
        padding: EdgeInsets.all(AppSpacing.xxxl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (provider.todayError != null && !provider.todayLoaded) {
      return AppCard(
        child: Column(
          children: [
            Icon(Icons.cloud_off_rounded, color: scheme.error, size: 32),
            const SizedBox(height: AppSpacing.sm),
            Text(
              provider.todayError!,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              variant: AppButtonVariant.tonal,
              expand: false,
              onPressed: provider.loadToday,
            ),
          ],
        ),
      );
    }

    final a = provider.today;
    final (accent, title, subtitle, icon) = _state(a);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Accent band
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.16),
                  accent.withValues(alpha: 0.04),
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accent, size: 28),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Column(
                      key: ValueKey(title),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Today's status",
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                  fontWeight: FontWeight.w700, color: accent),
                        ),
                        Text(
                          subtitle,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
                if (a != null) StatusChip.attendance(a.status),
              ],
            ),
          ),
          // Timeline row
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Row(
                  children: [
                    _TimelinePoint(
                      label: 'Checked in',
                      value: formatTime(a?.checkIn),
                      icon: Icons.login_rounded,
                      color: AppColors.success,
                      active: a?.checkIn != null,
                    ),
                    _TimelineConnector(active: a?.checkOut != null),
                    _TimelinePoint(
                      label: 'Checked out',
                      value: formatTime(a?.checkOut),
                      icon: Icons.logout_rounded,
                      color: AppColors.danger,
                      active: a?.checkOut != null,
                      trailing: true,
                    ),
                  ],
                ),
                if (a != null && (a.isLate || a.isEarlyOut)) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      if (a.isLate)
                        const StatusChip(
                            label: 'Late arrival',
                            color: AppColors.warning,
                            icon: Icons.schedule_rounded,
                            dense: true),
                      if (a.isLate && a.isEarlyOut)
                        const SizedBox(width: AppSpacing.sm),
                      if (a.isEarlyOut)
                        const StatusChip(
                            label: 'Early check-out',
                            color: AppColors.warning,
                            icon: Icons.directions_run_rounded,
                            dense: true),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Returns (accent, title, subtitle, icon) for the current state.
  (Color, String, String, IconData) _state(Attendance? a) {
    if (a == null || a.checkIn == null) {
      if (a?.status == AttendanceStatus.onLeave) {
        return (AppColors.info, 'On leave', 'Enjoy your day off',
            Icons.beach_access_rounded);
      }
      return (
        AppColors.slate,
        'Not checked in',
        'Scan the office QR to start your day',
        Icons.nightlight_round,
      );
    }
    if (a.checkOut != null) {
      return (
        AppColors.slate,
        'Completed',
        'Worked ${formatMinutes(a.workMinutes)} today',
        Icons.task_alt_rounded,
      );
    }
    // Working — live ticking
    final worked = a.liveWorkDuration(now.toUtc());
    return (
      AppColors.success,
      'Working',
      'Since ${formatTime(a.checkIn)} · ${formatLiveDuration(worked)}',
      Icons.work_history_rounded,
    );
  }
}

class _TimelinePoint extends StatelessWidget {
  const _TimelinePoint({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.active,
    this.trailing = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool active;
  final bool trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dim = !active;
    return Expanded(
      child: Column(
        crossAxisAlignment:
            trailing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                trailing ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!trailing) ...[
                Icon(icon,
                    size: 16,
                    color: dim ? scheme.outline : color),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (trailing) ...[
                const SizedBox(width: 6),
                Icon(icon, size: 16, color: dim ? scheme.outline : color),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: dim ? scheme.onSurfaceVariant : null,
                ),
          ),
        ],
      ),
    );
  }
}

class _TimelineConnector extends StatelessWidget {
  const _TimelineConnector({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 32,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      color: active ? AppColors.success : scheme.outlineVariant,
    );
  }
}

/// The single context-aware action button + hint.
class _ActionSection extends StatelessWidget {
  const _ActionSection({required this.provider, required this.onAction});

  final AttendanceProvider provider;
  final Future<void> Function(AttendanceAction) onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final action = provider.nextAction;

    Widget button;
    String hint;
    if (!provider.todayLoaded && provider.todayError != null) {
      button = const _DoneButton(label: 'Status unavailable');
      hint = 'Pull down to refresh';
    } else if (!provider.todayLoaded) {
      button = const AppButton(
        label: 'Loading…',
        height: 64,
        onPressed: null,
        loading: true,
      );
      hint = 'Checking your status…';
    } else if (action == AttendanceAction.checkIn) {
      button = AppButton(
        label: 'Check In',
        icon: Icons.login_rounded,
        height: 64,
        background: AppColors.success,
        foreground: Colors.white,
        onPressed: () => onAction(action!),
      );
      hint = 'Tap to scan the office QR and check in';
    } else if (action == AttendanceAction.checkOut) {
      button = AppButton(
        label: 'Check Out',
        icon: Icons.logout_rounded,
        height: 64,
        background: AppColors.danger,
        foreground: Colors.white,
        onPressed: () => onAction(action!),
      );
      hint = 'Tap to scan the office QR and check out';
    } else {
      // Done for today (checked out) or on-leave — disabled done state.
      button = _DoneButton(
        label: provider.isDoneForToday
            ? 'Completed for today'
            : 'No action available',
      );
      hint = provider.isDoneForToday
          ? "You're all done — see you tomorrow!"
          : 'Nothing to do right now';
    }

    final stateKey = !provider.todayLoaded
        ? (provider.todayError != null ? 'error' : 'loading')
        : (action?.name ?? (provider.isDoneForToday ? 'done' : 'none'));

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Column(
        key: ValueKey(stateKey),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          button,
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_scanner_rounded,
                  size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A disabled "done" pill with a checkmark for the checked-out state.
class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.slate.withValues(alpha: 0.12),
        borderRadius: AppRadius.buttonR,
        border: Border.all(color: AppColors.slate.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.slate),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.slate,
              fontWeight: FontWeight.w700,
              fontSize: 15.5,
            ),
          ),
        ],
      ),
    );
  }
}
