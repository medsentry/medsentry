import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/patient.dart';
import '../providers/providers.dart';
import '../utils/patient_address_data.dart';
import '../widgets/app_form_dialog.dart';
import '../widgets/layout/responsive_layout.dart';
import '../widgets/loading_state.dart';

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
        return ResponsiveContentContainer(
          child: Column(
            children: [
              _PatientIdentityHeader(
                patient: patient,
                onArchive:
                    currentUser?.canManageArchive == true && !patient.isArchived
                    ? () => _archivePatient(context, ref, patient)
                    : null,
              ),
              Expanded(child: _OverviewTab(patient: patient)),
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

    await ref.read(databaseProvider).archivePatient(patient.id);
    ref.invalidate(patientsProvider);
    ref.invalidate(archivedPatientsProvider);
    ref.invalidate(patientProvider(patient.id));

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${patient.fullName} archived.')));
      context.go('/patients');
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 900;
          final actions = _HeaderActions(onArchive: onArchive);

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PatientIdentity(patient: patient),
                const SizedBox(height: 14),
                actions,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _PatientIdentity(patient: patient)),
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: actions,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PatientIdentity extends StatelessWidget {
  final Patient patient;

  const _PatientIdentity({required this.patient});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.25),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            patient.firstName.isNotEmpty
                ? patient.firstName[0].toUpperCase()
                : '?',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 14),
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

class _HeaderActions extends StatelessWidget {
  final VoidCallback? onArchive;

  const _HeaderActions({this.onArchive});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (onArchive == null) return const SizedBox.shrink();
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: onArchive,
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Archive'),
            ),
          ],
        );
      },
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  final Patient patient;

  const _OverviewTab({required this.patient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: () => _showEditPatientDialog(context, ref, patient),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _confirmDeletePatient(context, ref, patient),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
          ],
        ),
        const SizedBox(height: 8),
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

  Future<void> _showEditPatientDialog(
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

  Future<void> _confirmDeletePatient(
    BuildContext context,
    WidgetRef ref,
    Patient patient,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Information'),
        content: const Text(
          'Are you sure you want to delete this information?',
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

    if (context.mounted) {
      context.go('/patients');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient information deleted')),
      );
    }
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
      text: patient.philHealthNumber ?? '',
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
                          controller: _firstNameController,
                          label: 'First Name',
                          required: true,
                          validator: (value) => isValidPersonName(value)
                              ? null
                              : 'Enter a valid first name (2-50 letters).',
                          onChanged: (_) => _markDirty(),
                        ),
                        AppTextField(
                          controller: _middleInitialController,
                          label: 'Middle Initial',
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z]'),
                            ),
                            LengthLimitingTextInputFormatter(2),
                          ],
                          onChanged: (v) {
                            _formatMiddleInitialInput(v);
                            _markDirty();
                          },
                        ),
                        AppTextField(
                          controller: _lastNameController,
                          label: 'Last Name',
                          required: true,
                          validator: (value) => isValidPersonName(value)
                              ? null
                              : 'Enter a valid last name (2-50 letters).',
                          onChanged: (_) => _markDirty(),
                        ),
                        AppDropdownField<String>(
                          label: 'Suffix',
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

  void _formatMiddleInitialInput(String value) {
    final formatted = formatMiddleInitial(value);
    if (formatted == null || _middleInitialController.text == formatted) return;
    _middleInitialController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
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

    setState(() => _isSaving = true);

    try {
      final userId = ref.read(currentUserProvider)?.id ?? 'system';
      final clearFields = <String>{
        if (_middleInitialController.text.trim().isEmpty) 'middleName',
        if (_suffix == 'None') 'suffix',
        if (email.isEmpty) 'email',
        if (rawContact.isEmpty) 'contactNumber',
        if (_philHealthController.text.trim().isEmpty) 'philHealthNumber',
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
            philHealthNumber: _philHealthController.text.trim().isEmpty
                ? null
                : _philHealthController.text.trim(),
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
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
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
