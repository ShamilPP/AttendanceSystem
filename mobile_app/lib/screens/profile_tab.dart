import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/attendance_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/documents_provider.dart';
import '../services/api_client.dart';
import '../utils/formatters.dart';
import 'documents_screen.dart';
import 'login_screen.dart';

/// Employee profile, change-password and logout.
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

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                try {
                  await context.read<AuthProvider>().refreshMe();
                } on ApiException catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.message)),
                    );
                  }
                }
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: scheme.primaryContainer,
                        child: Text(
                          user.initials,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            if ((user.designation?.name ?? '').isNotEmpty)
                              Text(
                                user.designation!.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                        color: scheme.onSurfaceVariant),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _InfoCard(rows: [
                    (Icons.badge_outlined, 'Employee ID',
                        user.employeeId.isEmpty ? '—' : user.employeeId),
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
                  const SizedBox(height: 16),
                  Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.folder_outlined),
                          title: const Text('My documents'),
                          subtitle: const Text(
                              'ID proofs, company ID cards and more'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) => const DocumentsScreen()),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.lock_reset_rounded),
                          title: const Text('Change password'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _changePassword(context),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading:
                              Icon(Icons.logout_rounded, color: scheme.error),
                          title: Text('Log out',
                              style: TextStyle(color: scheme.error)),
                          onTap: () => _logout(context),
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});

  final List<(IconData, String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            for (final (icon, label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 20, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 100,
                      child: Text(
                        label,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        value,
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _serverError!,
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _currentController,
                enabled: !_busy,
                obscureText: _obscure,
                decoration: const InputDecoration(
                    labelText: 'Current password'),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Current password is required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newController,
                enabled: !_busy,
                obscureText: _obscure,
                decoration: const InputDecoration(labelText: 'New password'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'New password is required';
                  }
                  if (value.length < 6) {
                    return 'Use at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmController,
                enabled: !_busy,
                obscureText: _obscure,
                decoration: const InputDecoration(
                    labelText: 'Confirm new password'),
                validator: (value) => value != _newController.text
                    ? 'Passwords do not match'
                    : null,
              ),
              const SizedBox(height: 8),
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
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Text('Update'),
        ),
      ],
    );
  }
}
