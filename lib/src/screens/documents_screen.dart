import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/document_service.dart';
import '../utils/context_extensions.dart';
import '../widgets/app_card.dart';
import '../widgets/app_form_dialog.dart';
import '../widgets/document_scanner_dialog.dart';
import '../widgets/layout/responsive_layout.dart';
import '../widgets/loading_state.dart';
import '../widgets/status_badge.dart';

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

enum _DocumentSortMode { newest, oldest, title, type }

enum _DocumentViewMode { list, grid }

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  DocumentType? _typeFilter;
  _DocumentSortMode _sortMode = _DocumentSortMode.newest;
  _DocumentViewMode _viewMode = _DocumentViewMode.list;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasFilters => _searchQuery.isNotEmpty || _typeFilter != null;

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _typeFilter = null;
    });
  }

  List<MedicalDocument> _filterAndSort(
    List<MedicalDocument> documents,
    Map<String, Patient> patientMap,
  ) {
    final query = _searchQuery.toLowerCase();
    final filtered = documents.where((doc) {
      final patient = patientMap[doc.patientId];
      final patientName = patient?.fullName.toLowerCase() ?? '';
      final matchesSearch =
          query.isEmpty ||
          doc.title.toLowerCase().contains(query) ||
          (doc.description?.toLowerCase().contains(query) ?? false) ||
          doc.typeDisplay.toLowerCase().contains(query) ||
          patientName.contains(query) ||
          (patient?.philHealthNumber?.toLowerCase().contains(query) ?? false);
      final matchesType = _typeFilter == null || doc.type == _typeFilter;
      final matchesStatus = doc.status != DocumentStatus.archived;
      return matchesSearch && matchesType && matchesStatus;
    }).toList();

    filtered.sort((a, b) {
      switch (_sortMode) {
        case _DocumentSortMode.oldest:
          return _docDate(a).compareTo(_docDate(b));
        case _DocumentSortMode.title:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case _DocumentSortMode.type:
          final typeCmp = a.typeDisplay.toLowerCase().compareTo(
            b.typeDisplay.toLowerCase(),
          );
          if (typeCmp != 0) return typeCmp;
          return _docDate(b).compareTo(_docDate(a));
        case _DocumentSortMode.newest:
          return _docDate(b).compareTo(_docDate(a));
      }
    });

    return filtered;
  }

  DateTime _docDate(MedicalDocument doc) =>
      doc.scanDate ?? doc.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Widget build(BuildContext context) {
    final documentsAsync = ref.watch(documentsProvider);
    final patientsAsync = ref.watch(patientsProvider);
    final currentUser = ref.watch(currentUserProvider);
    final canManage = currentUser?.canManageDocuments ?? false;

    return Column(
      children: [
        Expanded(
          child: documentsAsync.when(
            skipLoadingOnReload: true,
            data: (documents) {
              final patientMap = <String, Patient>{
                for (final patient in patientsAsync.valueOrNull ?? [])
                  patient.id: patient,
              };
              final filtered = _filterAndSort(documents, patientMap);
              final today = DateTime.now();
              final todayCount = documents.where((doc) {
                final date = doc.scanDate ?? doc.createdAt;
                if (date == null) return false;
                return date.year == today.year &&
                    date.month == today.month &&
                    date.day == today.day;
              }).length;

              return SingleChildScrollView(
                padding: ResponsiveLayout.pagePadding(context),
                child: ResponsiveContentContainer(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DocumentsPageHeader(
                        totalCount: documents.length,
                        filteredCount: filtered.length,
                        todayCount: todayCount,
                        canUpload: canManage,
                        onUpload: () => _showUploadDialog(context),
                      ),
                      const SizedBox(height: 16),
                      _DocumentsToolbar(
                        searchController: _searchController,
                        typeFilter: _typeFilter,
                        sortMode: _sortMode,
                        viewMode: _viewMode,
                        hasFilters: _hasFilters,
                        onSearchChanged: (value) =>
                            setState(() => _searchQuery = value),
                        onTypeChanged: (value) =>
                            setState(() => _typeFilter = value),
                        onSortModeChanged: (value) =>
                            setState(() => _sortMode = value),
                        onViewModeChanged: (value) =>
                            setState(() => _viewMode = value),
                        onClearFilters: _clearFilters,
                      ),
                      const SizedBox(height: 16),
                      if (filtered.isEmpty)
                        _EmptyDocumentsState(
                          hasFilters: _hasFilters,
                          canUpload: canManage,
                          onUpload: () => _showUploadDialog(context),
                        )
                      else if (_viewMode == _DocumentViewMode.grid)
                        _DocumentsGrid(
                          documents: filtered,
                          patientMap: patientMap,
                          canManage: canManage,
                          onChanged: _invalidateDocuments,
                        )
                      else
                        _DocumentsList(
                          documents: filtered,
                          patientMap: patientMap,
                          canManage: canManage,
                          onChanged: _invalidateDocuments,
                        ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const LoadingState(),
            error: (error, _) => AppErrorState(
              title: 'Documents could not be loaded',
              error: error,
              onRetry: () => ref.invalidate(documentsProvider),
            ),
          ),
        ),
      ],
    );
  }

  void _invalidateDocuments(String patientId) {
    ref.invalidate(documentsProvider);
    ref.invalidate(patientDocumentsProvider(patientId));
  }

  Future<void> _showUploadDialog(BuildContext context) async {
    await showDocumentUploadDialog(context);
  }
}

class _DocumentsPageHeader extends StatelessWidget {
  final int totalCount;
  final int filteredCount;
  final int todayCount;
  final bool canUpload;
  final VoidCallback onUpload;

  const _DocumentsPageHeader({
    required this.totalCount,
    required this.filteredCount,
    required this.todayCount,
    required this.canUpload,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 600;
            final titleWidget = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Patient Documents',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scanned records, lab results, referrals, and certificates linked to patients.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                  ),
                ),
              ],
            );

            final uploadButton = FilledButton.icon(
              onPressed: canUpload ? onUpload : null,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Upload Document'),
            );

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleWidget,
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: uploadButton),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: titleWidget),
                const SizedBox(width: 16),
                uploadButton,
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _StatChip(
              icon: Icons.folder_outlined,
              label: 'Total Documents',
              value: '$totalCount',
              color: Theme.of(context).colorScheme.primary,
            ),
            _StatChip(
              icon: Icons.today_outlined,
              label: 'Uploaded Today',
              value: '$todayCount',
              color: context.semanticColors.info,
            ),
            if (filteredCount != totalCount)
              _StatChip(
                icon: Icons.filter_alt_outlined,
                label: 'Showing',
                value: '$filteredCount',
                color: context.semanticColors.analytical,
              ),
          ],
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardSurface : theme.colorScheme.surface,
        borderRadius: AppRadius.roundedSm,
        border: Border.all(
          color: isDark
              ? AppColors.border
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark
                  ? AppColors.textSecondary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.65),
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: isDark ? AppColors.textPrimary : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentsToolbar extends StatelessWidget {
  final TextEditingController searchController;
  final DocumentType? typeFilter;
  final _DocumentSortMode sortMode;
  final _DocumentViewMode viewMode;
  final bool hasFilters;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<DocumentType?> onTypeChanged;
  final ValueChanged<_DocumentSortMode> onSortModeChanged;
  final ValueChanged<_DocumentViewMode> onViewModeChanged;
  final VoidCallback onClearFilters;

  const _DocumentsToolbar({
    required this.searchController,
    required this.typeFilter,
    required this.sortMode,
    required this.viewMode,
    required this.hasFilters,
    required this.onSearchChanged,
    required this.onTypeChanged,
    required this.onSortModeChanged,
    required this.onViewModeChanged,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: searchController,
            decoration: const InputDecoration(
              hintText: 'Search title, patient, PhilHealth, or type...',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: onSearchChanged,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final isNarrow = width < 500;
              final dropdownWidth = isNarrow ? width : 260.0;

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: dropdownWidth,
                    child: DropdownButtonFormField<DocumentType?>(
                      initialValue: typeFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Document Type',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<DocumentType?>(
                          value: null,
                          child: Text('All types'),
                        ),
                        ...DocumentType.values.map(
                          (type) => DropdownMenuItem<DocumentType?>(
                            value: type,
                            child: Text(_typeDisplay(type)),
                          ),
                        ),
                      ],
                      onChanged: onTypeChanged,
                    ),
                  ),
                  if (hasFilters)
                    ActionChip(
                      avatar: const Icon(
                        Icons.filter_alt_off_outlined,
                        size: 16,
                      ),
                      label: const Text('Clear filter'),
                      onPressed: onClearFilters,
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SegmentedButton<_DocumentSortMode>(
                segments: const [
                  ButtonSegment(
                    value: _DocumentSortMode.newest,
                    icon: Icon(Icons.schedule, size: 16),
                    label: Text('Newest'),
                  ),
                  ButtonSegment(
                    value: _DocumentSortMode.oldest,
                    icon: Icon(Icons.history, size: 16),
                    label: Text('Oldest'),
                  ),
                  ButtonSegment(
                    value: _DocumentSortMode.title,
                    icon: Icon(Icons.sort_by_alpha, size: 16),
                    label: Text('Title'),
                  ),
                ],
                selected: {sortMode},
                onSelectionChanged: (value) => onSortModeChanged(value.first),
              ),
              SegmentedButton<_DocumentViewMode>(
                segments: const [
                  ButtonSegment(
                    value: _DocumentViewMode.list,
                    icon: Icon(Icons.view_list_outlined, size: 16),
                    label: Text('List'),
                  ),
                  ButtonSegment(
                    value: _DocumentViewMode.grid,
                    icon: Icon(Icons.grid_view_outlined, size: 16),
                    label: Text('Grid'),
                  ),
                ],
                selected: {viewMode},
                onSelectionChanged: (value) => onViewModeChanged(value.first),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DocumentsList extends StatelessWidget {
  final List<MedicalDocument> documents;
  final Map<String, Patient> patientMap;
  final bool canManage;
  final void Function(String patientId) onChanged;

  const _DocumentsList({
    required this.documents,
    required this.patientMap,
    required this.canManage,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < documents.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _DocumentCard(
            document: documents[i],
            patient: patientMap[documents[i].patientId],
            canManage: canManage,
            onChanged: onChanged,
          ),
        ],
      ],
    );
  }
}

class _DocumentsGrid extends StatelessWidget {
  final List<MedicalDocument> documents;
  final Map<String, Patient> patientMap;
  final bool canManage;
  final void Function(String patientId) onChanged;

  const _DocumentsGrid({
    required this.documents,
    required this.patientMap,
    required this.canManage,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1200
            ? 3
            : width >= 760
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: crossAxisCount == 1 ? 210.0 : 215.0,
          ),
          itemCount: documents.length,
          itemBuilder: (context, index) {
            return _DocumentCard(
              document: documents[index],
              patient: patientMap[documents[index].patientId],
              canManage: canManage,
              onChanged: onChanged,
              compact: width < 600 || crossAxisCount > 1,
            );
          },
        );
      },
    );
  }
}

