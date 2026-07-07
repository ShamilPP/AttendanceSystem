import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/attendance_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/documents_provider.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_avatar.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';
import '../utils/formatters.dart';
import 'documents_screen.dart';
import 'login_screen.dart';

/// Employee profile: avatar header, info rows, change-password, documents,
/// logout.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Future<void> _changePassword(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    context.read<AttendanceProvider>().reset();
    context.read<DocumentsProvider>().reset();
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final scheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.of(context).padding.top;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          try {
            await context.read<AuthProvider>().refreshMe();
          } on ApiException catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(e.message)));
            }
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            // Gradient profile header
            Container(
              decoration: const BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              padding: EdgeInsets.fromLTRB(AppSpacing.xl,
                  topInset + AppSpacing.xl, AppSpacing.xl, AppSpacing.xxl),
              child: Column(
                children: [
                  AppAvatar(name: user.name, radius: 40, onGradient: true),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    user.name,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.sm,
                    children: [
                      _HeaderPill(
                        icon: Icons.badge_outlined,
                        label: user.employeeId.isEmpty ? '—' : user.employeeId,
                      ),
                      if ((user.designation?.name ?? '').isNotEmpty)
                        _HeaderPill(
                          icon: Icons.work_outline_rounded,
                          label: user.designation!.name,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  _InfoCard(rows: [
                    (Icons.alternate_email_rounded, 'Email', user.email),
                    (
                      Icons.apartment_rounded,
                      'Department',
                      (user.department?.name ?? '').isEmpty
                          ? '—'
                          : user.department!.name
                    ),
                    (
                      Icons.work_outline_rounded,
                      'Designation',
                      (user.designation?.name ?? '').isEmpty
                          ? '—'
                          : user.designation!.name
                    ),
                    (
                      Icons.phone_outlined,
                      'Phone',
                      (user.phone ?? '').isEmpty ? '—' : user.phone!
                    ),
                    (
                      Icons.home_outlined,
                      'Address',
                      (user.address ?? '').isEmpty ? '—' : user.address!
                    ),
                    (
                      Icons.event_available_outlined,
                      'Joining date',
                      (user.joiningDate ?? '').isEmpty
                          ? '—'
                          : formatDateString(user.joiningDate!)
                    ),
                  ]),
                  const SizedBox(height: AppSpacing.lg),
                  Card(
                    child: Column(
                      children: [
                        _ActionRow(
                          icon: Icons.folder_outlined,
                          iconColor: AppColors.info,
                          title: 'My documents',
                          subtitle: 'ID proofs, company ID cards and more',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) => const DocumentsScreen()),
                            );
                          },
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        _ActionRow(
                          icon: Icons.lock_reset_rounded,
                          iconColor: AppColors.teal,
                          title: 'Change password',
                          subtitle: 'Update your account password',
                          onTap: () => _changePassword(context),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        _ActionRow(
                          icon: Icons.logout_rounded,
                          iconColor: AppColors.danger,
                          title: 'Log out',
                          subtitle: 'Sign out of this device',
                          danger: true,
                          onTap: () => _logout(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'NexCrew Attendance',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: scheme.outline),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: AppRadius.pillR,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: AppColors.tint),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: danger ? AppColors.danger : null,
            ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: scheme.onSurfaceVariant),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});

  final List<(IconData, String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(rows[i].$1, size: 20, color: scheme.onSurfaceVariant),
                    const SizedBox(width: AppSpacing.md),
                    SizedBox(
                      width: 96,
                      child: Text(
                        rows[i].$2,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        rows[i].$3,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _serverError;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _serverError = null;
    });
    final auth = context.read<AuthProvider>();
    try {
      final message = await auth.changePassword(
          _currentController.text, _newController.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
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
    return AlertDialog(
      title: const Text('Change password'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_serverError != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: AppRadius.fieldR,
                  ),
                  child: Text(
                    _serverError!,
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              AppTextField(
                label: 'Current password',
                controller: _currentController,
                enabled: !_busy,
                obscureText: _obscure,
                prefixIcon: Icons.lock_outline_rounded,
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Current password is required'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'New password',
                controller: _newController,
                enabled: !_busy,
                obscureText: _obscure,
                prefixIcon: Icons.lock_reset_rounded,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'New password is required';
                  }
                  if (value.length < 6) return 'Use at least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Confirm new password',
                controller: _confirmController,
                enabled: !_busy,
                obscureText: _obscure,
                prefixIcon: Icons.lock_person_rounded,
                validator: (value) => value != _newController.text
                    ? 'Passwords do not match'
                    : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                  ),
                  label: Text(_obscure ? 'Show' : 'Hide'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        AppButton(
          label: 'Update',
          loading: _busy,
          expand: false,
          onPressed: _submit,
        ),
      ],
    );
  }
}
