import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/consultation.dart';
import '../models/document.dart';
import '../models/patient.dart';
import '../models/queue.dart';
import '../providers/providers.dart';
import '../utils/patient_address_data.dart';
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
        final consultationsAsync = ref.watch(
          patientConsultationsProvider(patient.id),
        );
        final documentsAsync = ref.watch(patientDocumentsProvider(patient.id));
        final queueAsync = ref.watch(patientQueueHistoryProvider(patient.id));

        final screenWidth = MediaQuery.of(context).size.width;
        final isNarrow = screenWidth < 900;
        final isVeryNarrow = screenWidth < 500;
        final identityExtent = isNarrow
            ? (isVeryNarrow ? 170.0 : 140.0)
            : 100.0;

        return DefaultTabController(
          length: 4,
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _PatientIdentityHeaderDelegate(
                    extent: identityExtent,
                    patient: patient,
                    onAddToQueue: currentUser?.canManageQueue == true
                        ? () => _showAddToQueueDialog(
                            context: context,
                            ref: ref,
                            patient: patient,
                          )
                        : null,
                    onNewConsultation: currentUser?.canConsult == true
                        ? () => context.push('/queue/${patient.id}/soap')
                        : null,
                    onDocuments: currentUser?.canManageDocuments == true
                        ? () => context.push('/documents')
                        : null,
                    onArchive:
                        currentUser?.canManageArchive == true &&
                            !patient.isArchived
                        ? () => _archivePatient(context, ref, patient)
                        : null,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14.0),
                    child: _PatientMetrics(
                      consultationsCount:
                          consultationsAsync.valueOrNull?.length,
                      documentsCount: documentsAsync.valueOrNull?.length,
                      queueCount: queueAsync.valueOrNull?.length,
                      lastVisitDate: patient.lastVisitDate,
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabBarDelegate(
                    const TabBar(
                      isScrollable: true,
                      tabs: [
                        Tab(icon: Icon(Icons.badge_outlined), text: 'Overview'),
                        Tab(
                          icon: Icon(Icons.medical_services_outlined),
                          text: 'Consultations',
                        ),
                        Tab(
                          icon: Icon(Icons.folder_outlined),
                          text: 'Documents',
                        ),
                        Tab(icon: Icon(Icons.queue_outlined), text: 'Queue'),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              children: [
                _KeepAliveTab(child: _OverviewTab(patient: patient)),
                _KeepAliveTab(
                  child: _ConsultationsTab(
                    consultationsAsync: consultationsAsync,
                  ),
                ),
                _KeepAliveTab(
                  child: _DocumentsTab(documentsAsync: documentsAsync),
                ),
                _KeepAliveTab(child: _QueueHistoryTab(queueAsync: queueAsync)),
              ],
            ),
          ),
        );
      },
      loading: () => const LoadingState(),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Future<void> _showAddToQueueDialog({
    required BuildContext context,
    required WidgetRef ref,
    required Patient patient,
  }) async {
    final purposeController = TextEditingController(
      text: 'General Consultation',
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add to Queue'),
          content: SizedBox(
            width: 420,
            child: TextField(
              controller: purposeController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Purpose of visit',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final purpose = purposeController.text.trim().isEmpty
                    ? 'General Consultation'
                    : purposeController.text.trim();
                await ref
                    .read(queueRepositoryProvider)
                    .addToQueue(patient.id, patient.fullName, purpose);
                ref.invalidate(queueProvider);
                ref.invalidate(patientQueueHistoryProvider(patient.id));
                ref.invalidate(patientAuditLogsProvider(patient.id));
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${patient.fullName} added to queue'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.queue),
              label: const Text('Add'),
            ),
          ],
        );
      },
    );

    purposeController.dispose();
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

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  const _TabBarDelegate(this.tabBar);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: overlapsContent || shrinkOffset > 0 ? 2 : 0,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}

