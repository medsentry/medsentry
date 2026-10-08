import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/clinic.dart';
import '../models/user.dart';
import '../providers/providers.dart';
import '../widgets/app_form_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/layout/responsive_layout.dart';
import '../widgets/loading_state.dart';
import '../widgets/status_badge.dart';
import '../utils/context_extensions.dart';

class RhuManagementScreen extends ConsumerStatefulWidget {
  const RhuManagementScreen({super.key});

  @override
  ConsumerState<RhuManagementScreen> createState() =>
      _RhuManagementScreenState();
}

class _RhuManagementScreenState extends ConsumerState<RhuManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all'; // 'all', 'active', 'inactive'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clinicsAsync = ref.watch(clinicsProvider);
    final usersAsync = ref.watch(usersProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: ResponsiveContentContainer(
          maxWidth: 1400,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              LayoutBuilder(
                builder: (context, headerConstraints) {
                  final isNarrow = headerConstraints.maxWidth < 600;
                  final titleSection = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rural Health Units (RHU)',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Platform-level management of municipality health facilities, operational scopes, and personnel assignments.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  );

                  final addButton = FilledButton.icon(
                    onPressed: () => _showAddClinicDialog(context),
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Add Facility'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleSection,
                        const SizedBox(height: 16),
                        addButton,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: titleSection),
                      const SizedBox(width: 16),
                      addButton,
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

            // Metrics / KPIs
            clinicsAsync.when(
              data: (clinics) {
                final allUsers = usersAsync.valueOrNull ?? <User>[];
                final activeCount = clinics.where((c) => c.isActive).length;
                final totalAssignedStaff = allUsers
                    .where((User u) => u.clinicId != null)
                    .length;

                return LayoutBuilder(
                  builder: (context, kpiConstraints) {
                    final card1 = _buildKpiCard(
                      context,
                      title: 'Total RHU Units',
                      value: '${clinics.length}',
                      icon: Icons.domain_outlined,
                      color: colorScheme.primary,
                    );
                    final card2 = _buildKpiCard(
                      context,
                      title: 'Active Facilities',
                      value: '$activeCount',
                      icon: Icons.check_circle_outline,
                      color: context.semanticColors.normal,
                    );
                    final card3 = _buildKpiCard(
                      context,
                      title: 'Assigned Personnel',
                      value: '$totalAssignedStaff',
                      icon: Icons.people_outline,
                      color: context.semanticColors.info,
                    );

                    if (kpiConstraints.maxWidth < 600) {
                      return Column(
                        children: [
                          card1,
                          const SizedBox(height: 12),
                          card2,
                          const SizedBox(height: 12),
                          card3,
                        ],
                      );
                    }

                    if (kpiConstraints.maxWidth < 900) {
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          SizedBox(
                            width: (kpiConstraints.maxWidth - 16) / 2,
                            child: card1,
                          ),
                          SizedBox(
                            width: (kpiConstraints.maxWidth - 16) / 2,
                            child: card2,
                          ),
                          SizedBox(
                            width: kpiConstraints.maxWidth,
                            child: card3,
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: card1),
                        const SizedBox(width: 16),
                        Expanded(child: card2),
                        const SizedBox(width: 16),
                        Expanded(child: card3),
                      ],
                    );
                  },
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (error, _) => AppErrorState(
                title: 'Facility metrics could not be loaded',
                error: error,
                onRetry: () => ref.invalidate(clinicsProvider),
              ),
            ),
            const SizedBox(height: 24),

            // Search and Filter Bar
            Card(
              elevation: 0,
              color: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: LayoutBuilder(
                  builder: (context, filterConstraints) {
                    final isNarrow = filterConstraints.maxWidth < 640;
                    final searchField = TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText:
                            'Search facilities by name, code, or location...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim().toLowerCase();
                        });
                      },
                    );

                    final filterButtons = SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'all', label: Text('All')),
                        ButtonSegment(value: 'active', label: Text('Active')),
                        ButtonSegment(
                          value: 'inactive',
                          label: Text('Inactive'),
                        ),
                      ],
                      selected: {_statusFilter},
                      onSelectionChanged: (val) {
                        setState(() {
                          _statusFilter = val.first;
                        });
                      },
                    );

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          searchField,
                          const Divider(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: filterButtons,
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: searchField),
                        const SizedBox(width: 16),
                        filterButtons,
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Facilities Content
            clinicsAsync.when(
              data: (clinics) {
                var filtered = clinics.where((c) {
                  if (_statusFilter == 'active' && !c.isActive) return false;
                  if (_statusFilter == 'inactive' && c.isActive) return false;
                  if (_searchQuery.isNotEmpty) {
                    final matchName = c.name.toLowerCase().contains(
                      _searchQuery,
                    );
                    final matchCode = c.code.toLowerCase().contains(
                      _searchQuery,
                    );
                    final matchAddr = (c.address ?? '').toLowerCase().contains(
                      _searchQuery,
                    );
                    return matchName || matchCode || matchAddr;
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.domain_disabled_outlined,
                    title: _searchQuery.isNotEmpty
                        ? 'No facilities match "$_searchQuery"'
                        : 'No facilities found',
                    message: 'Add a new Rural Health Unit to get started.',
                    action: FilledButton.icon(
                      onPressed: () => _showAddClinicDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Facility'),
                    ),
                  );
                }

                final users = usersAsync.valueOrNull ?? <User>[];

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 1100
                        ? 3
                        : (constraints.maxWidth > 700 ? 2 : 1);

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        mainAxisExtent: 280,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final clinic = filtered[index];
                        final assignedStaff = users
                            .where((User u) => u.clinicId == clinic.id)
                            .toList();

                        return _buildClinicCard(context, clinic, assignedStaff);
                      },
                    );
                  },
                );
              },
              loading: () => const LoadingState(),
              error: (error, _) => AppErrorState(
                title: 'Rural health units could not be loaded',
                error: error,
                onRetry: () => ref.invalidate(clinicsProvider),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildKpiCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
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

  Widget _buildClinicCard(
    BuildContext context,
    Clinic clinic,
    List<User> assignedStaff,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isActive = clinic.isActive;

    return Card(
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isActive
              ? colorScheme.outlineVariant.withValues(alpha: 0.6)
              : colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Title + Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clinic.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          clinic.code,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  StatusBadge.active(text: 'Active', showDot: true)
                else
                  StatusBadge.inactive(text: 'Inactive', showDot: true),
              ],
            ),
            const Divider(height: 24),

            // Contact / Location info
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    clinic.address ?? 'No address provided',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.phone_outlined,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    clinic.contactNumber ?? 'No contact phone',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.email_outlined,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    clinic.email ?? 'No email on record',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),

            // Footer: Personnel info + Action buttons
            Row(
              children: [
                InkWell(
                  onTap: assignedStaff.isEmpty
                      ? null
                      : () => _showAssignedStaffDialog(
                          context,
                          clinic,
                          assignedStaff,
                        ),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.groups_outlined,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${assignedStaff.length} Staff',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Edit Facility',
                  onPressed: () => _showEditClinicDialog(context, clinic),
                ),
                IconButton(
                  icon: Icon(
                    isActive ? Icons.toggle_on : Icons.toggle_off_outlined,
                    size: 24,
                    color: isActive
                        ? context.semanticColors.normal
                        : context.semanticColors.neutral,
                  ),
                  tooltip: isActive
                      ? 'Deactivate Facility'
                      : 'Activate Facility',
                  onPressed: () => _toggleClinicStatus(clinic),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 19,
                    color: context.semanticColors.critical,
                  ),
                  tooltip: 'Delete Facility',
                  onPressed: () =>
                      _confirmDeleteClinic(context, clinic, assignedStaff),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteClinic(
    BuildContext context,
    Clinic clinic,
    List<User> assignedStaff,
  ) async {
    return _showDeleteClinicConfirmDialog(context, ref, clinic, assignedStaff);
  }

  static Future<void> _showDeleteClinicConfirmDialog(
    BuildContext context,
    WidgetRef ref,
    Clinic clinic,
    List<User> assignedStaff,
  ) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final codeController = TextEditingController();
    var isDeleting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final enteredCode = codeController.text.trim().toUpperCase();
            final isCodeMatched = enteredCode == clinic.code.toUpperCase();

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.semanticColors.criticalBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: context.semanticColors.critical,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Delete Rural Health Unit',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodyMedium,
                        children: [
                          const TextSpan(
                            text: 'Are you sure you want to permanently delete ',
                          ),
                          TextSpan(
                            text: clinic.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: ' (${clinic.code})? This will remove the facility from the provincial system.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (assignedStaff.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.semanticColors.warningBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: context.semanticColors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: context.semanticColors.warning,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${assignedStaff.length} staff member(s) are currently assigned to this facility. Deleting will unassign these staff members.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: context.semanticColors.warning,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      'To confirm deletion, please type the facility code "${clinic.code}":',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: codeController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: clinic.code,
                        prefixIcon: const Icon(Icons.shield_outlined, size: 20),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: (!isCodeMatched || isDeleting)
                      ? null
                      : () async {
                          setDialogState(() => isDeleting = true);
                          final currentUserId =
                              ref.read(currentUserProvider)?.id;

                          try {
                            await ref
                                .read(clinicRepositoryProvider)
                                .deleteClinic(
                                  clinic.id,
                                  actorUserId: currentUserId,
                                );

                            ref.invalidate(clinicsProvider);
                            ref.invalidate(usersProvider);

                            if (context.mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Facility "${clinic.name}" deleted successfully',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isDeleting = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor:
                                      context.semanticColors.critical,
                                  content: Text('Error deleting facility: $e'),
                                ),
                              );
                            }
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: context.semanticColors.critical,
                    foregroundColor: Colors.white,
                  ),
                  icon: isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.delete_forever, size: 18),
                  label: Text(isDeleting ? 'Deleting...' : 'Delete Facility'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _toggleClinicStatus(Clinic clinic) async {
    final newStatus = !clinic.isActive;
    final currentUserId = ref.read(currentUserProvider)?.id;

    await ref
        .read(clinicRepositoryProvider)
        .toggleClinicStatus(clinic.id, newStatus, actorUserId: currentUserId);

    ref.invalidate(clinicsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${clinic.name} is now ${newStatus ? 'active' : 'inactive'}',
          ),
        ),
      );
    }
  }

  void _showAssignedStaffDialog(
    BuildContext context,
    Clinic clinic,
    List<User> assignedStaff,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.groups_outlined),
            const SizedBox(width: 10),
            Expanded(child: Text('${clinic.name} Personnel')),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: assignedStaff.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, idx) {
              final staff = assignedStaff[idx];
              return ListTile(
                leading: CircleAvatar(child: Text(staff.initials)),
                title: Text(staff.fullName),
                subtitle: Text('${staff.roleDisplay} • ${staff.email}'),
                trailing: staff.isActive
                    ? StatusBadge.active(text: 'Active')
                    : StatusBadge.inactive(text: 'Inactive'),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAddClinicDialog(BuildContext context) {
    _showClinicFormModal(context);
  }

  void _showEditClinicDialog(BuildContext context, Clinic clinic) {
    _showClinicFormModal(context, existing: clinic);
  }

  void _showClinicFormModal(BuildContext context, {Clinic? existing}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _ClinicFormModal(existing: existing),
    );
  }
}

