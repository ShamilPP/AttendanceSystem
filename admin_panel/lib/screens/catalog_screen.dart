import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/catalog_item.dart';
import '../providers/catalog_provider.dart';
import '../services/api_client.dart';
import '../widgets/app_feedback.dart';

/// Two CRUD lists: departments and designations.
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CatalogProvider>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CatalogProvider>();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (provider.error != null)
            ErrorBanner(
                message: provider.error!, onRetry: () => provider.refresh()),
          Expanded(
            child: provider.loading &&
                    provider.departments.isEmpty &&
                    provider.designations.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 900;
                    final departmentsPanel = _CatalogPanel(
                      title: 'Departments',
                      kind: 'departments',
                      singular: 'department',
                      icon: Icons.account_tree_outlined,
                      items: provider.departments,
                    );
                    final designationsPanel = _CatalogPanel(
                      title: 'Designations',
                      kind: 'designations',
                      singular: 'designation',
                      icon: Icons.badge_outlined,
                      items: provider.designations,
                    );
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: departmentsPanel),
                          const SizedBox(width: 16),
                          Expanded(child: designationsPanel),
                        ],
                      );
                    }
                    return ListView(
                      children: [
                        SizedBox(height: 420, child: departmentsPanel),
                        const SizedBox(height: 16),
                        SizedBox(height: 420, child: designationsPanel),
                      ],
                    );
                  }),
          ),
        ],
      ),
    );
  }
}

class _CatalogPanel extends StatelessWidget {
  const _CatalogPanel({
    required this.title,
    required this.kind,
    required this.singular,
    required this.icon,
    required this.items,
  });

  final String title;
  final String kind; // API path segment
  final String singular;
  final IconData icon;
  final List<CatalogItem> items;

  Future<void> _openEditor(BuildContext context, [CatalogItem? existing]) async {
    final provider = context.read<CatalogProvider>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CatalogItemDialog(
        provider: provider,
        kind: kind,
        singular: singular,
        existing: existing,
      ),
    );
    if (saved == true && context.mounted) {
      showSuccessSnack(context,
          existing == null ? 'New $singular added.' : 'Renamed successfully.');
    }
  }

  Future<void> _delete(BuildContext context, CatalogItem item) async {
    final provider = context.read<CatalogProvider>();
    final ok = await confirmDialog(
      context,
      title: 'Delete $singular',
      message: 'Delete "${item.name}"? This cannot be undone. '
          'Deletion is blocked while any employee still uses this $singular.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await provider.remove(kind, item.id);
      if (context.mounted) {
        showSuccessSnack(context, '"${item.name}" deleted.');
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        showErrorSnack(
          context,
          e.isConflict
              ? 'Cannot delete "${item.name}": it is still assigned to one or more employees. ${e.message}'
              : e.fullMessage,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Text('${items.length}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const Spacer(),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                  onPressed: () => _openEditor(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: items.isEmpty
                  ? EmptyState(
                      message: 'No $title yet. Add the first one.',
                      icon: icon)
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final item = items[i];
                        return ListTile(
                          dense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          title: Text(item.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: item.description == null
                              ? null
                              : Text(item.description!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Rename',
                                icon:
                                    const Icon(Icons.edit_outlined, size: 18),
                                onPressed: () => _openEditor(context, item),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                icon: Icon(Icons.delete_outline,
                                    size: 18,
                                    color: theme.colorScheme.error),
                                onPressed: () => _delete(context, item),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogItemDialog extends StatefulWidget {
  const _CatalogItemDialog({
    required this.provider,
    required this.kind,
    required this.singular,
    this.existing,
  });

  final CatalogProvider provider;
  final String kind;
  final String singular;
  final CatalogItem? existing;

  @override
  State<_CatalogItemDialog> createState() => _CatalogItemDialogState();
}

class _CatalogItemDialogState extends State<_CatalogItemDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.existing?.name ?? '');
    _descriptionController =
        TextEditingController(text: widget.existing?.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final description = _descriptionController.text.trim();
      if (widget.existing == null) {
        await widget.provider.create(widget.kind, name, description);
      } else {
        await widget.provider
            .rename(widget.kind, widget.existing!.id, name, description);
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
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit
          ? 'Rename ${widget.singular}'
          : 'Add ${widget.singular}'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _save(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