class _PatientIdentityHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Patient patient;
  final VoidCallback? onAddToQueue;
  final VoidCallback? onNewConsultation;
  final VoidCallback? onDocuments;
  final VoidCallback? onArchive;
  final double extent;

  const _PatientIdentityHeaderDelegate({
    required this.patient,
    required this.onAddToQueue,
    required this.onNewConsultation,
    required this.onDocuments,
    this.onArchive,
    required this.extent,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      elevation: overlapsContent || shrinkOffset > 0 ? 4 : 0,
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 900;
            final actions = _HeaderActions(
              onDocuments: onDocuments,
              onAddToQueue: onAddToQueue,
              onNewConsultation: onNewConsultation,
              onArchive: onArchive,
            );

            return Column(
              children: [
                if (isNarrow)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PatientIdentity(patient: patient),
                      const SizedBox(height: 12),
                      actions,
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _PatientIdentity(patient: patient)),
                      const SizedBox(width: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: actions,
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  double get maxExtent => extent;

  @override
  double get minExtent => extent;

  @override
  bool shouldRebuild(covariant _PatientIdentityHeaderDelegate oldDelegate) {
    return patient != oldDelegate.patient || extent != oldDelegate.extent;
  }
}

class _PatientIdentity extends StatelessWidget {
  final Patient patient;

  const _PatientIdentity({required this.patient});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            patient.firstName.isNotEmpty ? patient.firstName[0] : '?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                patient.fullName,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.credit_card,
                    label: 'PHN: ${patient.philHealthNumber ?? 'N/A'}',
                  ),
                  _InfoChip(
                    icon: Icons.cake_outlined,
                    label: '${patient.age ?? 'N/A'} years old',
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
  final VoidCallback? onAddToQueue;
  final VoidCallback? onNewConsultation;
  final VoidCallback? onDocuments;
  final VoidCallback? onArchive;

  const _HeaderActions({
    required this.onAddToQueue,
    required this.onNewConsultation,
    required this.onDocuments,
    this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        if (onArchive != null)
          OutlinedButton.icon(
            onPressed: onArchive,
            icon: const Icon(Icons.archive_outlined),
            label: const Text('Archive'),
          ),
        OutlinedButton.icon(
          onPressed: onDocuments,
          icon: const Icon(Icons.folder_outlined),
          label: const Text('Documents'),
        ),
        OutlinedButton.icon(
          onPressed: onAddToQueue,
          icon: const Icon(Icons.queue),
          label: const Text('Add Queue'),
        ),
        ElevatedButton.icon(
          onPressed: onNewConsultation,
          icon: const Icon(Icons.medical_services_outlined),
          label: const Text('New Consultation'),
        ),
      ],
    );
  }
}

class _PatientMetrics extends StatelessWidget {
  final int? consultationsCount;
  final int? documentsCount;
  final int? queueCount;
  final DateTime? lastVisitDate;

  const _PatientMetrics({
    required this.consultationsCount,
    required this.documentsCount,
    required this.queueCount,
    required this.lastVisitDate,
  });

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _MetricTile(
        label: 'Consultations',
        value: (consultationsCount ?? 0).toString(),
        icon: Icons.medical_services_outlined,
        color: MedSentryColors.green700,
      ),
      _MetricTile(
        label: 'Documents',
        value: (documentsCount ?? 0).toString(),
        icon: Icons.folder_outlined,
        color: const Color(0xFF16A34A),
      ),
      _MetricTile(
        label: 'Queue Visits',
        value: (queueCount ?? 0).toString(),
        icon: Icons.queue_outlined,
        color: const Color(0xFFF59E0B),
      ),
      _MetricTile(
        label: 'Last Visit',
        value: _shortDate(lastVisitDate),
        icon: Icons.event_available_outlined,
        color: MedSentryColors.green800,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? 4
            : constraints.maxWidth >= 420
            ? 2
            : 1;
        final width = (constraints.maxWidth - (10 * (columns - 1))) / columns;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: tiles
              .map(
                (tile) => SizedBox(
                  width: width.isFinite ? width : constraints.maxWidth,
                  child: tile,
                ),
              )
              .toList(),
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
      padding: const EdgeInsets.all(16),
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
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 760;
            final gap = isWide ? 12.0 : 0.0;
            final width = isWide
                ? (constraints.maxWidth - gap) / 2
                : constraints.maxWidth;
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

            return Wrap(
              spacing: gap,
              runSpacing: 12,
              children: panels
                  .map(
                    (panel) => SizedBox(
                      width: width.isFinite ? width : constraints.maxWidth,
                      child: panel,
                    ),
                  )
                  .toList(),
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
    return AlertDialog(
      title: const Text('Edit Patient Information'),
      content: SizedBox(
        width: 760,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _responsiveRow([
                  _textField(
                    _firstNameController,
                    'First Name',
                    required: true,
                  ),
                  _textField(
                    _middleInitialController,
                    'Middle Initial',
                    maxLength: 2,
                    formatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')),
                    ],
                    onChanged: _formatMiddleInitialInput,
                  ),
                  _textField(_lastNameController, 'Last Name', required: true),
                  _dropdown<String>(
                    label: 'Suffix',
                    value: _suffix,
                    items: _suffixItems,
                    onChanged: (value) =>
                        setState(() => _suffix = value ?? 'None'),
                  ),
                ]),
                const SizedBox(height: 12),
                _responsiveRow([
                  _dropdown<String>(
                    label: 'Gender',
                    value: _gender,
                    items: _genderItems,
                    required: true,
                    itemLabel: (v) =>
                        v.isEmpty ? v : (v[0].toUpperCase() + v.substring(1)),
                    onChanged: (value) => setState(() => _gender = value),
                  ),
                  _dropdown<String>(
                    label: 'Civil Status',
                    value: _civilStatus,
                    items: _civilStatusItems,
                    required: true,
                    itemLabel: (v) => v == 'live-in'
                        ? 'Live-in'
                        : (v.isEmpty
                              ? v
                              : (v[0].toUpperCase() + v.substring(1))),
                    onChanged: (value) => setState(() => _civilStatus = value),
                  ),
                  _datePickerField(
                    label: 'Date of Birth',
                    value: _dateOfBirth,
                    onChanged: (date) {
                      setState(() {
                        _dateOfBirth = date;
                        if (date != null) {
                          _category = patientCategoryFromDateOfBirth(date);
                        }
                      });
                    },
                  ),
                ]),
                const Divider(height: 28),
                _responsiveRow([
                  _dropdown<String>(
                    label: 'Municipality',
                    value: _municipality,
                    items: _municipalities,
                    required: true,
                    onChanged: (value) {
                      setState(() {
                        _municipality = value;
                        _barangay = null;
                        _purok = null;
                        _zipCodeController.text =
                            municipalityAddressData[value]?.zipCode ?? '';
                      });
                    },
                  ),
                  _dropdown<String>(
                    label: 'Barangay',
                    value: _barangay,
                    items: _barangays,
                    required: true,
                    onChanged: (value) => setState(() {
                      _barangay = value;
                      _purok = null;
                    }),
                  ),
                ]),
                const SizedBox(height: 12),
                _responsiveRow([
                  _dropdown<String>(
                    label: 'Purok / Sitio',
                    value: _purok,
                    items: _puroks,
                    required: true,
                    onChanged: (value) => setState(() => _purok = value),
                  ),
                  _textField(_zipCodeController, 'ZIP Code', readOnly: true),
                ]),
                const SizedBox(height: 12),
                _textField(
                  _streetController,
                  'Street / House No.',
                  required: true,
                ),
                const Divider(height: 28),
                _responsiveRow([
                  _textField(
                    _contactController,
                    'Contact Number',
                    required: true,
                  ),
                  _textField(_emailController, 'Email Address'),
                ]),
                const SizedBox(height: 12),
                _responsiveRow([
                  _textField(
                    _emergencyNameController,
                    'Emergency Contact',
                    required: true,
                  ),
                  _textField(
                    _emergencyRelationController,
                    'Relationship',
                    required: true,
                  ),
                  _textField(
                    _emergencyNumberController,
                    'Emergency Number',
                    required: true,
                  ),
                ]),
                const Divider(height: 28),
                _responsiveRow([
                  _textField(_philHealthController, 'PhilHealth Number'),
                  _dropdown<String>(
                    label: 'Blood Type',
                    value: _bloodType,
                    items: _bloodTypes,
                    onChanged: (value) => setState(() => _bloodType = value),
                  ),
                  _readOnlyField(
                    label: 'Category',
                    value: _category?.displayName ?? 'Based on age',
                  ),
                ]),
                const SizedBox(height: 12),
                _textField(_allergiesController, 'Allergies', maxLines: 2),
                const SizedBox(height: 12),
                _textField(
                  _medicalHistoryController,
                  'Medical History',
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save'),
        ),
      ],
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

  Widget _textField(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool readOnly = false,
    int? maxLength,
    int maxLines = 1,
    List<TextInputFormatter>? formatters,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      maxLength: maxLength,
      maxLines: maxLines,
      inputFormatters: formatters,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        border: const OutlineInputBorder(),
        counterText: '',
      ),
      validator: required
          ? (value) => value == null || value.trim().isEmpty
                ? '$label is required.'
                : null
          : null,
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    String Function(T value)? itemLabel,
    bool required = false,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: items.contains(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        border: const OutlineInputBorder(),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(
                itemLabel?.call(item) ?? item.toString(),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: required
          ? (value) => value == null ? '$label is required.' : null
          : null,
    );
  }

  Widget _datePickerField({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
  }) {
    final text = value != null
        ? '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}'
        : 'Select Date';
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime(now.year - 20, 1, 1),
          firstDate: DateTime(1900),
          lastDate: now,
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
        ),
        child: Text(text, overflow: TextOverflow.ellipsis),
      ),
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

    final contact = _contactController.text.trim();
    final emergency = _emergencyNumberController.text.trim();
    if (!RegExp(r'^09\d{9}$').hasMatch(contact) ||
        !RegExp(r'^09\d{9}$').hasMatch(emergency)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Contact numbers must start with 09 and contain 11 digits.',
          ),
        ),
      );
      return;
    }

    final email = _emailController.text.trim();
    if (email.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid email address or leave it blank.'),
        ),
      );
      return;
    }

    final userId = ref.read(currentUserProvider)?.id ?? 'system';
    final clearFields = <String>{
      if (_middleInitialController.text.trim().isEmpty) 'middleName',
      if (_suffix == 'None') 'suffix',
      if (email.isEmpty) 'email',
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
          contactNumber: contact,
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
          emergencyContactNumber: emergency,
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Patient information saved')));
  }
}