class _ClinicFormModal extends ConsumerStatefulWidget {
  final Clinic? existing;

  const _ClinicFormModal({this.existing});

  @override
  ConsumerState<_ClinicFormModal> createState() => _ClinicFormModalState();
}

class _ClinicFormModalState extends ConsumerState<_ClinicFormModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _addressController;
  late final TextEditingController _contactController;
  late final TextEditingController _emailController;
  bool _isSaving = false;
  bool _isDirty = false;

  void _markDirty() {
    if (!_isDirty && mounted) {
      setState(() => _isDirty = true);
    }
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _codeController = TextEditingController(text: existing?.code ?? '');
    _addressController = TextEditingController(text: existing?.address ?? '');
    _contactController = TextEditingController(
      text: existing?.contactNumber ?? '',
    );
    _emailController = TextEditingController(text: existing?.email ?? '');

    _nameController.addListener(_markDirty);
    _codeController.addListener(_markDirty);
    _addressController.addListener(_markDirty);
    _contactController.addListener(_markDirty);
    _emailController.addListener(_markDirty);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleCancel() async {
    if (!_isDirty || _isSaving) {
      Navigator.of(context).pop();
      return;
    }
    final shouldDiscard = await confirmDiscardUnsavedChanges(context);
    if (shouldDiscard && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    final clinicsList = ref.watch(clinicsProvider).valueOrNull ?? [];

    return PopScope(
      canPop: !_isDirty || _isSaving,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleCancel();
      },
      child: AppFormDialog(
        icon: existing != null
            ? Icons.edit_outlined
            : Icons.domain_add_outlined,
        title: existing != null
            ? 'Edit Health Unit'
            : 'Register Rural Health Unit',
        subtitle: existing != null
            ? 'Update facility details for ${existing.name}'
            : 'Register a new RHU facility node into the multi-tenant platform',
        maxWidth: 580,
        onClose: _isSaving ? null : _handleCancel,
        isLoading: _isSaving,
        loadingText: existing != null
            ? 'Updating facility details...'
            : 'Registering facility...',
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppFormSection(
                title: 'Facility Identification',
                subtitle:
                    'Official registration name and unique system identifier code',
                icon: Icons.domain_outlined,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Facility Name *',
                        hintText: 'e.g. RHU Cantilan Rural Health Center',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.domain_outlined),
                      ),
                      validator: (v) {
                        final trimmed = v?.trim() ?? '';
                        if (trimmed.isEmpty) {
                          return 'Facility name is required.';
                        }
                        if (trimmed.length < 3) {
                          return 'Facility name must be at least 3 characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _codeController,
                      enabled: existing == null,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'Facility Unique Code *',
                        hintText: 'e.g. RHU-CAN',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.badge_outlined),
                        helperText: existing != null
                            ? 'Facility code cannot be changed once established.'
                            : 'Uppercase alphanumeric code (2-10 characters)',
                      ),
                      validator: (v) {
                        final trimmed = v?.trim().toUpperCase() ?? '';
                        if (trimmed.isEmpty) {
                          return 'Facility code is required.';
                        }
                        if (!RegExp(r'^[A-Z0-9\-_]{2,12}$').hasMatch(trimmed)) {
                          return 'Use 2-12 uppercase letters, numbers, or dashes.';
                        }
                        if (existing == null) {
                          final duplicate = clinicsList.any(
                            (c) => c.code.trim().toUpperCase() == trimmed,
                          );
                          if (duplicate) {
                            return 'A facility with code "$trimmed" already exists.';
                          }
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppFormSection(
                title: 'Location & Contact Details',
                subtitle:
                    'Physical geographic location and official communication channels',
                icon: Icons.location_on_outlined,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Physical Facility Address *',
                        hintText:
                            'e.g. Barangay Poblacion, Cantilan, Surigao del Sur',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      validator: (v) {
                        final trimmed = v?.trim() ?? '';
                        if (trimmed.isEmpty) {
                          return 'Facility address is required.';
                        }
                        if (!isValidPostalAddress(trimmed)) {
                          return 'Enter a valid address (3-200 characters).';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _contactController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Contact Number',
                              hintText: 'e.g. 0917-123-4567',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            validator: (v) {
                              final trimmed = v?.trim() ?? '';
                              if (trimmed.isEmpty) return null;
                              final digits = trimmed.replaceAll(
                                RegExp(r'\D'),
                                '',
                              );
                              final nationalDigits = digits.startsWith('63')
                                  ? '0${digits.substring(2)}'
                                  : digits;
                              if (!RegExp(
                                r'^0[2-9]\d{8,9}$',
                              ).hasMatch(nationalDigits)) {
                                return 'Enter a valid Philippine mobile or landline number.';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Official Email',
                              hintText: 'e.g. rhu.cantilan@doh.gov.ph',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (v) {
                              final trimmed = v?.trim() ?? '';
                              if (trimmed.isEmpty) return null;
                              if (!isValidEmailAddress(trimmed)) {
                                return 'Enter a valid email address.';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (existing != null) ...[
            AppDialogAction(
              label: 'Delete Facility',
              isDestructive: true,
              icon: Icons.delete_outline,
              onPressed: _isSaving
                  ? null
                  : () {
                      Navigator.pop(context);
                      final allUsers =
                          ref.read(usersProvider).valueOrNull ?? [];
                      final assigned = allUsers
                          .where((u) => u.clinicId == existing.id)
                          .toList();
                      _RhuManagementScreenState._showDeleteClinicConfirmDialog(
                        context,
                        ref,
                        existing,
                        assigned,
                      );
                    },
            ),
            const Spacer(),
          ],
          AppDialogAction(
            label: 'Cancel',
            onPressed: _isSaving ? null : _handleCancel,
          ),
          AppDialogAction(
            label: _isSaving
                ? 'Saving...'
                : (existing != null ? 'Update Facility' : 'Register Facility'),
            isPrimary: true,
            icon: Icons.save_outlined,
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final currentUserId = ref.read(currentUserProvider)?.id;

    try {
      final existing = widget.existing;
      final phoneInput = _contactController.text.trim();
      final normalizedContact = phoneInput.isEmpty
          ? null
          : (isValidPhilippinePhone(phoneInput)
              ? formatPhilippinePhone(phoneInput)
              : phoneInput);

      if (existing != null) {
        final updated = existing.copyWith(
          name: _nameController.text.trim(),
          code: _codeController.text.trim().toUpperCase(),
          address: _addressController.text.trim(),
          contactNumber: normalizedContact,
          email: _emailController.text.trim(),
        );
        await ref
            .read(clinicRepositoryProvider)
            .updateClinic(updated, actorUserId: currentUserId);
      } else {
        await ref
            .read(clinicRepositoryProvider)
            .createClinic(
              name: _nameController.text.trim(),
              code: _codeController.text.trim().toUpperCase(),
              address: _addressController.text.trim(),
              contactNumber: normalizedContact,
              email: _emailController.text.trim(),
              actorUserId: currentUserId,
            );
      }

      ref.invalidate(clinicsProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              existing != null
                  ? 'Facility "${_nameController.text.trim()}" updated successfully'
                  : 'Facility "${_nameController.text.trim()}" registered successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving facility: $e')));
      }
    }
  }
}