class _DocumentCard extends ConsumerWidget {
  final MedicalDocument document;
  final Patient? patient;
  final bool canManage;
  final void Function(String patientId) onChanged;
  final bool compact;

  const _DocumentCard({
    required this.document,
    required this.patient,
    required this.canManage,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final typeColor = _typeColor(document.type);
    final date = document.scanDate ?? document.createdAt;

    return AppCard(
      onTap: () => _previewDocument(context, ref),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: typeColor.withValues(alpha: 0.2)),
                ),
                child: Icon(
                  _fileIcon(document.mimeType ?? 'unknown'),
                  color: typeColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.title,
                      maxLines: compact ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _Badge(label: document.typeDisplay, color: typeColor),
                        if (document.status == DocumentStatus.archived)
                          StatusBadge.fromDocumentStatus(document.status),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) => _handleAction(context, ref, value),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'preview',
                    child: ListTile(
                      leading: Icon(Icons.visibility_outlined),
                      title: Text('Preview file'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'open',
                    child: ListTile(
                      leading: Icon(Icons.open_in_new),
                      title: Text('Open with system app'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  if (canManage)
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit details'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                  if (canManage)
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        title: Text(
                          'Delete',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (patient != null)
            InkWell(
              onTap: () => context.go('/patients/${patient!.id}'),
              child: Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      patient!.fullName,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            )
          else
            Text(
              'Patient ID: ${document.patientId}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          if (!compact &&
              document.description != null &&
              document.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              document.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    date != null ? _formatDate(date) : 'Unknown date',
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.sd_storage_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DocumentService.formatFileSize(document.fileSize),
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Preview file',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _previewDocument(context, ref),
                    icon: const Icon(Icons.visibility_outlined, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Open or download document',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _openDocument(context),
                    icon: const Icon(Icons.open_in_new, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _previewDocument(BuildContext context, WidgetRef ref) async {
    await DocumentPreviewDialog.show(
      context,
      document: document,
      patient: patient,
      canManage: canManage,
      onChanged: onChanged,
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    switch (action) {
      case 'preview':
        await _previewDocument(context, ref);
      case 'open':
        await _openDocument(context);
      case 'edit':
        await _editDocument(context, ref);
      case 'delete':
        await _deleteDocument(context, ref);
    }
  }

  Future<void> _openDocument(BuildContext context) async {
    try {
      await DocumentService.openDocument(
        document.filePath,
        fileName: DocumentService.fileNameForDocument(document),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to open document: $e')));
      }
    }
  }

  Future<void> _editDocument(BuildContext context, WidgetRef ref) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _DocumentEditDialog(document: document),
    );

    if (updated == true) {
      onChanged(document.patientId);
    }
  }

  Future<void> _deleteDocument(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Delete Document',
      message:
          'Are you sure you want to delete "${document.title}"? This cannot be undone.',
      confirmLabel: 'Delete Document',
      cancelLabel: 'Cancel',
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
      type: ConfirmDialogType.danger,
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(databaseProvider).deleteDocument(document.id);
      await ref
          .read(auditServiceProvider)
          .logAction(
            action: AuditAction.delete,
            entityType: AuditEntityTypes.document,
            entityId: document.id,
            patientId: document.patientId,
            details: 'Deleted document "${document.title}"',
          );
      String? cleanupError;
      try {
        await DocumentService.deleteDocument(document.filePath);
      } catch (e) {
        cleanupError = '$e';
      }
      onChanged(document.patientId);

      if (context.mounted) {
        final message = cleanupError == null
            ? 'Document deleted'
            : 'Document record was deleted, but its stored file could not be removed: $cleanupError';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to delete document: $e')),
        );
      }
    }
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.roundedSm,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

Color _typeColor(DocumentType type) {
  return switch (type) {
    DocumentType.labResult => AppColors.primaryEmerald,
    DocumentType.xRay => AppColors.info,
    DocumentType.prescription => AppColors.analytical,
    DocumentType.medicalCertificate => AppColors.primaryEmeraldDark,
    DocumentType.referral => AppColors.pending,
    DocumentType.other => AppColors.neutral,
  };
}

/// Dedicated, interactive in-app modal preview dialog for medical documents and scans
class DocumentPreviewDialog extends ConsumerStatefulWidget {
  final MedicalDocument document;
  final Patient? patient;
  final bool canManage;
  final void Function(String patientId) onChanged;

  const DocumentPreviewDialog({
    super.key,
    required this.document,
    required this.patient,
    required this.canManage,
    required this.onChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required MedicalDocument document,
    Patient? patient,
    bool canManage = false,
    required void Function(String patientId) onChanged,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => DocumentPreviewDialog(
        document: document,
        patient: patient,
        canManage: canManage,
        onChanged: onChanged,
      ),
    );
  }

  @override
  ConsumerState<DocumentPreviewDialog> createState() =>
      _DocumentPreviewDialogState();
}

class _DocumentPreviewDialogState extends ConsumerState<DocumentPreviewDialog> {
  final TransformationController _transformationController =
      TransformationController();
  late Future<Uint8List?> _bytesFuture;
  double _zoomLevel = 1.0;

  @override
  void initState() {
    super.initState();
    _bytesFuture = DocumentService.readDocumentBytes(widget.document.filePath);
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    setState(() {
      _zoomLevel = (_zoomLevel + 0.3).clamp(0.5, 4.0);
      _transformationController.value = Matrix4.diagonal3Values(
        _zoomLevel,
        _zoomLevel,
        1.0,
      );
    });
  }

  void _zoomOut() {
    setState(() {
      _zoomLevel = (_zoomLevel - 0.3).clamp(0.5, 4.0);
      _transformationController.value = Matrix4.diagonal3Values(
        _zoomLevel,
        _zoomLevel,
        1.0,
      );
    });
  }

  void _resetZoom() {
    setState(() {
      _zoomLevel = 1.0;
      _transformationController.value = Matrix4.identity();
    });
  }

  Future<void> _openDocument() async {
    try {
      await DocumentService.openDocument(
        widget.document.filePath,
        fileName: DocumentService.fileNameForDocument(widget.document),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to open or download document: $e')),
        );
      }
    }
  }

  bool get _isImage {
    final ext = (widget.document.mimeType ?? '').toLowerCase();
    return ext == 'jpg' || ext == 'jpeg' || ext == 'png';
  }

  bool get _isPdf {
    final ext = (widget.document.mimeType ?? '').toLowerCase();
    return ext == 'pdf';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final typeColor = _typeColor(widget.document.type);
    final date = widget.document.scanDate ?? widget.document.createdAt;

    return Dialog(
      backgroundColor: isDark
          ? AppColors.cardSurface
          : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? AppColors.border : theme.colorScheme.outlineVariant,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880, maxHeight: 820),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: typeColor.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(
                      _fileIcon(widget.document.mimeType ?? 'unknown'),
                      color: typeColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.document.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _Badge(
                              label: widget.document.typeDisplay,
                              color: typeColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (widget.patient != null)
                              widget.patient!.fullName,
                            if (date != null) _formatDate(date),
                            DocumentService.formatFileSize(
                              widget.document.fileSize,
                            ),
                          ].join('  •  '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.textSecondary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close preview',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Content Viewer
            Expanded(
              child: Container(
                color: isDark
                    ? const Color(0xFF0D0E10)
                    : const Color(0xFFF3F4F6),
                alignment: Alignment.center,
                child: FutureBuilder<Uint8List?>(
                  future: _bytesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      );
                    }

                    if (snapshot.hasError || snapshot.data == null) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _fileIcon(widget.document.mimeType ?? 'unknown'),
                              size: 64,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              snapshot.hasError
                                  ? 'Unable to load document preview'
                                  : 'Preview not available in this view',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              snapshot.hasError
                                  ? '${snapshot.error}'
                                  : 'Use "Open or Download File" below to access this document.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? AppColors.textSecondary
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final bytes = snapshot.data!;

                    if (_isImage) {
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: InteractiveViewer(
                              transformationController:
                                  _transformationController,
                              minScale: 0.5,
                              maxScale: 4.0,
                              clipBehavior: Clip.hardEdge,
                              child: Center(
                                child: Image.memory(
                                  bytes,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Text('Unable to render image'),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: (isDark ? Colors.black : Colors.white)
                                    .withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.border
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.zoom_out, size: 20),
                                    tooltip: 'Zoom out',
                                    onPressed: _zoomOut,
                                  ),
                                  Text(
                                    '${(_zoomLevel * 100).toInt()}%',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.zoom_in, size: 20),
                                    tooltip: 'Zoom in',
                                    onPressed: _zoomIn,
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.restart_alt,
                                      size: 20,
                                    ),
                                    tooltip: 'Reset zoom',
                                    onPressed: _resetZoom,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    if (_isPdf) {
                      return Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: context.semanticColors.critical
                                    .withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.picture_as_pdf,
                                size: 44,
                                color: context.semanticColors.critical,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              widget.document.title,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'PDF Document (${DocumentService.formatFileSize(widget.document.fileSize)})',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? AppColors.textSecondary
                                    : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: _openDocument,
                              icon: const Icon(Icons.download_outlined),
                              label: const Text('Download PDF Document'),
                            ),
                          ],
                        ),
                      );
                    }

                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _fileIcon(widget.document.mimeType ?? ''),
                            size: 64,
                            color: typeColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.document.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: _openDocument,
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Open or Download File'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            if (widget.document.description != null &&
                widget.document.description!.isNotEmpty) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Text(
                  widget.document.description!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.textSecondary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],

            const Divider(height: 1),

            // Footer action bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: _openDocument,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Open / Download'),
                  ),
                  Row(
                    children: [
                      if (widget.canManage) ...[
                        TextButton.icon(
                          onPressed: () async {
                            final updated = await showDialog<bool>(
                              context: context,
                              builder: (_) => _DocumentEditDialog(
                                document: widget.document,
                              ),
                            );
                            if (updated == true) {
                              widget.onChanged(widget.document.patientId);
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            }
                          },
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Edit'),
                        ),
                        const SizedBox(width: 8),
                      ],
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ],
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

Future<void> showDocumentUploadDialog(
  BuildContext context, {
  Patient? initialPatient,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) =>
        DocumentUploadDialog(initialPatient: initialPatient),
  );
}

class DocumentUploadDialog extends ConsumerStatefulWidget {
  final Patient? initialPatient;

  const DocumentUploadDialog({super.key, this.initialPatient});

  @override
  ConsumerState<DocumentUploadDialog> createState() =>
      _DocumentUploadDialogState();
}

class _DocumentUploadDialogState extends ConsumerState<DocumentUploadDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _patientSearchController = TextEditingController();
  final _patientSearchFocusNode = FocusNode();
  final _uuid = const Uuid();

  Patient? _selectedPatient;
  DocumentType _selectedType = DocumentType.labResult;
  DocumentPickerResult? _pickedFile;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_refreshSaveState);
    _patientSearchController.addListener(_handlePatientSearchChanged);
    if (widget.initialPatient != null) {
      _selectedPatient = widget.initialPatient;
      _patientSearchController.text = _patientPickerLabel(
        widget.initialPatient!,
      );
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_refreshSaveState);
    _patientSearchController.removeListener(_handlePatientSearchChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    _patientSearchController.dispose();
    _patientSearchFocusNode.dispose();
    super.dispose();
  }

  void _refreshSaveState() {
    if (mounted) setState(() {});
  }

  void _handlePatientSearchChanged() {
    final selected = _selectedPatient;
    if (selected == null) {
      _refreshSaveState();
      return;
    }

    if (_patientSearchController.text != _patientPickerLabel(selected)) {
      setState(() => _selectedPatient = null);
    } else {
      _refreshSaveState();
    }
  }

  Future<void> _scanDocument() async {
    final result = await DocumentScannerDialog.show(context);
    if (result != null) {
      setState(() {
        _pickedFile = result;
        if (_titleController.text.trim().isEmpty) {
          _titleController.text = result.name;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(patientsProvider);

    return AppFormDialog(
      icon: Icons.document_scanner_rounded,
      title: 'Upload Patient Document',
      subtitle:
          'Scan physical documents or webcam captures, or attach existing files',
      maxWidth: 680,
      content: patientsAsync.when(
        skipLoadingOnReload: true,
        data: (patients) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppFormSection(
              title: 'Patient & Classification',
              subtitle: 'Select the patient and assign document type',
              icon: Icons.person_outline,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PatientSearchDropdown(
                    patients: patients,
                    controller: _patientSearchController,
                    focusNode: _patientSearchFocusNode,
                    selectedPatient: _selectedPatient,
                    onSelected: (patient) {
                      setState(() {
                        _selectedPatient = patient;
                        _patientSearchController.text = _patientPickerLabel(
                          patient,
                        );
                      });
                    },
                    onClear: () {
                      setState(() {
                        _selectedPatient = null;
                        _patientSearchController.clear();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Document title *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<DocumentType>(
                          key: ValueKey(_selectedType),
                          initialValue: _selectedType,
                          decoration: const InputDecoration(
                            labelText: 'Document type *',
                            border: OutlineInputBorder(),
                          ),
                          items: DocumentType.values
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(_typeDisplay(type)),
                                ),
                              )
                              .toList(),
                          onChanged: (type) => setState(
                            () => _selectedType = type ?? DocumentType.other,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Description or notes (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppFormSection(
              title: 'Document Source & Attachment',
              subtitle:
                  'Scan using physical flatbed/ADF or live camera, or upload existing file',
              icon: Icons.attach_file_rounded,
              child: _PickedFilePanel(
                pickedFile: _pickedFile,
                onScanDocument: _scanDocument,
                onPickFile: () => _pickFile(imageOnly: false),
                onPickImage: () => _pickFile(imageOnly: true),
                onClear: () => setState(() => _pickedFile = null),
              ),
            ),
          ],
        ),
        loading: () => const SizedBox(height: 160, child: LoadingState()),
        error: (error, _) => AppErrorState(
          title: 'Patient list could not be loaded',
          error: error,
          onRetry: () => ref.invalidate(patientsProvider),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _canSave ? _saveDocument : null,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.cloud_upload_outlined),
          label: const Text('Save Document'),
        ),
      ],
    );
  }

  bool get _canSave =>
      !_isSaving &&
      (ref.read(currentUserProvider)?.canManageDocuments ?? false) &&
      _selectedPatient != null &&
      _pickedFile != null &&
      _titleController.text.trim().isNotEmpty;

  Future<void> _pickFile({required bool imageOnly}) async {
    try {
      final picked = imageOnly
          ? await DocumentService.pickImage()
          : await DocumentService.pickDocument();
      if (picked == null) return;
      setState(() {
        _pickedFile = picked;
        if (_titleController.text.trim().isEmpty) {
          _titleController.text = picked.name;
        }
      });
    } on DocumentValidationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to pick file: $e')));
      }
    }
  }

  Future<void> _saveDocument() async {
    final patient = _selectedPatient;
    final picked = _pickedFile;
    if (patient == null || picked == null) return;
    if (!(ref.read(currentUserProvider)?.canManageDocuments ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are not allowed to upload documents.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    String? savedFilePath;

    try {
      final documentId = _uuid.v4();
      DocumentService.validatePickedDocument(picked);
      final bytes = await picked.getBytes();
      final filePath = await DocumentService.saveDocument(
        documentId: documentId,
        patientId: patient.id,
        bytes: bytes,
        fileName: picked.name,
      );
      savedFilePath = filePath;
      final currentUser = ref.read(currentUserProvider);
      final now = DateTime.now();

      final document = MedicalDocument(
        id: documentId,
        patientId: patient.id,
        type: _selectedType,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        filePath: filePath,
        fileSize: bytes.length,
        mimeType: picked.extension,
        scannedBy: currentUser?.id ?? 'system',
        scanDate: now,
        createdAt: now,
        updatedAt: now,
        syncStatus: 1,
        clinicId: patient.clinicId ?? currentUser?.clinicId,
      );

      await ref.read(databaseProvider).insertDocument(document);
      await ref
          .read(auditServiceProvider)
          .logAction(
            action: AuditAction.create,
            entityType: AuditEntityTypes.document,
            entityId: document.id,
            patientId: patient.id,
            details:
                'Uploaded ${_typeDisplay(_selectedType)} "${document.title}" for ${patient.fullName}',
          );
      savedFilePath = null;
      ref.invalidate(documentsProvider);
      ref.invalidate(patientDocumentsProvider(patient.id));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document uploaded successfully')),
        );
      }
    } on DocumentValidationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      var errorMessage = '$e';
      if (savedFilePath != null) {
        try {
          await DocumentService.deleteDocument(savedFilePath);
        } catch (cleanupError) {
          errorMessage =
              '$errorMessage. The incomplete file could not be removed: $cleanupError';
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save document: $errorMessage')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

class _PatientSearchDropdown extends StatelessWidget {
  final List<Patient> patients;
  final TextEditingController controller;
  final FocusNode focusNode;
  final Patient? selectedPatient;
  final ValueChanged<Patient> onSelected;
  final VoidCallback onClear;

  const _PatientSearchDropdown({
    required this.patients,
    required this.controller,
    required this.focusNode,
    required this.selectedPatient,
    required this.onSelected,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final sortedPatients = List<Patient>.from(patients)
      ..sort(
        (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
      );

    return RawAutocomplete<Patient>(
      textEditingController: controller,
      focusNode: focusNode,
      displayStringForOption: _patientPickerLabel,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) return sortedPatients.take(8);

        return sortedPatients
            .where((patient) {
              final haystack = [
                patient.fullName,
                patient.philHealthNumber ?? '',
                patient.contactNumber ?? '',
                patient.barangay ?? '',
                patient.purokSitio ?? '',
              ].join(' ').toLowerCase();
              return haystack.contains(query);
            })
            .take(12);
      },
      onSelected: onSelected,
      fieldViewBuilder: (context, textController, fieldFocusNode, onSubmitted) {
        return TextField(
          controller: textController,
          focusNode: fieldFocusNode,
          decoration: InputDecoration(
            labelText: 'Attach to patient',
            hintText: 'Search name, PhilHealth, contact, barangay, or purok',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.person_search_outlined),
            suffixIcon:
                selectedPatient != null || textController.text.isNotEmpty
                ? IconButton(
                    tooltip: 'Clear patient',
                    onPressed: onClear,
                    icon: const Icon(Icons.close),
                  )
                : const Icon(Icons.arrow_drop_down),
          ),
        );
      },
      optionsViewBuilder: (context, onSelectedOption, options) {
        final optionList = options.toList();
        if (optionList.isEmpty) {
          return const SizedBox.shrink();
        }

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280, maxWidth: 620),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: optionList.length,
                separatorBuilder: (_, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final patient = optionList[index];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      child: Text(
                        patient.firstName.isNotEmpty
                            ? patient.firstName[0].toUpperCase()
                            : '?',
                      ),
                    ),
                    title: Text(
                      patient.fullName,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      [
                        if (patient.philHealthNumber?.isNotEmpty == true)
                          'PHN: ${patient.philHealthNumber}',
                        if (patient.contactNumber?.isNotEmpty == true)
                          patient.contactNumber!,
                        if (patient.barangay?.isNotEmpty == true)
                          patient.barangay!,
                      ].join(' - '),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => onSelectedOption(patient),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

String _patientPickerLabel(Patient patient) {
  final suffix = patient.philHealthNumber?.trim().isNotEmpty == true
      ? ' - PHN: ${patient.philHealthNumber}'
      : '';
  return '${patient.fullName}$suffix';
}

class _PickedFilePanel extends StatelessWidget {
  final DocumentPickerResult? pickedFile;
  final VoidCallback? onScanDocument;
  final VoidCallback onPickFile;
  final VoidCallback onPickImage;
  final VoidCallback onClear;

  const _PickedFilePanel({
    required this.pickedFile,
    this.onScanDocument,
    required this.onPickFile,
    required this.onPickImage,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (pickedFile == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (onScanDocument != null)
                FilledButton.icon(
                  onPressed: onScanDocument,
                  icon: const Icon(Icons.document_scanner_rounded, size: 18),
                  label: const Text('Scan Document (Scanner / Camera)'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryEmerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: onPickFile,
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Choose PDF / File'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onPickImage,
                icon: const Icon(Icons.image_outlined, size: 18),
                label: const Text('Choose Image'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Supported: PDF, JPG, PNG, WEBP (Max 10 MB). Scanned documents are encrypted with AES-GCM and stored securely.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.28),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryEmeraldSubtle,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              _fileIcon(pickedFile!.extension),
              size: 26,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pickedFile!.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(DocumentService.formatFileSize(pickedFile!.size)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove selected file',
            onPressed: onClear,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _DocumentEditDialog extends ConsumerStatefulWidget {
  final MedicalDocument document;

  const _DocumentEditDialog({required this.document});

  @override
  ConsumerState<_DocumentEditDialog> createState() =>
      _DocumentEditDialogState();
}

class _DocumentEditDialogState extends ConsumerState<_DocumentEditDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();
  DocumentType _type = DocumentType.labResult;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final document = widget.document;
    _titleController.text = document.title;
    _descriptionController.text = document.description ?? '';
    _notesController.text = document.notes ?? '';
    _type = document.type;
    _titleController.addListener(_refresh);
  }

  @override
  void dispose() {
    _titleController.removeListener(_refresh);
    _titleController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog(
      icon: Icons.edit_note_rounded,
      title: 'Edit Document',
      subtitle: 'Update document metadata and internal staff notes',
      maxWidth: 580,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Document title *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<DocumentType>(
            initialValue: _type,
            decoration: const InputDecoration(
              labelText: 'Document type *',
              border: OutlineInputBorder(),
            ),
            items: DocumentType.values
                .map(
                  (type) => DropdownMenuItem(
                    value: type,
                    child: Text(_typeDisplay(type)),
                  ),
                )
                .toList(),
            onChanged: (value) =>
                setState(() => _type = value ?? DocumentType.other),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description or notes',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Internal staff notes',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _canSave ? _save : null,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('Save Changes'),
        ),
      ],
    );
  }

  bool get _canSave => !_isSaving && _titleController.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_canSave) return;

    setState(() => _isSaving = true);

    final existing = widget.document;
    final now = DateTime.now();

    final updated = MedicalDocument(
      id: existing.id,
      patientId: existing.patientId,
      type: _type,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      filePath: existing.filePath,
      fileUrl: existing.fileUrl,
      fileSize: existing.fileSize,
      mimeType: existing.mimeType,
      scannedBy: existing.scannedBy,
      scanDate: existing.scanDate,
      status: existing.status,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdAt: existing.createdAt,
      updatedAt: now,
      syncStatus: existing.syncStatus == 0 ? 2 : existing.syncStatus,
      clinicId: existing.clinicId,
    );

    try {
      await ref.read(databaseProvider).updateDocument(updated);
      await ref
          .read(auditServiceProvider)
          .logAction(
            action: AuditAction.update,
            entityType: AuditEntityTypes.document,
            entityId: updated.id,
            patientId: updated.patientId,
            details: 'Updated document "${updated.title}"',
          );
      ref.invalidate(documentsProvider);
      ref.invalidate(patientDocumentsProvider(existing.patientId));

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Document saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to save document: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _EmptyDocumentsState extends StatelessWidget {
  final bool hasFilters;
  final bool canUpload;
  final VoidCallback onUpload;

  const _EmptyDocumentsState({
    required this.hasFilters,
    required this.canUpload,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters
                ? 'No documents match the filters'
                : 'No documents found',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasFilters
                ? 'Try clearing the search or type filter.'
                : 'Upload scanned records, lab results, or referrals as PDF, JPG, or PNG files.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (!hasFilters) ...[
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: canUpload ? onUpload : null,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Upload First Document'),
            ),
          ],
        ],
      ),
    );
  }
}

IconData _fileIcon(String fileType) {
  return switch (fileType.toLowerCase()) {
    'pdf' => Icons.picture_as_pdf,
    'jpg' || 'jpeg' || 'png' => Icons.image,
    _ => Icons.insert_drive_file,
  };
}

String _typeDisplay(DocumentType type) {
  return switch (type) {
    DocumentType.labResult => 'Laboratory Result',
    DocumentType.xRay => 'X-Ray / Imaging',
    DocumentType.prescription => 'Prescription',
    DocumentType.medicalCertificate => 'Medical Certificate',
    DocumentType.referral => 'Referral Letter',
    DocumentType.other => 'Other Document',
  };
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