class _ConsultationsTab extends ConsumerWidget {
  final AsyncValue<List<Consultation>> consultationsAsync;

  const _ConsultationsTab({required this.consultationsAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return consultationsAsync.when(
      skipLoadingOnReload: true,
      data: (consultations) {
        if (consultations.isEmpty) {
          return _EmptyState(
            icon: Icons.medical_services_outlined,
            title: 'No consultations yet',
            message: 'Saved SOAP notes for this patient will appear here.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: consultations.length,
          separatorBuilder: (_, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = consultations[index];
            return _ConsultationCard(
              consultation: item,
              icon: Icons.medical_services_outlined,
              iconColor: const Color(0xFF16A34A),
              title: item.icd10Code?.isNotEmpty == true
                  ? 'Diagnosis: ${item.icd10Code}'
                  : 'SOAP Consultation',
              subtitle: _shortDate(item.consultationDate ?? item.createdAt),
              details: _firstFilled([
                item.assessment,
                item.subjective,
                item.plan,
                'No clinical summary recorded.',
              ]),
              onEdit: () => _editConsultation(context, ref, item),
              onDelete: () => _deleteConsultation(context, ref, item),
            );
          },
        );
      },
      loading: () => const LoadingState(),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Future<void> _editConsultation(
    BuildContext context,
    WidgetRef ref,
    Consultation consultation,
  ) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _ConsultationEditDialog(consultation: consultation),
    );

    if (updated == true) {
      ref.invalidate(patientConsultationsProvider(consultation.patientId));
      ref.invalidate(patientAuditLogsProvider(consultation.patientId));
    }
  }

  Future<void> _deleteConsultation(
    BuildContext context,
    WidgetRef ref,
    Consultation consultation,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Consultation'),
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
    await ref
        .read(consultationRepositoryProvider)
        .deleteConsultation(id: consultation.id, deletedBy: userId);
    ref.invalidate(patientConsultationsProvider(consultation.patientId));
    ref.invalidate(patientAuditLogsProvider(consultation.patientId));

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Consultation deleted')));
    }
  }
}

class _ConsultationEditDialog extends ConsumerStatefulWidget {
  final Consultation consultation;

