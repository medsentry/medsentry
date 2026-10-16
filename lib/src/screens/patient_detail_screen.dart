import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/report_pdf_service.dart';
import '../utils/patient_address_data.dart';
import '../widgets/app_card.dart';
import '../widgets/app_form_dialog.dart';
import '../widgets/layout/responsive_layout.dart';
import '../widgets/loading_state.dart';
import 'documents_screen.dart';

class PatientDetailScreen extends ConsumerWidget {
  final String patientId;

  const PatientDetailScreen({super.key, required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientAsync = ref.watch(patientProvider(patientId));

    return patientAsync.when(
      data: (patient) {
        if (patient == null) {
          return const Center(child: Text('Patient not found'));
        }

        final currentUser = ref.watch(currentUserProvider);
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return ResponsiveContentContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PatientIdentityHeader(
                patient: patient,
                onArchive:
                    currentUser?.canManageArchive == true && !patient.isArchived
                    ? () => _archivePatient(context, ref, patient)
                    : null,
              ),
              _PatientActionsBar(
                patient: patient,
                onUploadDocuments: () => _handleUploadDocuments(context, ref, patient),
                onAuditHistory: () => _handleAuditHistory(context, ref, patient),
                onCreateRecord: () => _handleCreateRecord(context, ref, patient),
                onEditDetails: () => _handleEditDetails(context, ref, patient),
                onPrintRecord: () => _handlePrintRecord(context, ref, patient),
                onArchive:
                    currentUser?.canManageArchive == true && !patient.isArchived
                    ? () => _archivePatient(context, ref, patient)
                    : null,
                onDelete: currentUser?.canManageArchive == true
                    ? () => _confirmDeletePatient(context, ref, patient)
                    : null,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: DefaultTabController(
                  length: 4,
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.cardSurface : theme.colorScheme.surface,
                          borderRadius: AppRadius.roundedSm,
                          border: Border.all(
                            color: isDark ? AppColors.border : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        child: TabBar(
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          indicatorColor: isDark ? AppColors.primaryEmerald : theme.colorScheme.primary,
                          labelColor: isDark ? AppColors.primaryEmerald : theme.colorScheme.primary,
                          unselectedLabelColor: isDark ? AppColors.textSecondary : theme.colorScheme.onSurfaceVariant,
                          tabs: const [
                            Tab(icon: Icon(Icons.badge_outlined, size: 18), text: 'Demographics & Info'),
                            Tab(icon: Icon(Icons.medical_services_outlined, size: 18), text: 'Clinical Records (SOAP)'),
                            Tab(icon: Icon(Icons.attach_file_outlined, size: 18), text: 'Attached Documents'),
                            Tab(icon: Icon(Icons.history_outlined, size: 18), text: 'Audit Trail'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _OverviewTab(patient: patient),
                            _PatientConsultationsList(
                              patient: patient,
                              onCreateRecord: () => _handleCreateRecord(context, ref, patient),
                            ),
                            _PatientDocumentsList(
                              patient: patient,
                              onUploadDocument: () => _handleUploadDocuments(context, ref, patient),
                            ),
                            _PatientAuditTrailList(patient: patient),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const LoadingState(),
      error: (error, _) => AppErrorState(
        title: 'Patient record could not be loaded',
        error: error,
        onRetry: () => ref.invalidate(patientProvider(patientId)),
      ),
    );
  }

  Future<void> _handleUploadDocuments(
    BuildContext context,
    WidgetRef ref,
    Patient patient,
  ) async {
    await showDocumentUploadDialog(context, initialPatient: patient);
    ref.invalidate(patientDocumentsProvider(patient.id));
    ref.invalidate(patientAuditLogsProvider(patient.id));
    ref.invalidate(documentsProvider);
  }

  void _handleAuditHistory(
    BuildContext context,
    WidgetRef ref,
    Patient patient,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => _PatientAuditHistoryDialog(patient: patient),
    );
  }

  Future<void> _handleCreateRecord(
    BuildContext context,
    WidgetRef ref,
    Patient patient,
  ) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => _CreateConsultationDialog(patient: patient),
    );
    if (created == true) {
      ref.invalidate(patientConsultationsProvider(patient.id));
      ref.invalidate(patientAuditLogsProvider(patient.id));
    }
  }

  Future<void> _handleEditDetails(
    BuildContext context,
    WidgetRef ref,
    Patient patient,
  ) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _PatientEditDialog(patient: patient),
    );
    if (updated == true) {
      ref.invalidate(patientProvider(patient.id));
      ref.invalidate(patientsProvider);
    }
  }

  void _handlePrintRecord(
    BuildContext context,
    WidgetRef ref,
    Patient patient,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => _PatientPrintRecordDialog(patient: patient),
    );
  }

  Future<void> _confirmDeletePatient(
    BuildContext context,
    WidgetRef ref,
    Patient patient,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Patient Record'),
        content: Text(
          'Are you sure you want to permanently delete the record for ${patient.fullName}? This action is recorded in the audit trail.',
        ),
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

    final userId = ref.read(currentUserProvider)?.id ?? 'system';
    await ref.read(patientRepositoryProvider).deletePatient(patient.id, userId);
    ref.invalidate(patientsProvider);
    ref.invalidate(patientProvider(patient.id));
    ref.invalidate(auditLogsProvider);

    if (context.mounted) {
      context.go('/patients');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient record deleted successfully')),
      );
    }
  }

  Future<void> _archivePatient(
    BuildContext context,
    WidgetRef ref,
    Patient patient,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Patient Record'),
        content: Text(
          'Archive ${patient.fullName}? The record can be restored from the Archive module.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final userId = ref.read(currentUserProvider)?.id ?? 'system';
      await ref
          .read(patientRepositoryProvider)
          .deletePatient(patient.id, userId);
      ref.invalidate(patientsProvider);
      ref.invalidate(archivedPatientsProvider);
      ref.invalidate(auditLogsProvider);
      ref.invalidate(patientProvider(patient.id));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${patient.fullName} archived.')),
        );
        context.go('/patients');
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not archive patient: $error')),
        );
      }
    }
  }
}

class _PatientIdentityHeader extends StatelessWidget {
  final Patient patient;
  final VoidCallback? onArchive;

  const _PatientIdentityHeader({required this.patient, this.onArchive});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardSurface : theme.colorScheme.surface,
        borderRadius: AppRadius.roundedMd,
        border: Border.all(
          color: isDark
              ? AppColors.border
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: isDark ? AppShadows.subtle : null,
      ),
      child: _PatientIdentity(patient: patient),
    );
  }
}

class _PatientIdentity extends StatelessWidget {
  final Patient patient;

