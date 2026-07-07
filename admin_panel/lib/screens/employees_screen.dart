import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/import_result.dart';
import '../models/user.dart';
import '../providers/catalog_provider.dart';
import '../providers/employees_provider.dart';
import '../services/api_client.dart';
import '../services/file_download.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/formats.dart';
import '../widgets/app_avatar.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_feedback.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/picker_fields.dart';
import '../widgets/states.dart';
import '../widgets/status_chip.dart';
import '../widgets/table_wrapper.dart';

/// Employee management: searchable table, CRUD, Excel import/export.
class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  late final TextEditingController _searchController;
  bool _importing = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _searchController =
        TextEditingController(text: context.read<EmployeesProvider>().search);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CatalogProvider>().ensureLoaded();
      context.read<EmployeesProvider>().fetch();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters({
    String? departmentId,
    bool clearDepartment = false,
    String? designationId,
    bool clearDesignation = false,
    String? isActive,
    bool clearActive = false,
  }) {
    final provider = context.read<EmployeesProvider>();
    provider.applyFilters(
      search: _searchController.text.trim(),
      departmentId:
          clearDepartment ? null : (departmentId ?? provider.departmentId),
      designationId:
          clearDesignation ? null : (designationId ?? provider.designationId),
      isActive: clearActive ? null : (isActive ?? provider.isActive),
    );
  }

  Future<void> _openEditor([User? existing]) async {
    final provider = context.read<EmployeesProvider>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EmployeeDialog(provider: provider, existing: existing),
    );
    if (saved == true && mounted) {
      showSuccessSnack(context,
          existing == null ? 'Employee created.' : 'Employee updated.');
    }
  }

  Future<void> _delete(User user) async {
    final provider = context.read<EmployeesProvider>();
    final ok = await confirmDialog(
      context,
      title: 'Deactivate employee',
      icon: Icons.person_off_outlined,
      message:
          'Deactivate ${user.name} (${user.employeeId})? This is a soft delete: '
          'the account is marked inactive and can no longer sign in, but its '
          'attendance history is kept.',
      confirmLabel: 'Deactivate',
      destructive: true,
    );
    if (!ok) return;
    try {
      await provider.softDelete(user.id);
      if (mounted) showSuccessSnack(context, '${user.name} deactivated.');
    } on ApiException catch (e) {
      if (mounted) showErrorSnack(context, e.fullMessage);
    }
  }

  Future<void> _import() async {
    final provider = context.read<EmployeesProvider>();
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    final file = picked?.files.firstOrNull;
    if (file == null || file.bytes == null) return;
    setState(() => _importing = true);
    try {
      final result = await provider.importXlsx(file.bytes!, file.name);
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) => _ImportResultDialog(result: result),
        );
      }
    } on ApiException catch (e) {
      if (mounted) showErrorSnack(context, e.fullMessage);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _export() async {
    final provider = context.read<EmployeesProvider>();
    setState(() => _exporting = true);
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
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmployeesProvider>();
    final catalog = context.watch<CatalogProvider>();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search',
                      hintText: 'Name, email or employee ID',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _applyFilters();
                        },
                      ),
                    ),
                    onSubmitted: (_) => _applyFilters(),
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<String?>(
                    key: ValueKey('emp-dept-${provider.departmentId}'),
                    initialValue: provider.departmentId,
                    decoration: const InputDecoration(labelText: 'Department'),
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('All')),
                      for (final d in catalog.departments)
                        DropdownMenuItem<String?>(
                            value: d.id, child: Text(d.name)),
                    ],
                    onChanged: (v) =>
                        _applyFilters(departmentId: v, clearDepartment: v == null),
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<String?>(
                    key: ValueKey('emp-desig-${provider.designationId}'),
                    initialValue: provider.designationId,
                    decoration: const InputDecoration(labelText: 'Designation'),
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('All')),
                      for (final d in catalog.designations)
                        DropdownMenuItem<String?>(
                            value: d.id, child: Text(d.name)),
                    ],
                    onChanged: (v) => _applyFilters(
                        designationId: v, clearDesignation: v == null),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<String?>(
                    key: ValueKey('emp-active-${provider.isActive}'),
                    initialValue: provider.isActive,
                    decoration: const InputDecoration(labelText: 'Active'),
                    items: const [
                      DropdownMenuItem<String?>(value: null, child: Text('All')),
                      DropdownMenuItem<String?>(
                          value: 'true', child: Text('Active')),
                      DropdownMenuItem<String?>(
                          value: 'false', child: Text('Inactive')),
                    ],
                    onChanged: (v) =>
                        _applyFilters(isActive: v, clearActive: v == null),
                  ),
                ),
                AppButton(
                  label: 'Add Employee',
                  icon: Icons.person_add_alt,
                  onPressed: () => _openEditor(),
                ),
                AppButton.outline(
                  label: 'Import',
                  icon: Icons.upload_file,
                  loading: _importing,
                  onPressed: _import,
                ),
                AppButton.outline(
                  label: 'Export',
                  icon: Icons.download,
                  loading: _exporting,
                  onPressed: _export,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (provider.error != null)
            ErrorBanner(
                message: provider.error!, onRetry: () => provider.fetch()),
          Expanded(
            child: provider.loading
                ? const LoadingState(message: 'Loading employees…')
                : provider.records.isEmpty
                    ? EmptyState(
                        title: 'No employees',
                        message: 'No employees match the current filters.',
                        icon: Icons.person_off_outlined,
                        actionLabel: 'Add Employee',
                        onAction: () => _openEditor(),
                      )
                    : AppCard(
                        padding: EdgeInsets.zero,
                        child: ClipRRect(
                          borderRadius: AppRadius.cardR,
                          child: TableWrapper(
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Employee')),
                                DataColumn(label: Text('Email')),
                                DataColumn(label: Text('Department')),
                                DataColumn(label: Text('Designation')),
                                DataColumn(label: Text('Phone')),
                                DataColumn(label: Text('Joined')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: [
                                for (final u in provider.records)
                                  DataRow(cells: [
                                    DataCell(EmployeeCell(
                                      name: u.name,
                                      subtitle: u.employeeId,
                                      badge: u.isAdmin
                                          ? const _AdminBadge()
                                          : null,
                                    )),
                                    DataCell(Text(u.email)),
                                    DataCell(Text(u.departmentName)),
                                    DataCell(Text(u.designationName)),
                                    DataCell(Text(u.phone ?? '—')),
                                    DataCell(Text(u.joiningDate ?? '—')),
                                    DataCell(u.isActive
                                        ? const StatusChip(
                                            label: 'Active',
                                            color: AppColors.active)
                                        : const StatusChip(
                                            label: 'Inactive',
                                            color: AppColors.inactive)),
                                    DataCell(Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Edit',
                                          icon: const Icon(Icons.edit_outlined,
                                              size: 18),
                                          onPressed: () => _openEditor(u),
                                        ),
                                        IconButton(
                                          tooltip: 'Deactivate (soft delete)',
                                          icon: Icon(Icons.delete_outline,
                                              size: 18,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error),
                                          onPressed: u.isActive
                                              ? () => _delete(u)
                                              : null,
                                        ),
                                      ],
                                    )),
                                  ]),
                              ],
                            ),
                          ),
                        ),
                      ),
          ),
          PaginationBar(
            pagination: provider.pagination,
            onPageChanged: (page) => provider.fetch(toPage: page),
          ),
        ],
      ),
    );
  }
}

