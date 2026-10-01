import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../models/document.dart';
import '../models/patient.dart';
import '../providers/providers.dart';
import '../services/document_service.dart';
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
  DocumentStatus? _statusFilter;
  _DocumentSortMode _sortMode = _DocumentSortMode.newest;
  _DocumentViewMode _viewMode = _DocumentViewMode.list;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasFilters =>
      _searchQuery.isNotEmpty || _typeFilter != null || _statusFilter != null;

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _typeFilter = null;
      _statusFilter = null;
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
      final matchesStatus =
          _statusFilter == null || doc.status == _statusFilter;
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
              final pendingCount = documents
                  .where((doc) => doc.status == DocumentStatus.pending)
                  .length;
              final verifiedCount = documents
                  .where((doc) => doc.status == DocumentStatus.verified)
                  .length;
              final today = DateTime.now();
              final todayCount = documents.where((doc) {
                final date = doc.scanDate ?? doc.createdAt;
                if (date == null) return false;
                return date.year == today.year &&
                    date.month == today.month &&
                    date.day == today.day;
              }).length;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DocumentsPageHeader(
                      totalCount: documents.length,
                      filteredCount: filtered.length,
                      pendingCount: pendingCount,
                      verifiedCount: verifiedCount,
                      todayCount: todayCount,
                      canUpload: canManage,
                      onUpload: () => _showUploadDialog(context),
                    ),
                    const SizedBox(height: 16),
                    _DocumentsToolbar(
                      searchController: _searchController,
                      typeFilter: _typeFilter,
                      statusFilter: _statusFilter,
                      sortMode: _sortMode,
                      viewMode: _viewMode,
                      hasFilters: _hasFilters,
                      onSearchChanged: (value) =>
                          setState(() => _searchQuery = value),
                      onTypeChanged: (value) =>
                          setState(() => _typeFilter = value),
                      onStatusChanged: (value) =>
                          setState(() => _statusFilter = value),
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
              );
            },
            loading: () => const LoadingState(),
            error: (error, stack) => Center(child: Text('Error: $error')),
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
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => const _DocumentUploadDialog(),
    );
  }
}

class _DocumentsPageHeader extends StatelessWidget {
  final int totalCount;
  final int filteredCount;
  final int pendingCount;
  final int verifiedCount;
  final int todayCount;
  final bool canUpload;
  final VoidCallback onUpload;