  const _ConsultationEditDialog({required this.consultation});

  @override
  ConsumerState<_ConsultationEditDialog> createState() =>
      _ConsultationEditDialogState();
}

class _ConsultationEditDialogState
    extends ConsumerState<_ConsultationEditDialog> {
  final _subjectiveController = TextEditingController();
  final _objectiveController = TextEditingController();
  final _assessmentController = TextEditingController();
  final _planController = TextEditingController();
  final _icd10Controller = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final consultation = widget.consultation;
    _subjectiveController.text = consultation.subjective ?? '';
    _objectiveController.text = consultation.objective ?? '';
    _assessmentController.text = consultation.assessment ?? '';
    _planController.text = consultation.plan ?? '';
    _icd10Controller.text = consultation.icd10Code ?? '';
    for (final controller in [
      _subjectiveController,
      _objectiveController,
      _assessmentController,
      _planController,
    ]) {
      controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _subjectiveController,
      _objectiveController,
      _assessmentController,
      _planController,
    ]) {
      controller.removeListener(_refresh);
    }
    _subjectiveController.dispose();
    _objectiveController.dispose();
    _assessmentController.dispose();
    _planController.dispose();
    _icd10Controller.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  bool get _hasSoapContent =>
      _subjectiveController.text.trim().isNotEmpty ||
      _objectiveController.text.trim().isNotEmpty ||
      _assessmentController.text.trim().isNotEmpty ||
      _planController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Consultation'),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _soapField('Subjective', _subjectiveController),
              const SizedBox(height: 12),
              _soapField('Objective', _objectiveController),
              const SizedBox(height: 12),
              _soapField('Assessment', _assessmentController),
              const SizedBox(height: 12),
              _soapField('Plan', _planController),
              const SizedBox(height: 12),
              TextField(
                controller: _icd10Controller,
                decoration: const InputDecoration(
                  labelText: 'ICD-10 Code',
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
          onPressed: !_isSaving && _hasSoapContent ? _save : null,
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

  Widget _soapField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Future<void> _save() async {
    if (!_hasSoapContent) return;

    setState(() => _isSaving = true);
    final userId = ref.read(currentUserProvider)?.id ?? 'system';
    final clearFields = <String>{
      if (_subjectiveController.text.trim().isEmpty) 'subjective',
      if (_objectiveController.text.trim().isEmpty) 'objective',
      if (_assessmentController.text.trim().isEmpty) 'assessment',
      if (_planController.text.trim().isEmpty) 'plan',
      if (_icd10Controller.text.trim().isEmpty) 'icd10Code',
    };

    try {
      await ref
          .read(consultationRepositoryProvider)
          .updateConsultation(
            id: widget.consultation.id,
            subjective: _subjectiveController.text.trim(),
            objective: _objectiveController.text.trim(),
            assessment: _assessmentController.text.trim(),
            plan: _planController.text.trim(),
            icd10Code: _icd10Controller.text.trim(),
            clearFields: clearFields,
            updatedBy: userId,
          );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Consultation saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save consultation: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _DocumentsTab extends StatelessWidget {
  final AsyncValue<List<MedicalDocument>> documentsAsync;

  const _DocumentsTab({required this.documentsAsync});

  @override
  Widget build(BuildContext context) {
    return documentsAsync.when(
      skipLoadingOnReload: true,
      data: (documents) {
        if (documents.isEmpty) {
          return _EmptyState(
            icon: Icons.folder_outlined,
            title: 'No patient documents',
            message:
                'Scanned lab results, referrals, and certificates will appear here.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: documents.length,
          separatorBuilder: (_, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = documents[index];
            return _RecordCard(
              icon: Icons.insert_drive_file_outlined,
              iconColor: MedSentryColors.green800,
              title: item.title,
              subtitle:
                  '${item.typeDisplay} - ${_shortDate(item.scanDate ?? item.createdAt)}',
              details: item.description?.isNotEmpty == true
                  ? item.description!
                  : item.statusDisplay,
            );
          },
        );
      },
      loading: () => const LoadingState(),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }
}

class _QueueHistoryTab extends StatelessWidget {
  final AsyncValue<List<QueueItem>> queueAsync;

  const _QueueHistoryTab({required this.queueAsync});

  @override
  Widget build(BuildContext context) {
    return queueAsync.when(
      skipLoadingOnReload: true,
      data: (items) {
        if (items.isEmpty) {
          return _EmptyState(
            icon: Icons.queue_outlined,
            title: 'No queue history',
            message: 'Queue visits and triage priority will appear here.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = items[index];
            return _RecordCard(
              icon: Icons.queue_outlined,
              iconColor: item.priorityColor,
              title: item.purpose ?? 'General Consultation',
              subtitle:
                  '${item.statusDisplay} - ${item.priorityDisplay} - ${_shortDate(item.arrivalTime)}',
              details: item.vitalsTaken
                  ? 'Vitals recorded. Wait time: ${item.waitTimeDisplay}'
                  : 'Vitals pending. Wait time: ${item.waitTimeDisplay}',
            );
          },
        );
      },
      loading: () => const LoadingState(),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }
}

class _RecordCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String details;

  const _RecordCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: iconColor.withValues(alpha: 0.12),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text(details),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsultationCard extends StatelessWidget {
  final Consultation consultation;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String details;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ConsultationCard({
    required this.consultation,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.details,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: iconColor.withValues(alpha: 0.12),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text(details),
                  if (consultation.updatedAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Updated: ${_formatDateTime(consultation.updatedAt!)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.58),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                IconButton(
                  tooltip: 'Edit',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const Divider(height: 22),
            ...children,
          ],
        ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.62),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(value?.isNotEmpty == true ? value! : 'N/A')),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

String _firstFilled(List<String?> values) {
  for (final value in values) {
    if (value != null && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return 'N/A';
}

String _shortDate(DateTime? date) {
  if (date == null) return 'N/A';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String _formatDateTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${_shortDate(date)} $hour:$minute';
}

class _KeepAliveTab extends StatefulWidget {
  final Widget child;

  const _KeepAliveTab({required this.child});

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