class _AdminBadge extends StatelessWidget {
  const _AdminBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('admin',
          style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700)),
    );
  }
}

/// Create/edit dialog covering every contract field; password optional on edit.
class _EmployeeDialog extends StatefulWidget {
  const _EmployeeDialog({required this.provider, this.existing});

  final EmployeesProvider provider;
  final User? existing;

  @override
  State<_EmployeeDialog> createState() => _EmployeeDialogState();
}

class _EmployeeDialogState extends State<_EmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _employeeIdController;
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  String? _departmentId;
  String? _designationId;
  String _role = 'employee';
  DateTime? _joiningDate;
  bool _saving = false;
  String? _error;

  bool get isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _employeeIdController = TextEditingController(text: e?.employeeId ?? '');
    _nameController = TextEditingController(text: e?.name ?? '');
    _emailController = TextEditingController(text: e?.email ?? '');
    _passwordController = TextEditingController();
    _phoneController = TextEditingController(text: e?.phone ?? '');
    _addressController = TextEditingController(text: e?.address ?? '');
    _departmentId =
        (e?.department?.id.isNotEmpty ?? false) ? e!.department!.id : null;
    _designationId =
        (e?.designation?.id.isNotEmpty ?? false) ? e!.designation!.id : null;
    _role = e?.role ?? 'employee';
    _joiningDate =
        e?.joiningDate == null ? null : DateTime.tryParse(e!.joiningDate!);
  }

  @override
  void dispose() {
    _employeeIdController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_departmentId == null || _designationId == null) {
      setState(() => _error = 'Department and designation are required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = <String, dynamic>{
      if (_employeeIdController.text.trim().isNotEmpty)
        'employeeId': _employeeIdController.text.trim(),
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      if (_passwordController.text.isNotEmpty)
        'password': _passwordController.text,
      'departmentId': _departmentId,
      'designationId': _designationId,
      if (_phoneController.text.trim().isNotEmpty)
        'phone': _phoneController.text.trim(),
      if (_addressController.text.trim().isNotEmpty)
        'address': _addressController.text.trim(),
      if (_joiningDate != null) 'joiningDate': isoDay(_joiningDate!),
      'role': _role,
    };
    try {
      if (isEdit) {
        await widget.provider.update(widget.existing!.id, body);
      } else {
        await widget.provider.create(body);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() {
        _saving = false;
        _error = e.fullMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    return AlertDialog(
      title: Text(isEdit ? 'Edit employee' : 'Add employee'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _employeeIdController,
                      decoration: InputDecoration(
                        labelText: 'Employee ID',
                        helperText:
                            isEdit ? null : 'Leave blank to auto-generate',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Name *'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Name is required'
                          : null,
                    ),
                  ),
                ]),
                const SizedBox(height: AppSpacing.md),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email *'),
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return 'Email is required';
                        if (!value.contains('@')) return 'Invalid email';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: isEdit ? 'Password' : 'Password *',
                        helperText:
                            isEdit ? 'Leave blank to keep current' : null,
                      ),
                      validator: (v) {
                        if (!isEdit && (v == null || v.isEmpty)) {
                          return 'Password is required';
                        }
                        if (v != null && v.isNotEmpty && v.length < 6) {
                          return 'At least 6 characters';
                        }
                        return null;
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: AppSpacing.md),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _departmentId,
                      decoration:
                          const InputDecoration(labelText: 'Department *'),
                      items: [
                        for (final d in catalog.departments)
                          DropdownMenuItem(value: d.id, child: Text(d.name)),
                      ],
                      onChanged: (v) => setState(() => _departmentId = v),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _designationId,
                      decoration:
                          const InputDecoration(labelText: 'Designation *'),
                      items: [
                        for (final d in catalog.designations)
                          DropdownMenuItem(value: d.id, child: Text(d.name)),
                      ],
                      onChanged: (v) => setState(() => _designationId = v),
                    ),
                  ),
                ]),
                const SizedBox(height: AppSpacing.md),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(labelText: 'Phone'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: DatePickerField(
                      label: 'Joining date',
                      value: _joiningDate,
                      allowClear: true,
                      onChanged: (d) => setState(() => _joiningDate = d),
                    ),
                  ),
                ]),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(
                        value: 'employee', child: Text('Employee')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (v) => setState(() => _role = v ?? _role),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        AppButton(
          label: isEdit ? 'Save changes' : 'Create',
          loading: _saving,
          onPressed: _save,
        ),
      ],
    );
  }
}

/// Shows imported/skipped counts and per-row errors after an Excel import.
class _ImportResultDialog extends StatelessWidget {
  const _ImportResultDialog({required this.result});

  final ImportResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Import finished'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CountChip(
                  label: 'Imported',
                  count: result.imported,
                  color: AppColors.present,
                  icon: Icons.check_circle_outline),
              const SizedBox(width: AppSpacing.md),
              CountChip(
                  label: 'Skipped',
                  count: result.skipped,
                  color: AppColors.late,
                  icon: Icons.remove_circle_outline),
            ]),
            if (result.errors.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text('Row errors',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: result.errors.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final e = result.errors[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 64,
                            child: Text('Row ${e.row}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.error)),
                          ),
                          Expanded(
                            child: Text(e.message,
                                style: theme.textTheme.bodySmall),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        AppButton(
          label: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