  const _PatientIdentity({required this.patient});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryEmerald : theme.colorScheme.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8, top: 4),
          child: IconButton.filledTonal(
            tooltip: 'Back to Patients',
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/patients');
              }
            },
          ),
        ),
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isDark ? AppColors.primaryEmeraldSubtle : primary.withValues(alpha: 0.1),
            borderRadius: AppRadius.roundedSm,
            border: Border.all(
              color: isDark ? primary.withValues(alpha: 0.25) : primary.withValues(alpha: 0.25),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            patient.firstName.isNotEmpty
                ? patient.firstName[0].toUpperCase()
                : '?',
            style: TextStyle(
              color: primary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
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
                      patient.fullName,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: isDark ? AppColors.textPrimary : null,
                      ),
                    ),
                  ),
                  if (patient.bloodType != null &&
                      patient.bloodType!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: theme.colorScheme.error.withValues(
                            alpha: 0.25,
                          ),
                        ),
                      ),
                      child: Text(
                        patient.bloodType!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _InfoChip(
                    icon: Icons.credit_card,
                    label: 'PHN: ${patient.philHealthNumber ?? 'N/A'}',
                  ),
                  _InfoChip(
                    icon: Icons.cake_outlined,
                    label: '${patient.age ?? 'N/A'} yrs',
                  ),
                  _InfoChip(
                    icon: Icons.wc_outlined,
                    label: patient.gender?.toUpperCase() ?? 'UNKNOWN',
                  ),
                  if (patient.barangay != null)
                    _InfoChip(
                      icon: Icons.location_on_outlined,
                      label: patient.barangay!,
                    ),
                  if (patient.allergies != null &&
                      patient.allergies!.trim().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: theme.colorScheme.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 13,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Allergy: ${patient.allergies!}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PatientActionsBar extends StatelessWidget {
  final Patient patient;
  final VoidCallback onUploadDocuments;
  final VoidCallback onAuditHistory;
  final VoidCallback onCreateRecord;
  final VoidCallback onEditDetails;
  final VoidCallback onPrintRecord;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;

  const _PatientActionsBar({
    required this.patient,
    required this.onUploadDocuments,
    required this.onAuditHistory,
    required this.onCreateRecord,
    required this.onEditDetails,
    required this.onPrintRecord,
    this.onArchive,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardSurface : theme.colorScheme.surface,
        borderRadius: AppRadius.roundedMd,
        border: Border.all(
          color: isDark
              ? AppColors.border
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: isDark ? AppShadows.subtle : null,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 680;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment:
                isNarrow ? WrapAlignment.start : WrapAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark
                          ? AppColors.primaryEmerald
                          : theme.colorScheme.primary,
                      foregroundColor: isDark
                          ? const Color(0xFF080909)
                          : theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    onPressed: onCreateRecord,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text(
                      'Create / New Record',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onPressed: onUploadDocuments,
                    icon: const Icon(Icons.upload_file_outlined, size: 18),
                    label: const Text('Upload Documents'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onPressed: onEditDetails,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit Details'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onPressed: onPrintRecord,
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: const Text('Print Record'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onPressed: onAuditHistory,
                    icon: const Icon(Icons.history_outlined, size: 18),
                    label: const Text('History / Audit Log'),
                  ),
                ],
              ),
              if (onArchive != null || onDelete != null)
                PopupMenuButton<String>(
                  tooltip: 'More Patient Options',
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'archive') onArchive?.call();
                    if (value == 'delete') onDelete?.call();
                  },
                  itemBuilder: (context) => [
                    if (onArchive != null)
                      const PopupMenuItem(
                        value: 'archive',
                        child: Row(
                          children: [
                            Icon(Icons.archive_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Archive Patient'),
                          ],
                        ),
                      ),
                    if (onDelete != null)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.redAccent,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Delete Record',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  final Patient patient;

  const _OverviewTab({required this.patient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 760;
            final panels = [
              _SectionPanel(
                title: 'Basic Information',
                icon: Icons.badge_outlined,
                children: [
                  _InfoRow(label: 'First Name', value: patient.firstName),
                  _InfoRow(
                    label: 'Middle Initial',
                    value: formatMiddleInitial(patient.middleName),
                  ),
                  _InfoRow(label: 'Last Name', value: patient.lastName),
                  _InfoRow(
                    label: 'Suffix',
                    value: normalizeSuffix(patient.suffix),
                  ),
                  _InfoRow(
                    label: 'Date of Birth',
                    value: _shortDate(patient.dateOfBirth),
                  ),
                  _InfoRow(
                    label: 'Age',
                    value: '${patient.age ?? 'N/A'} years',
                  ),
                  _InfoRow(
                    label: 'Gender',
                    value: patient.gender?.toUpperCase(),
                  ),
                  _InfoRow(
                    label: 'Civil Status',
                    value: patient.civilStatus?.toUpperCase(),
                  ),
                ],
              ),
              _SectionPanel(
                title: 'Address Information',
                icon: Icons.home_outlined,
                children: [
                  _InfoRow(label: 'Street / House No.', value: patient.address),
                  _InfoRow(label: 'Municipality', value: patient.city),
                  _InfoRow(label: 'Barangay', value: patient.barangay),
                  _InfoRow(label: 'Purok / Sitio', value: patient.purokSitio),
                  _InfoRow(label: 'Province', value: patient.province),
                  _InfoRow(label: 'ZIP Code', value: patient.zipCode),
                ],
              ),
              _SectionPanel(
                title: 'Contact Information',
                icon: Icons.contact_phone_outlined,
                children: [
                  _InfoRow(
                    label: 'Contact Number',
                    value: patient.contactNumber,
                  ),
                  _InfoRow(label: 'Email Address', value: patient.email),
                  _InfoRow(
                    label: 'Emergency Name',
                    value: patient.emergencyContactName,
                  ),
                  _InfoRow(
                    label: 'Relationship',
                    value: patient.emergencyContactRelation,
                  ),
                  _InfoRow(
                    label: 'Emergency Number',
                    value: patient.emergencyContactNumber,
                  ),
                ],
              ),
              _SectionPanel(
                title: 'Medical / Other Information',
                icon: Icons.medical_information_outlined,
                children: [
                  _InfoRow(label: 'Blood Type', value: patient.bloodType),
                  _InfoRow(
                    label: 'Allergies',
                    value: patient.allergies ?? 'None',
                  ),
                  _InfoRow(
                    label: 'Medical History',
                    value: patient.medicalHistory ?? 'None',
                  ),
                  _InfoRow(
                    label: 'PhilHealth',
                    value: patient.philHealthNumber,
                  ),
                  _InfoRow(
                    label: 'Category',
                    value: patient.category?.displayName,
                  ),
                ],
              ),
            ];

            if (!isWide) {
              return Column(
                children: [
                  for (var index = 0; index < panels.length; index++) ...[
                    panels[index],
                    if (index < panels.length - 1) const SizedBox(height: 12),
                  ],
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      panels[0],
                      const SizedBox(height: 12),
                      panels[2],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      panels[1],
                      const SizedBox(height: 12),
                      panels[3],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PatientEditDialog extends ConsumerStatefulWidget {
  final Patient patient;

  const _PatientEditDialog({required this.patient});

  @override
  ConsumerState<_PatientEditDialog> createState() => _PatientEditDialogState();
}

class _PatientEditDialogState extends ConsumerState<_PatientEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _middleInitialController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _streetController;
  late final TextEditingController _zipCodeController;
  late final TextEditingController _contactController;
  late final TextEditingController _emailController;
  late final TextEditingController _emergencyNameController;
  late final TextEditingController _emergencyRelationController;
  late final TextEditingController _emergencyNumberController;
  late final TextEditingController _philHealthController;
  late final TextEditingController _allergiesController;
  late final TextEditingController _medicalHistoryController;

  late String _suffix;
  String? _municipality;
  String? _barangay;
  String? _purok;
  String? _gender;
  String? _civilStatus;
  String? _bloodType;
  DateTime? _dateOfBirth;
  PatientCategory? _category;
  bool _isSaving = false;
  bool _isDirty = false;

  void _markDirty() {
    if (!_isDirty && mounted) {
      setState(() => _isDirty = true);
    }
  }

  Future<void> _handleCancel() async {
    if (!_isDirty || _isSaving) {
      Navigator.of(context).pop(false);
      return;
    }
    final shouldDiscard = await confirmDiscardUnsavedChanges(context);
    if (shouldDiscard && mounted) {
      Navigator.of(context).pop(false);
    }
  }

  List<String> get _suffixItems {
    if (!suffixOptions.contains(_suffix)) {
      return [_suffix, ...suffixOptions];
    }
    return suffixOptions;
  }

  List<String> get _genderItems {
    const defaultGenders = ['male', 'female', 'other'];
    if (_gender != null && !defaultGenders.contains(_gender)) {
      return [_gender!, ...defaultGenders];
    }
    return defaultGenders;
  }

  List<String> get _civilStatusItems {
    const defaultStatuses = [
      'single',
      'married',
      'widowed',
      'separated',
      'live-in',
    ];
    if (_civilStatus != null && !defaultStatuses.contains(_civilStatus)) {
      return [_civilStatus!, ...defaultStatuses];
    }
    return defaultStatuses;
  }

  List<String> get _municipalities {
    final list = municipalityAddressData.keys.toList();
    if (_municipality != null && !list.contains(_municipality)) {
      list.add(_municipality!);
    }
    return list;
  }

  List<String> get _barangays {
    final municipality = _municipality;
    final list = <String>[];
    if (municipality != null &&
        municipalityAddressData.containsKey(municipality)) {
      list.addAll(municipalityAddressData[municipality]!.barangayPuroks.keys);
    }
    if (_barangay != null &&
        _barangay!.isNotEmpty &&
        !list.contains(_barangay)) {
      list.insert(0, _barangay!);
    }
    return list;
  }

  List<String> get _puroks {
    final municipality = _municipality;
    final barangay = _barangay;
    final list = <String>[];
    if (municipality != null &&
        barangay != null &&
        municipalityAddressData.containsKey(municipality) &&
        municipalityAddressData[municipality]!.barangayPuroks.containsKey(
          barangay,
        )) {
      list.addAll(
        municipalityAddressData[municipality]!.barangayPuroks[barangay]!,
      );
    } else {
      list.addAll(defaultPuroks);
    }
    if (_purok != null && _purok!.isNotEmpty && !list.contains(_purok)) {
      list.insert(0, _purok!);
    }
    return list;
  }

  List<String> get _bloodTypes {
    const defaultTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    if (_bloodType != null && !defaultTypes.contains(_bloodType)) {
      return [_bloodType!, ...defaultTypes];
    }
    return defaultTypes;
  }

  @override
  void initState() {
    super.initState();
    final patient = widget.patient;
    _firstNameController = TextEditingController(text: patient.firstName);
    _middleInitialController = TextEditingController(
      text:
          formatMiddleInitial(patient.middleName) ?? (patient.middleName ?? ''),
    );
    _lastNameController = TextEditingController(text: patient.lastName);
    _streetController = TextEditingController(text: patient.address ?? '');
    _zipCodeController = TextEditingController(text: patient.zipCode ?? '');
    _contactController = TextEditingController(
      text: patient.contactNumber ?? '',
    );
    _emailController = TextEditingController(text: patient.email ?? '');
    _emergencyNameController = TextEditingController(
      text: patient.emergencyContactName ?? '',
    );
    _emergencyRelationController = TextEditingController(
      text: patient.emergencyContactRelation ?? '',
    );
    _emergencyNumberController = TextEditingController(
      text: patient.emergencyContactNumber ?? '',
    );
    _philHealthController = TextEditingController(
      text: (patient.philHealthNumber ?? '').replaceAll(RegExp(r'[^0-9]'), ''),
    );
    _allergiesController = TextEditingController(text: patient.allergies ?? '');
    _medicalHistoryController = TextEditingController(
      text: patient.medicalHistory ?? '',
    );

    // Normalize Suffix
    final rawSuffix = patient.suffix?.trim();
    if (rawSuffix != null && rawSuffix.isNotEmpty && rawSuffix != 'None') {
      final match = suffixOptions.firstWhere(
        (opt) => opt.toLowerCase() == rawSuffix.toLowerCase(),
        orElse: () => rawSuffix,
      );
      _suffix = match;
    } else {
      _suffix = 'None';
    }

    // Normalize Municipality (case-insensitive & fallback)
    final rawCity = patient.city?.trim();
    if (rawCity != null && rawCity.isNotEmpty) {
      final match = municipalityAddressData.keys.firstWhere(
        (k) => k.toLowerCase() == rawCity.toLowerCase(),
        orElse: () => rawCity,
      );
      _municipality = match;
    } else {
      _municipality = 'Madrid';
    }

    if (_zipCodeController.text.trim().isEmpty && _municipality != null) {
      _zipCodeController.text =
          municipalityAddressData[_municipality]?.zipCode ?? '';
    }

    // Normalize Barangay
    final rawBarangay = patient.barangay?.trim();
    if (rawBarangay != null && rawBarangay.isNotEmpty) {
      String brgyMatch = rawBarangay;
      if (_municipality != null &&
          municipalityAddressData.containsKey(_municipality)) {
        final stdList =
            municipalityAddressData[_municipality]!.barangayPuroks.keys;
        for (final b in stdList) {
          if (b.toLowerCase() == rawBarangay.toLowerCase()) {
            brgyMatch = b;
            break;
          }
        }
      }
      _barangay = brgyMatch;
    } else {
      _barangay = null;
    }

    // Normalize Purok
    final rawPurok = patient.purokSitio?.trim();
    if (rawPurok != null && rawPurok.isNotEmpty) {
      String purokMatch = rawPurok;
      for (final p in defaultPuroks) {
        if (p.toLowerCase() == rawPurok.toLowerCase()) {
          purokMatch = p;
          break;
        }
      }
      _purok = purokMatch;
    } else {
      _purok = null;
    }

    // Normalize Gender (case-insensitive)
    final rawGender = patient.gender?.trim().toLowerCase();
    if (rawGender == 'male' || rawGender == 'female' || rawGender == 'other') {
      _gender = rawGender;
    } else if (patient.gender != null && patient.gender!.trim().isNotEmpty) {
      _gender = patient.gender!.trim();
    } else {
      _gender = null;
    }

    // Normalize Civil Status (case-insensitive)
    const statusOptions = [
      'single',
      'married',
      'widowed',
      'separated',
      'live-in',
    ];
    final rawCivil = patient.civilStatus?.trim().toLowerCase();
    if (statusOptions.contains(rawCivil)) {
      _civilStatus = rawCivil;
    } else if (patient.civilStatus != null &&
        patient.civilStatus!.trim().isNotEmpty) {
      _civilStatus = patient.civilStatus!.trim();
    } else {
      _civilStatus = null;
    }

    // Normalize Blood Type
    final rawBlood = patient.bloodType?.trim().toUpperCase();
    const defaultBloodTypes = [
      'A+',
      'A-',
      'B+',
      'B-',
      'AB+',
      'AB-',
      'O+',
      'O-',
    ];
    if (rawBlood != null && defaultBloodTypes.contains(rawBlood)) {
      _bloodType = rawBlood;
    } else if (patient.bloodType != null &&
        patient.bloodType!.trim().isNotEmpty) {
      _bloodType = patient.bloodType!.trim();
    } else {
      _bloodType = null;
    }

    _dateOfBirth = patient.dateOfBirth;
    _category =
        patientCategoryFromDateOfBirth(patient.dateOfBirth) ?? patient.category;

    _firstNameController.addListener(_markDirty);
    _middleInitialController.addListener(_markDirty);
    _lastNameController.addListener(_markDirty);
    _streetController.addListener(_markDirty);
    _zipCodeController.addListener(_markDirty);
    _contactController.addListener(_markDirty);
    _emailController.addListener(_markDirty);
    _emergencyNameController.addListener(_markDirty);
    _emergencyRelationController.addListener(_markDirty);
    _emergencyNumberController.addListener(_markDirty);
    _philHealthController.addListener(_markDirty);
    _allergiesController.addListener(_markDirty);
    _medicalHistoryController.addListener(_markDirty);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleInitialController.dispose();
    _lastNameController.dispose();
    _streetController.dispose();
    _zipCodeController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _emergencyNameController.dispose();
    _emergencyRelationController.dispose();
    _emergencyNumberController.dispose();
    _philHealthController.dispose();
    _allergiesController.dispose();
    _medicalHistoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDirty || _isSaving,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleCancel();
      },
      child: AppFormDialog(
        icon: Icons.person_outline,
        title: 'Edit Patient Information',
        subtitle:
            'Update demographics, residential address, emergency contact, and clinical notes',
        maxWidth: 820,
        onClose: _isSaving ? null : _handleCancel,
        isLoading: _isSaving,
        loadingText: 'Saving patient modifications...',
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppFormSection(
                  icon: Icons.badge_outlined,
                  title: 'Personal Information',
                  subtitle: 'Demographics and identification',
                  child: Column(
                    children: [
                      _responsiveRow([
                        AppTextField(
                          controller: _lastNameController,
                          label: 'Last Name (LN)',
                          required: true,
                          validator: (value) => isValidPersonName(value)
                              ? null
                              : 'Enter a valid last name (2-50 letters).',
                          onChanged: (_) => _markDirty(),
                        ),
                        AppTextField(
                          controller: _firstNameController,
                          label: 'First Name (FN)',
                          required: true,
                          validator: (value) => isValidPersonName(value)
                              ? null
                              : 'Enter a valid first name (2-50 letters).',
                          onChanged: (_) => _markDirty(),
                        ),
                        AppTextField(
                          controller: _middleInitialController,
                          label: 'Middle Initial (MI) (e.g., Guerda)',
                          hint: 'e.g. Guerda or G.',
                          onChanged: (_) => _markDirty(),
                        ),
                        AppDropdownField<String>(
                          label: 'Suffix (e.g., Jr., Sr., III)',
                          value: _suffix,
                          items: _suffixItems
                              .map(
                                (s) =>
                                    DropdownMenuItem(value: s, child: Text(s)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() {
                            _suffix = v ?? 'None';
                            _markDirty();
                          }),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      _responsiveRow([
                        AppDropdownField<String>(
                          label: 'Sex / Gender',
                          required: true,
                          value: _gender,
                          items: _genderItems
                              .map(
                                (g) => DropdownMenuItem(
                                  value: g,
                                  child: Text(
                                    g.isEmpty
                                        ? g
                                        : (g[0].toUpperCase() + g.substring(1)),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() {
                            _gender = v;
                            _markDirty();
                          }),
                        ),
                        AppDropdownField<String>(
                          label: 'Civil Status',
                          required: true,
                          value: _civilStatus,
                          items: _civilStatusItems
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(
                                    c == 'live-in'
                                        ? 'Live-in'
                                        : (c.isEmpty
                                              ? c
                                              : (c[0].toUpperCase() +
                                                    c.substring(1))),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() {
                            _civilStatus = v;
                            _markDirty();
                          }),
                        ),
                        AppDatePickerField(
                          label: 'Date of Birth',
                          required: true,
                          selectedDate: _dateOfBirth,
                          showAgeBadge: true,
                          onDateSelected: (date) {
                            setState(() {
                              _dateOfBirth = date;
                              if (date != null) {
                                _category = patientCategoryFromDateOfBirth(
                                  date,
                                );
                              }
                              _markDirty();
                            });
                          },
                        ),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppFormSection(
                  icon: Icons.location_on_outlined,
                  title: 'Residential Address',
                  subtitle: 'Geographical location within Surigao del Sur LGUs',
                  child: Column(
                    children: [
                      _responsiveRow([
                        AppDropdownField<String>(
                          label: 'Municipality',
                          required: true,
                          value: _municipality,
                          items: _municipalities
                              .map(
                                (m) =>
                                    DropdownMenuItem(value: m, child: Text(m)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() {
                            _municipality = v;
                            _barangay = null;
                            _purok = null;
                            _zipCodeController.text =
                                municipalityAddressData[v]?.zipCode ?? '';
                            _markDirty();
                          }),
                        ),
                        AppDropdownField<String>(
                          label: 'Barangay',
                          required: true,
                          value: _barangay,
                          items: _barangays
                              .map(
                                (b) =>
                                    DropdownMenuItem(value: b, child: Text(b)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() {
                            _barangay = v;
                            _purok = null;
                            _markDirty();
                          }),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      _responsiveRow([
                        AppDropdownField<String>(
                          label: 'Purok / Sitio',
                          required: true,
                          value: _purok,
                          items: _puroks
                              .map(
                                (p) =>
                                    DropdownMenuItem(value: p, child: Text(p)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() {
                            _purok = v;
                            _markDirty();
                          }),
                        ),
                        AppTextField(
                          controller: _zipCodeController,
                          label: 'ZIP Code',
                          enabled: false,
                          icon: Icons.pin_drop_outlined,
                        ),
                      ]),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _streetController,
                        label: 'Street / House No. / Landmark',
                        required: true,
                        icon: Icons.home_outlined,
                        validator: (value) => isValidPostalAddress(value)
                            ? null
                            : 'Enter a valid address (3-200 characters).',
                        onChanged: (_) => _markDirty(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppFormSection(
                  icon: Icons.phone_outlined,
                  title: 'Contact Information',
                  subtitle: 'Patient communication channels',
                  child: _responsiveRow([
                    AppPhoneField(
                      controller: _contactController,
                      label: 'Primary Mobile Number',
                      required: false,
                      onChanged: (_) => _markDirty(),
                    ),
                    AppTextField(
                      controller: _emailController,
                      label: 'Email Address (Optional)',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isNotEmpty && !isValidEmailAddress(t)) {
                          return 'Enter a valid email address.';
                        }
                        return null;
                      },
                      onChanged: (_) => _markDirty(),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                AppFormSection(
                  icon: Icons.contact_emergency_outlined,
                  title: 'Emergency Contact',
                  subtitle:
                      'Designated contact person in case of medical crisis',
                  child: Column(
                    children: [
                      _responsiveRow([
                        AppTextField(
                          controller: _emergencyNameController,
                          label: 'Contact Full Name',
                          required: true,
                          icon: Icons.person_outline,
                          onChanged: (_) => _markDirty(),
                        ),
                        AppTextField(
                          controller: _emergencyRelationController,
                          label: 'Relationship',
                          required: true,
                          hint: 'e.g. Spouse, Mother, Guardian',
                          icon: Icons.family_restroom_outlined,
                          onChanged: (_) => _markDirty(),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      AppPhoneField(
                        controller: _emergencyNumberController,
                        label: 'Emergency Mobile Number',
                        required: true,
                        onChanged: (_) => _markDirty(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppFormSection(
                  icon: Icons.medical_information_outlined,
                  title: 'Health & Clinical Profile',
                  subtitle:
                      'Insurance details, blood profile, allergies, and medical history',
                  child: Column(
                    children: [
                      _responsiveRow([
                        AppTextField(
                          controller: _philHealthController,
                          label: 'PhilHealth Identification (12 digits)',
                          hint: 'XX-XXXXXXXXX-X',
                          icon: Icons.credit_card_outlined,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(12),
                          ],
                          validator: (v) {
                            final t = v?.trim() ?? '';
                            if (t.isNotEmpty && t.length != 12) {
                              return 'PhilHealth number must be 12 digits.';
                            }
                            return null;
                          },
                          onChanged: (_) => _markDirty(),
                        ),
                        AppDropdownField<String>(
                          label: 'Blood Type',
                          value: _bloodType,
                          items: _bloodTypes
                              .map(
                                (b) =>
                                    DropdownMenuItem(value: b, child: Text(b)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() {
                            _bloodType = v;
                            _markDirty();
                          }),
                        ),
                        _readOnlyField(
                          label: 'Assigned Category',
                          value: _category?.displayName ?? 'Auto based on age',
                        ),
                      ]),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _allergiesController,
                        label: 'Known Allergies (Drugs, Food, Environmental)',
                        hint: 'List allergies or enter "None Known"',
                        icon: Icons.warning_amber_outlined,
                        maxLines: 2,
                        onChanged: (_) => _markDirty(),
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _medicalHistoryController,
                        label: 'Past Medical History & Chronic Conditions',
                        hint: 'e.g. Hypertension, Type 2 Diabetes, Asthma',
                        icon: Icons.history_outlined,
                        maxLines: 2,
                        onChanged: (_) => _markDirty(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _handleCancel,
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  Widget _responsiveRow(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            children: children
                .map(
                  (child) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: child,
                  ),
                )
                .toList(),
          );
        }
        final rowChildren = <Widget>[];
        for (final child in children) {
          if (rowChildren.isNotEmpty) {
            rowChildren.add(const SizedBox(width: 10));
          }
          rowChildren.add(Expanded(child: child));
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rowChildren,
        );
      },
    );
  }

  Widget _readOnlyField({required String label, required String value}) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      child: Text(value),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final rawContact = _contactController.text.trim();
    final rawEmergency = _emergencyNumberController.text.trim();
    final contactNormalized = normalizePhilippinePhone(rawContact);
    final emergencyNormalized = normalizePhilippinePhone(rawEmergency);

    if (rawContact.isNotEmpty &&
        (contactNormalized.length != 11 ||
            !contactNormalized.startsWith('09'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Patient contact number must contain 11 digits starting with 09 (e.g. 0906-985-6320).',
          ),
        ),
      );
      return;
    }

    if (emergencyNormalized.length != 11 ||
        !emergencyNormalized.startsWith('09')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Emergency contact number must contain 11 digits starting with 09 (e.g. 0906-985-6320).',
          ),
        ),
      );
      return;
    }

    final email = _emailController.text.trim();
    if (email.isNotEmpty && !isValidEmailAddress(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid email address or leave it blank.'),
        ),
      );
      return;
    }

    final philHealthNumber = _philHealthController.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    setState(() => _isSaving = true);

    try {
      final userId = ref.read(currentUserProvider)?.id ?? 'system';
      final clearFields = <String>{
        if (_middleInitialController.text.trim().isEmpty) 'middleName',
        if (_suffix == 'None') 'suffix',
        if (email.isEmpty) 'email',
        if (rawContact.isEmpty) 'contactNumber',
        if (philHealthNumber.isEmpty) 'philHealthNumber',
        if (_bloodType == null) 'bloodType',
        if (_allergiesController.text.trim().isEmpty) 'allergies',
        if (_medicalHistoryController.text.trim().isEmpty) 'medicalHistory',
      };

      await ref
          .read(patientRepositoryProvider)
          .updatePatient(
            id: widget.patient.id,
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            middleName: _middleInitialController.text.trim(),
            suffix: _suffix,
            dateOfBirth: _dateOfBirth ?? widget.patient.dateOfBirth,
            gender: _gender,
            civilStatus: _civilStatus,
            contactNumber: rawContact.isEmpty
                ? null
                : formatPhilippinePhone(contactNormalized),
            email: email.isEmpty ? null : email,
            address: _streetController.text.trim(),
            barangay: _barangay,
            purokSitio: _purok,
            city: _municipality,
            province: widget.patient.province ?? 'Surigao del Sur',
            zipCode: _zipCodeController.text.trim(),
            philHealthNumber: philHealthNumber.isEmpty
                ? null
                : philHealthNumber,
            bloodType: _bloodType,
            emergencyContactName: _emergencyNameController.text.trim(),
            emergencyContactNumber: formatPhilippinePhone(emergencyNormalized),
            emergencyContactRelation: _emergencyRelationController.text.trim(),
            allergies: _allergiesController.text.trim().isEmpty
                ? null
                : _allergiesController.text.trim(),
            medicalHistory: _medicalHistoryController.text.trim().isEmpty
                ? null
                : _medicalHistoryController.text.trim(),
            category: _category,
            clearFields: clearFields,
            userId: userId,
          );

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient information saved successfully')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _SectionPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionPanel({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryEmerald : theme.colorScheme.primary;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.primaryEmeraldSubtle : primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.roundedSm,
                ),
                child: Icon(icon, size: 16, color: primary),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                  color: isDark ? AppColors.textPrimary : null,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final labelWidth = (constraints.maxWidth * 0.4).clamp(96.0, 160.0);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: labelWidth,
                child: Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.62),
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value?.isNotEmpty == true ? value! : 'N/A',
                  softWrap: true,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? AppColors.elevatedSurface : theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: AppRadius.roundedSm,
        border: Border.all(
          color: isDark ? AppColors.border : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: isDark ? AppColors.primaryEmerald : theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.textPrimary : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

String _shortDate(DateTime? date) {
  if (date == null) return 'N/A';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _PatientConsultationsList extends ConsumerWidget {
  final Patient patient;
  final VoidCallback onCreateRecord;

  const _PatientConsultationsList({
    required this.patient,
    required this.onCreateRecord,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final consultationsAsync = ref.watch(
      patientConsultationsProvider(patient.id),
    );

    return consultationsAsync.when(
      data: (consultations) {
        if (consultations.isEmpty) {
          return Center(
            child: AppCard(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 48,
                    color: isDark ? AppColors.textSecondary : Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No clinical records recorded yet',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Create a SOAP consultation record for clinical observations, vitals, and diagnosis.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? AppColors.textSecondary : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark
                          ? AppColors.primaryEmerald
                          : theme.colorScheme.primary,
                      foregroundColor: isDark
                          ? const Color(0xFF080909)
                          : theme.colorScheme.onPrimary,
                    ),
                    onPressed: onCreateRecord,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Create First Clinical Record'),
                  ),
                ],
              ),
            ),
          );
        }

        final sorted = List<Consultation>.from(consultations)
          ..sort((a, b) => (b.consultationDate ?? b.createdAt ?? DateTime.now())
              .compareTo(a.consultationDate ?? a.createdAt ?? DateTime.now()));

        return ListView.separated(
          padding: const EdgeInsets.only(top: 4, bottom: 24),
          itemCount: sorted.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final c = sorted[index];
            final date = c.consultationDate ?? c.createdAt;
            final dateStr =
                date != null ? DateFormat('yyyy-MM-dd').format(date) : 'N/A';

            return AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.primaryEmeraldSubtle
                              : theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isDark
                                ? AppColors.primaryEmerald.withValues(alpha: 0.3)
                                : theme.colorScheme.primary.withValues(
                                    alpha: 0.3,
                                  ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 13,
                              color: isDark
                                  ? AppColors.primaryEmerald
                                  : theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.primaryEmerald
                                    : theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (c.icd10Code != null && c.icd10Code!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.elevatedSurface
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.border
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            'ICD-10: ${c.icd10Code}${c.icd10Description != null ? " - ${c.icd10Description}" : ""}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.textPrimary
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                      if (c.isFollowUp) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.pending.withValues(
                              alpha: 0.15,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Follow-up',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.pending,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (c.assessment != null && c.assessment!.isNotEmpty) ...[
                    Text(
                      'Diagnosis: ${c.assessment}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.textPrimary : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  _buildSoapRow(
                    'Subjective (S)',
                    c.subjective ?? 'None recorded',
                    isDark,
                  ),
                  const SizedBox(height: 6),
                  _buildSoapRow(
                    'Objective (O)',
                    c.objective ?? 'None recorded',
                    isDark,
                  ),
                  const SizedBox(height: 6),
                  _buildSoapRow(
                    'Plan (P)',
                    c.plan ?? 'None recorded',
                    isDark,
                  ),
                  if (c.followUpInstructions != null &&
                      c.followUpInstructions!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _buildSoapRow(
                      'Follow-up Instructions',
                      c.followUpInstructions!,
                      isDark,
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
      loading: () => const LoadingState(),
      error: (e, _) => Center(child: Text('Failed to load clinical records: $e')),
    );
  }

  Widget _buildSoapRow(String title, String content, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textSecondary : Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          child: Text(
            content,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.textPrimary : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}

class _PatientDocumentsList extends ConsumerWidget {
  final Patient patient;
  final VoidCallback onUploadDocument;

  const _PatientDocumentsList({
    required this.patient,
    required this.onUploadDocument,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final docsAsync = ref.watch(patientDocumentsProvider(patient.id));

    return docsAsync.when(
      data: (docs) {
        if (docs.isEmpty) {
          return Center(
            child: AppCard(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_open_outlined,
                    size: 48,
                    color: isDark ? AppColors.textSecondary : Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No documents attached',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Upload lab results, prescriptions, imaging scans, or medical certificates.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? AppColors.textSecondary : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark
                          ? AppColors.primaryEmerald
                          : theme.colorScheme.primary,
                      foregroundColor: isDark
                          ? const Color(0xFF080909)
                          : theme.colorScheme.onPrimary,
                    ),
                    onPressed: onUploadDocument,
                    icon: const Icon(Icons.upload_file_outlined, size: 18),
                    label: const Text('Upload First Document'),
                  ),
                ],
              ),
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;
            return GridView.builder(
              padding: const EdgeInsets.only(top: 4, bottom: 24),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isWide ? 2 : 1,
                mainAxisExtent: 110,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final isImage = (doc.mimeType?.startsWith('image/') ?? false) ||
                    doc.filePath.toLowerCase().endsWith('.png') ||
                    doc.filePath.toLowerCase().endsWith('.jpg') ||
                    doc.filePath.toLowerCase().endsWith('.jpeg');
                final fileSizeKb = (doc.fileSize / 1024).toStringAsFixed(1);
                final docDate = doc.createdAt ?? DateTime.now();

                return InkWell(
                  onTap: () {
                    final currentUser = ref.read(currentUserProvider);
                    DocumentPreviewDialog.show(
                      context,
                      document: doc,
                      patient: patient,
                      canManage: currentUser?.canManageDocuments ?? false,
                      onChanged: (_) {
                        ref.invalidate(patientDocumentsProvider(patient.id));
                      },
                    );
                  },
                  borderRadius: AppRadius.roundedSm,
                  child: AppCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.primaryEmeraldSubtle
                                : theme.colorScheme.primary.withValues(
                                    alpha: 0.1,
                                  ),
                            borderRadius: AppRadius.roundedSm,
                          ),
                          child: Icon(
                            isImage
                                ? Icons.image_outlined
                                : Icons.picture_as_pdf_outlined,
                            color: isDark
                                ? AppColors.primaryEmerald
                                : theme.colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                doc.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppColors.elevatedSurface
                                          : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      doc.typeDisplay,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? AppColors.textSecondary
                                            : Colors.grey[800],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$fileSizeKb KB',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? AppColors.textSecondary
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('yyyy-MM-dd').format(docDate),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark
                                      ? AppColors.textSecondary
                                      : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.visibility_outlined, size: 20),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
      loading: () => const LoadingState(),
      error: (e, _) => Center(child: Text('Failed to load documents: $e')),
    );
  }
}

class _PatientAuditTrailList extends ConsumerWidget {
  final Patient patient;

  const _PatientAuditTrailList({required this.patient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auditLogsAsync = ref.watch(patientAuditLogsProvider(patient.id));

    return auditLogsAsync.when(
      data: (logs) {
        if (logs.isEmpty) {
          return Center(
            child: AppCard(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history_toggle_off,
                    size: 48,
                    color: isDark ? AppColors.textSecondary : Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No audit history yet',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Audit records for creation, edits, documents, and consultations will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? AppColors.textSecondary : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final sorted = List<AuditLog>.from(logs)
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

        return ListView.separated(
          padding: const EdgeInsets.only(top: 4, bottom: 24),
          itemCount: sorted.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final log = sorted[index];
            Color actionColor;
            switch (log.action.name.toLowerCase()) {
              case 'create':
              case 'register':
                actionColor = AppColors.primaryEmerald;
                break;
              case 'update':
              case 'edit':
                actionColor = AppColors.info;
                break;
              case 'delete':
              case 'archive':
                actionColor = AppColors.critical;
                break;
              default:
                actionColor = AppColors.pending;
            }

            final dateStr =
                DateFormat('yyyy-MM-dd HH:mm:ss').format(log.timestamp);

            return AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: actionColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: actionColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          log.action.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: actionColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '[${log.entityType.toUpperCase()}]',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textSecondary
                              : Colors.grey[700],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.textSecondary
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    log.description ?? 'Activity recorded',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.textPrimary : Colors.black87,
                    ),
                  ),
                  if (log.userId.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Actor: ${log.userId}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.textSecondary
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
      loading: () => const LoadingState(),
      error: (e, _) => Center(child: Text('Failed to load audit history: $e')),
    );
  }
}

class _CreateConsultationDialog extends ConsumerStatefulWidget {
  final Patient patient;

  const _CreateConsultationDialog({required this.patient});

  @override
  ConsumerState<_CreateConsultationDialog> createState() =>
      _CreateConsultationDialogState();
}

class _CreateConsultationDialogState
    extends ConsumerState<_CreateConsultationDialog> {
  final _formKey = GlobalKey<FormState>();
  DateTime _consultationDate = DateTime.now();
  late final TextEditingController _subjectiveController;
  late final TextEditingController _objectiveController;
  late final TextEditingController _assessmentController;
  late final TextEditingController _planController;
  late final TextEditingController _icd10Controller;
  late final TextEditingController _icd10DescController;
  late final TextEditingController _followUpNotesController;
  bool _isFollowUp = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _subjectiveController = TextEditingController();
    _objectiveController = TextEditingController();
    _assessmentController = TextEditingController();
    _planController = TextEditingController();
    _icd10Controller = TextEditingController();
    _icd10DescController = TextEditingController();
    _followUpNotesController = TextEditingController();
  }

  @override
  void dispose() {
    _subjectiveController.dispose();
    _objectiveController.dispose();
    _assessmentController.dispose();
    _planController.dispose();
    _icd10Controller.dispose();
    _icd10DescController.dispose();
    _followUpNotesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final currentUser = ref.read(currentUserProvider);
      final userId = currentUser?.id ?? 'system';

      await ref.read(consultationRepositoryProvider).createConsultation(
            patientId: widget.patient.id,
            subjective: _subjectiveController.text.trim(),
            objective: _objectiveController.text.trim(),
            assessment: _assessmentController.text.trim(),
            plan: _planController.text.trim(),
            icd10Code: _icd10Controller.text.trim().isEmpty
                ? 'R69'
                : _icd10Controller.text.trim(),
            icd10Description: _icd10DescController.text.trim().isEmpty
                ? null
                : _icd10DescController.text.trim(),
            consultationDate: _consultationDate,
            isFollowUp: _isFollowUp,
            followUpInstructions: _isFollowUp &&
                    _followUpNotesController.text.trim().isNotEmpty
                ? _followUpNotesController.text.trim()
                : null,
            createdBy: userId,
          );

      ref.invalidate(patientConsultationsProvider(widget.patient.id));
      ref.invalidate(patientAuditLogsProvider(widget.patient.id));

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clinical consultation record created successfully.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save record: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog(
      icon: Icons.note_add_outlined,
      title: 'New Clinical Record (SOAP)',
      subtitle:
          'Add consultation diagnosis, observations, and care plan for ${widget.patient.fullName}',
      maxWidth: 780,
      isLoading: _isSaving,
      loadingText: 'Saving consultation record...',
      onClose: _isSaving ? null : () => Navigator.pop(context),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppDatePickerField(
                label: 'Consultation Date',
                selectedDate: _consultationDate,
                onDateSelected: (d) {
                  if (d != null) setState(() => _consultationDate = d);
                },
              ),
              const SizedBox(height: 16),
              AppFormSection(
                icon: Icons.chat_bubble_outline,
                title: 'Subjective (S)',
                subtitle:
                    'Chief complaint, history of present illness, and symptoms reported by patient',
                child: AppTextField(
                  controller: _subjectiveController,
                  label: 'Subjective Findings / Chief Complaint',
                  hint:
                      'e.g. Patient reports intermittent fever for 3 days accompanied by productive cough.',
                  required: true,
                  maxLines: 3,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Subjective note is required.' : null,
                ),
              ),
              const SizedBox(height: 16),
              AppFormSection(
                icon: Icons.monitor_heart_outlined,
                title: 'Objective (O)',
                subtitle:
                    'Vital signs, physical examination, laboratory or imaging findings',
                child: AppTextField(
                  controller: _objectiveController,
                  label: 'Objective Findings & Vital Signs',
                  hint:
                      'e.g. BP: 120/80 mmHg, HR: 78 bpm, RR: 18 cpm, Temp: 38.2 C. Chest: coarse crackles left base.',
                  required: true,
                  maxLines: 3,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Objective findings are required.' : null,
                ),
              ),
              const SizedBox(height: 16),
              AppFormSection(
                icon: Icons.assignment_outlined,
                title: 'Assessment (A)',
                subtitle:
                    'Clinical impression, primary diagnosis, and ICD-10 classification',
                child: Column(
                  children: [
                    AppTextField(
                      controller: _assessmentController,
                      label: 'Clinical Assessment / Impression',
                      hint: 'e.g. Community-Acquired Pneumonia (Low Risk)',
                      required: true,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Assessment is required.' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: AppTextField(
                            controller: _icd10Controller,
                            label: 'ICD-10 Code',
                            hint: 'e.g. J18.9',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: AppTextField(
                            controller: _icd10DescController,
                            label: 'ICD-10 Description',
                            hint: 'e.g. Pneumonia, unspecified organism',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppFormSection(
                icon: Icons.medication_outlined,
                title: 'Plan (P)',
                subtitle:
                    'Medications prescribed, diagnostic orders, patient education, follow-up',
                child: Column(
                  children: [
                    AppTextField(
                      controller: _planController,
                      label: 'Treatment Plan & Prescriptions',
                      hint:
                          'e.g. Amoxicillin 500mg TID for 7 days. Paracetamol 500mg PRN. Increase oral fluid intake.',
                      required: true,
                      maxLines: 3,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Treatment plan is required.' : null,
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _isFollowUp,
                      title: const Text('Schedule Follow-up Visit'),
                      subtitle: const Text(
                        'Patient requires re-evaluation or monitoring',
                      ),
                      onChanged: (val) =>
                          setState(() => _isFollowUp = val ?? false),
                    ),
                    if (_isFollowUp) ...[
                      const SizedBox(height: 8),
                      AppTextField(
                        controller: _followUpNotesController,
                        label: 'Follow-up Instructions & Return Date',
                        hint:
                            'e.g. Return in 5 days or immediately if dyspnea worsens.',
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _handleSave,
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Save Record'),
        ),
      ],
    );
  }
}

class _PatientAuditHistoryDialog extends ConsumerWidget {
  final Patient patient;

  const _PatientAuditHistoryDialog({required this.patient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auditLogsAsync = ref.watch(patientAuditLogsProvider(patient.id));

    return Dialog(
      backgroundColor:
          isDark ? AppColors.cardSurface : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.roundedLg,
        side: BorderSide(
          color: isDark ? AppColors.border : theme.colorScheme.outlineVariant,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.primaryEmeraldSubtle
                          : theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: AppRadius.roundedSm,
                    ),
                    child: Icon(
                      Icons.history_outlined,
                      color: isDark
                          ? AppColors.primaryEmerald
                          : theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Patient Audit & Activity History',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.textPrimary : null,
                          ),
                        ),
                        Text(
                          '${patient.fullName} (ID: ${patient.id})',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              Expanded(
                child: auditLogsAsync.when(
                  data: (logs) {
                    if (logs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history_toggle_off,
                              size: 48,
                              color: isDark
                                  ? AppColors.textSecondary
                                  : Colors.grey,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No audit records found for this patient.',
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.textSecondary
                                    : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    final sorted = List<AuditLog>.from(logs)
                      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

                    return ListView.separated(
                      itemCount: sorted.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final log = sorted[index];
                        return _buildAuditLogCard(context, log, isDark);
                      },
                    );
                  },
                  loading: () => const LoadingState(),
                  error: (e, _) =>
                      Center(child: Text('Error loading audit log: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuditLogCard(BuildContext context, AuditLog log, bool isDark) {
    Color actionColor;
    switch (log.action.name.toLowerCase()) {
      case 'create':
      case 'register':
        actionColor = AppColors.primaryEmerald;
        break;
      case 'update':
      case 'edit':
        actionColor = AppColors.info;
        break;
      case 'delete':
      case 'archive':
        actionColor = AppColors.critical;
        break;
      default:
        actionColor = AppColors.pending;
    }

    final dateStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(log.timestamp);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.elevatedSurface : Colors.grey.shade50,
        borderRadius: AppRadius.roundedSm,
        border: Border.all(
          color: isDark ? AppColors.border : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: actionColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: actionColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  log.action.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: actionColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (log.entityType.isNotEmpty)
                Text(
                  '[${log.entityType.toUpperCase()}]',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textSecondary : Colors.grey[700],
                  ),
                ),
              const Spacer(),
              Text(
                dateStr,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.textSecondary : Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            log.description ?? 'Activity recorded',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.textPrimary : Colors.black87,
            ),
          ),
          if (log.userId.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Actor: ${log.userId}',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.textSecondary : Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PatientPrintRecordDialog extends ConsumerWidget {
  final Patient patient;

  const _PatientPrintRecordDialog({required this.patient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);
    final settingsAsync = ref.watch(systemSettingsProvider);
    final consultations =
        ref.watch(patientConsultationsProvider(patient.id)).valueOrNull ?? [];
    final documents =
        ref.watch(patientDocumentsProvider(patient.id)).valueOrNull ?? [];

    final settings = settingsAsync.valueOrNull ??
        const SystemSettings(
          clinicName: 'Surigao del Sur Rural Health Unit',
          clinicCode: 'RHU-01',
          clinicAddress: 'Surigao del Sur, Philippines',
          clinicContact: '0906-985-6320',
        );

    return Dialog(
      backgroundColor:
          isDark ? AppColors.cardSurface : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.roundedLg,
        side: BorderSide(
          color: isDark ? AppColors.border : theme.colorScheme.outlineVariant,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 750),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.primaryEmeraldSubtle
                          : theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: AppRadius.roundedSm,
                    ),
                    child: Icon(
                      Icons.print_outlined,
                      color: isDark
                          ? AppColors.primaryEmerald
                          : theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Official Patient Health Summary Record',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.textPrimary : null,
                          ),
                        ),
                        Text(
                          'Comprehensive medical profile, history, consultations, and document registry for ${patient.fullName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: AppRadius.roundedSm,
                  child: PdfPreview(
                    build: (format) =>
                        ReportPdfService().generateIndividualPatientRecordPdf(
                      patient: patient,
                      settings: settings,
                      preparedByName:
                          currentUser?.fullName ?? 'Healthcare Staff',
                      preparedByRole: currentUser?.role.displayName ?? 'Staff',
                      consultations: consultations,
                      documents: documents,
                    ),
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    allowPrinting: true,
                    allowSharing: true,
                    canDebug: false,
                    pdfFileName:
                        'MedSentry_${patient.lastName}_${patient.firstName}_Record.pdf',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
