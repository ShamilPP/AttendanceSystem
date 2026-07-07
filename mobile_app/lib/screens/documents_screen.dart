import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../models/document.dart';
import '../providers/documents_provider.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/formatters.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';
import '../widgets/async_states.dart';

const int _maxUploadBytes = 10 * 1024 * 1024; // 10 MB
const List<String> _allowedExtensions = ['pdf', 'jpg', 'jpeg', 'png'];

/// The employee's uploaded documents: list, upload, download, delete.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<DocumentsProvider>();
      if (!provider.loaded) provider.load();
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  bool _hasAllowedExtension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1) return false;
    return _allowedExtensions
        .contains(fileName.substring(dot + 1).toLowerCase());
  }

  Future<void> _startUpload() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.sm),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Upload a document',
                    style: Theme.of(sheetContext)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Choose a file'),
              subtitle: const Text('PDF, JPG or PNG · up to 10 MB'),
              onTap: () => Navigator.of(sheetContext).pop('file'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pick from gallery'),
              subtitle: const Text('Photo of a document or ID card'),
              onTap: () => Navigator.of(sheetContext).pop('image'),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final String? filePath;
    final String fileName;
    if (source == 'file') {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.single;
      filePath = picked.path;
      fileName = picked.name;
    } else {
      final image = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (image == null) return;
      filePath = image.path;
      fileName = image.name;
    }
    if (filePath == null || !mounted) return;

    if (!_hasAllowedExtension(fileName)) {
      _showSnack('Only PDF, JPG and PNG files are allowed.');
      return;
    }
    final size = await File(filePath).length();
    if (size > _maxUploadBytes) {
      _showSnack('File is ${formatBytes(size)} — the limit is 10 MB.');
      return;
    }
    if (!mounted) return;

    final details = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _UploadDetailsDialog(fileName: fileName),
    );
    if (details == null || !mounted) return;

    final provider = context.read<DocumentsProvider>();
    try {
      await provider.upload(
        filePath: filePath,
        fileName: fileName,
        name: details.$1,
        type: details.$2,
      );
      _showSnack('Document uploaded.');
    } on ApiException catch (e) {
      _showSnack(e.message);
    }
  }

  Future<void> _download(EmployeeDocument doc) async {
    final provider = context.read<DocumentsProvider>();
    _showSnack('Downloading ${doc.fileName}…');
    try {
      final bytes = await provider.download(doc);
      final dir = await getApplicationDocumentsDirectory();
      final safeName =
          doc.fileName.isEmpty ? 'document_${doc.id}' : doc.fileName;
      final file = File('${dir.path}${Platform.pathSeparator}$safeName');
      await file.writeAsBytes(bytes, flush: true);
      _showSnack('Saved to ${file.path}');
    } on ApiException catch (e) {
      _showSnack(e.message);
    } on FileSystemException catch (e) {
      _showSnack('Could not save file: ${e.message}');
    }
  }

  Future<void> _delete(EmployeeDocument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text('"${doc.name}" will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final provider = context.read<DocumentsProvider>();
    try {
      await provider.delete(doc);
      _showSnack('Document deleted.');
    } on ApiException catch (e) {
      _showSnack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DocumentsProvider>();

    Widget body;
    if (provider.loading && !provider.loaded) {
      body = const LoadingState(message: 'Loading documents…');
    } else if (provider.error != null && provider.documents.isEmpty) {
      body = ErrorState(message: provider.error!, onRetry: provider.load);
    } else if (provider.documents.isEmpty) {
      body = RefreshIndicator(
        onRefresh: provider.load,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: EmptyState(
                icon: Icons.folder_open_rounded,
                title: 'No documents yet',
                message: 'Upload your ID proof or company ID card using the '
                    'button below.',
                action: AppButton(
                  label: 'Upload document',
                  icon: Icons.upload_file_rounded,
                  expand: false,
                  onPressed: provider.uploading ? null : _startUpload,
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: provider.load,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 96),
          itemCount: provider.documents.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            final doc = provider.documents[index];
            return _DocumentCard(
              doc: doc,
              onDownload: () => _download(doc),
              onDelete: () => _delete(doc),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Documents')),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: provider.uploading ? null : _startUpload,
        icon: provider.uploading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : const Icon(Icons.upload_file_rounded),
        label: Text(provider.uploading ? 'Uploading…' : 'Upload'),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.doc,
    required this.onDownload,
    required this.onDelete,
  });

  final EmployeeDocument doc;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = doc.isPdf ? AppColors.danger : AppColors.info;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: AppColors.tint),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                doc.isPdf
                    ? Icons.picture_as_pdf_outlined
                    : Icons.image_outlined,
                color: accent,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.name.isEmpty ? doc.fileName : doc.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${DocumentType.label(doc.type)} · '
                    '${formatBytes(doc.size)}'
                    '${doc.uploadedAt != null ? ' · ${formatDayDate(doc.uploadedAt!)}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Download',
              onPressed: onDownload,
              icon: const Icon(Icons.download_rounded),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.danger),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadDetailsDialog extends StatefulWidget {
  const _UploadDetailsDialog({required this.fileName});

  final String fileName;

  @override
  State<_UploadDetailsDialog> createState() => _UploadDetailsDialogState();
}

class _UploadDetailsDialogState extends State<_UploadDetailsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  String _type = DocumentType.idProof;

  @override
  void initState() {
    super.initState();
    final dot = widget.fileName.lastIndexOf('.');
    _nameController = TextEditingController(
      text: dot > 0 ? widget.fileName.substring(0, dot) : widget.fileName,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Upload document'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              label: 'Document name',
              controller: _nameController,
              hint: 'e.g. Passport',
              prefixIcon: Icons.title_rounded,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'A name is required'
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Type',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: [
                for (final type in DocumentType.all)
                  DropdownMenuItem(
                    value: type,
                    child: Text(DocumentType.label(type)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Icon(Icons.attach_file_rounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.of(context).pop((_nameController.text.trim(), _type));
          },
          child: const Text('Upload'),
        ),
      ],
    );
  }
}