  const _DocumentsPageHeader({
    required this.totalCount,
    required this.filteredCount,
    required this.pendingCount,
    required this.verifiedCount,
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
        Row(
          children: [
            Expanded(
              child: Column(
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
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.68,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: canUpload ? onUpload : null,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Upload Document'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _StatChip(
              icon: Icons.folder_outlined,
              label: 'Total',
              value: '$totalCount',
              color: MedSentryColors.green700,
            ),
            _StatChip(
              icon: Icons.today_outlined,
              label: 'Today',
              value: '$todayCount',
              color: MedSentryColors.green600,
            ),
            _StatChip(
              icon: Icons.pending_actions_outlined,
              label: 'Pending review',
              value: '$pendingCount',
              color: const Color(0xFFF59E0B),
            ),
            _StatChip(
              icon: Icons.verified_outlined,
              label: 'Verified',
              value: '$verifiedCount',
              color: const Color(0xFF16A34A),
            ),
            if (filteredCount != totalCount)
              _StatChip(
                icon: Icons.filter_alt_outlined,
                label: 'Showing',
                value: '$filteredCount',
                color: MedSentryColors.green800,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.62),
                ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DocumentsToolbar extends StatelessWidget {
  final TextEditingController searchController;
  final DocumentType? typeFilter;
  final DocumentStatus? statusFilter;
  final _DocumentSortMode sortMode;
  final _DocumentViewMode viewMode;
  final bool hasFilters;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<DocumentType?> onTypeChanged;
  final ValueChanged<DocumentStatus?> onStatusChanged;
  final ValueChanged<_DocumentSortMode> onSortModeChanged;
  final ValueChanged<_DocumentViewMode> onViewModeChanged;
  final VoidCallback onClearFilters;

  const _DocumentsToolbar({
    required this.searchController,
    required this.typeFilter,
    required this.statusFilter,
    required this.sortMode,
    required this.viewMode,
    required this.hasFilters,
    required this.onSearchChanged,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.onSortModeChanged,
    required this.onViewModeChanged,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: 'Search title, patient, PhilHealth, or type...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: onSearchChanged,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<DocumentType?>(
                    initialValue: typeFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Type',
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
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<DocumentStatus?>(
                    initialValue: statusFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<DocumentStatus?>(
                        value: null,
                        child: Text('All statuses'),
                      ),
                      ...DocumentStatus.values.map(
                        (status) => DropdownMenuItem<DocumentStatus?>(
                          value: status,
                          child: Text(_statusDisplay(status)),
                        ),
                      ),
                    ],
                    onChanged: onStatusChanged,
                  ),
                ),
                if (hasFilters)
                  ActionChip(
                    avatar: const Icon(Icons.filter_alt_off_outlined, size: 16),
                    label: const Text('Clear filters'),
                    onPressed: onClearFilters,
                  ),
              ],
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
            childAspectRatio: crossAxisCount == 1 ? 2.8 : 1.15,
          ),
          itemCount: documents.length,
          itemBuilder: (context, index) {
            return _DocumentCard(
              document: documents[index],
              patient: patientMap[documents[index].patientId],
              canManage: canManage,
              onChanged: onChanged,
              compact: crossAxisCount > 1,
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

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDocument(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _fileIcon(document.mimeType ?? 'unknown'),
                      color: typeColor,
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
                            _Badge(
                              label: document.typeDisplay,
                              color: typeColor,
                            ),
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
                        value: 'open',
                        child: ListTile(
                          leading: Icon(Icons.open_in_new),
                          title: Text('Open file'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                      if (canManage &&
                          document.status == DocumentStatus.pending)
                        const PopupMenuItem(
                          value: 'verify',
                          child: ListTile(
                            leading: Icon(Icons.verified_outlined),
                            title: Text('Mark verified'),
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
              Row(
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
                  const Spacer(),
                  if (canManage && document.status == DocumentStatus.pending)
                    TextButton.icon(
                      onPressed: () => _verifyDocument(context, ref),
                      icon: const Icon(Icons.verified_outlined, size: 18),
                      label: const Text('Verify'),
                    ),
                  IconButton(
                    tooltip: 'Open',
                    onPressed: () => _openDocument(context),
                    icon: const Icon(Icons.open_in_new),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    switch (action) {
      case 'open':
        await _openDocument(context);
      case 'verify':
        await _verifyDocument(context, ref);
      case 'edit':
        await _editDocument(context, ref);
      case 'delete':
        await _deleteDocument(context, ref);
    }
  }

  Future<void> _openDocument(BuildContext context) async {
    try {
      await DocumentService.openDocument(document.filePath);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to open document: $e')));
      }
    }
  }

  Future<void> _verifyDocument(BuildContext context, WidgetRef ref) async {
    if (!canManage || document.status == DocumentStatus.verified) return;

    final currentUser = ref.read(currentUserProvider);
    final now = DateTime.now();
    final updated = document.copyWith(
      status: DocumentStatus.verified,
      verifiedBy: currentUser?.id ?? 'system',
      verifiedDate: now,
      updatedAt: now,
      syncStatus: document.syncStatus == 0 ? 2 : document.syncStatus,
    );

    try {
      await ref.read(databaseProvider).updateDocument(updated);
      onChanged(document.patientId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document marked as verified')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to verify document: $e')),
        );
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Delete "${document.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await DocumentService.deleteDocument(document.filePath);
      await ref.read(databaseProvider).deleteDocument(document.id);
      onChanged(document.patientId);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Document deleted')));
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
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
    DocumentType.labResult => MedSentryColors.green700,
    DocumentType.xRay => const Color(0xFF0EA5E9),
    DocumentType.prescription => const Color(0xFF8B5CF6),
    DocumentType.medicalCertificate => MedSentryColors.green800,
    DocumentType.referral => const Color(0xFFF59E0B),
    DocumentType.other => MedSentryColors.statusNeutral,
  };
}

class _DocumentUploadDialog extends ConsumerStatefulWidget {
  const _DocumentUploadDialog();

  @override
  ConsumerState<_DocumentUploadDialog> createState() =>
      _DocumentUploadDialogState();
}

class _DocumentUploadDialogState extends ConsumerState<_DocumentUploadDialog> {
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

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(patientsProvider);

    return AlertDialog(
      title: const Text('Upload Patient Document'),
      content: SizedBox(
        width: 620,
        child: patientsAsync.when(
          data: (patients) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                          labelText: 'Document title',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<DocumentType>(
                        initialValue: _selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Document type',
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
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description or notes',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                _PickedFilePanel(
                  pickedFile: _pickedFile,
                  onPickFile: () => _pickFile(imageOnly: false),
                  onPickImage: () => _pickFile(imageOnly: true),
                  onClear: () => setState(() => _pickedFile = null),
                ),
              ],
            ),
          ),
          loading: () => const SizedBox(height: 160, child: LoadingState()),
          error: (error, stack) => Text('Unable to load patients: $error'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _canSave ? _saveDocument : null,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
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
        _selectedType = DocumentService.getDocumentType(picked.extension);
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
      );

      await ref.read(databaseProvider).insertDocument(document);
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to save document: $e')));
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
  final VoidCallback onPickFile;
  final VoidCallback onPickImage;
  final VoidCallback onClear;

  const _PickedFilePanel({
    required this.pickedFile,
    required this.onPickFile,
    required this.onPickImage,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (pickedFile == null) {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          OutlinedButton.icon(
            onPressed: onPickFile,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Choose PDF or file'),
          ),
          OutlinedButton.icon(
            onPressed: onPickImage,
            icon: const Icon(Icons.image_outlined),
            label: const Text('Choose image'),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.28),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(_fileIcon(pickedFile!.extension), size: 34),
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
  DocumentStatus _status = DocumentStatus.pending;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final document = widget.document;
    _titleController.text = document.title;
    _descriptionController.text = document.description ?? '';
    _notesController.text = document.notes ?? '';
    _type = document.type;
    _status = document.status;
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
    return AlertDialog(
      title: const Text('Edit Document'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Document title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<DocumentType>(
                      initialValue: _type,
                      decoration: const InputDecoration(
                        labelText: 'Document type',
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
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<DocumentStatus>(
                      initialValue: _status,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: DocumentStatus.values
                          .map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(_statusDisplay(status)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(
                        () => _status = value ?? DocumentStatus.pending,
                      ),
                    ),
                  ),
                ],
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
                  labelText: 'Internal notes',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _canSave ? _save : null,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('Save'),
        ),
      ],
    );
  }

  bool get _canSave => !_isSaving && _titleController.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_canSave) return;

    setState(() => _isSaving = true);

    final currentUser = ref.read(currentUserProvider);
    final existing = widget.document;
    final now = DateTime.now();
    final verifiedNow =
        _status == DocumentStatus.verified &&
        existing.status != DocumentStatus.verified;

    final updated = MedicalDocument(
      id: existing.id,
      patientId: existing.patientId,
      consultationId: existing.consultationId,
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
      verifiedBy: verifiedNow
          ? currentUser?.id ?? 'system'
          : existing.verifiedBy,
      verifiedDate: verifiedNow ? now : existing.verifiedDate,
      status: _status,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdAt: existing.createdAt,
      updatedAt: now,
      syncStatus: existing.syncStatus == 0 ? 2 : existing.syncStatus,
    );

    try {
      await ref.read(databaseProvider).updateDocument(updated);
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
          const Icon(Icons.folder_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            hasFilters
                ? 'No documents match the filters'
                : 'No documents found',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasFilters
                ? 'Try clearing the search or type filter.'
                : 'Upload scanned records, lab results, or referrals as PDF, JPG, or PNG files.',
            style: const TextStyle(color: Colors.grey),
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
    DocumentType.labResult => 'Lab Result',
    DocumentType.xRay => 'X-Ray / Imaging',
    DocumentType.prescription => 'Prescription',
    DocumentType.medicalCertificate => 'Medical Certificate',
    DocumentType.referral => 'Referral',
    DocumentType.other => 'Other',
  };
}

String _statusDisplay(DocumentStatus status) {
  return switch (status) {
    DocumentStatus.pending => 'Pending',
    DocumentStatus.verified => 'Verified',
    DocumentStatus.archived => 'Archived',
  };
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
