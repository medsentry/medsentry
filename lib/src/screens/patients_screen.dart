import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/app_notification.dart';
import '../utils/file_exporter/file_exporter.dart';
import '../utils/patient_address_data.dart';
import '../widgets/app_form_dialog.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../widgets/loading_state.dart';
import '../widgets/layout/responsive_layout.dart';
import '../widgets/patient_preview_panel.dart';

class PatientsScreen extends ConsumerStatefulWidget {
  final bool openAddPatient;
  final String? initialSearch;

  /// When set, shows and registers only this facility's patients (used by
  /// the facility page). Otherwise a Super Admin sees every facility,
  /// grouped by facility.
  final String? clinicId;

  const PatientsScreen({
    super.key,
    this.openAddPatient = false,
    this.initialSearch,
    this.clinicId,
  });

  @override
  ConsumerState<PatientsScreen> createState() => _PatientsScreenState();
}

enum _PatientViewMode { list, grid }

enum _PatientSortMode { byLocation, alphabetical }

class _PatientsScreenState extends ConsumerState<PatientsScreen> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';
  String? _barangayFilter;
  String? _purokFilter;
  PatientCategory? _categoryFilter;
  _PatientViewMode _viewMode = _PatientViewMode.list;
  _PatientSortMode _sortMode = _PatientSortMode.byLocation;
  String? _selectedPatientId;

  @override
  void initState() {
    super.initState();
    _applyInitialSearch(widget.initialSearch);
    if (widget.openAddPatient && _canRegisterPatients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showAddPatientDialog(context);
      });
    }
  }

  @override
  void didUpdateWidget(covariant PatientsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSearch != widget.initialSearch) {
      _applyInitialSearch(widget.initialSearch);
    }
    if (!oldWidget.openAddPatient &&
        widget.openAddPatient &&
        _canRegisterPatients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showAddPatientDialog(context);
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _showAddPatientDialog(BuildContext context) {
    if (!_canRegisterPatients) return;

    showDialog(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (context, ref, child) => _PatientRegistrationWizard(
          initialClinicId: widget.clinicId,
          onPatientAdded: () {
            // Refresh the patients list
            ref.invalidate(patientsProvider);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Facility group headers need the clinic names; rebuild when they load,
    // or every group shows as "No facility assigned".
    if (_groupsByFacility) ref.watch(clinicsProvider);
    final query = _searchQuery.trim();
    final patientsAsync = query.isEmpty
        ? ref.watch(patientsProvider)
        : ref.watch(patientSearchProvider(query));
    final canRegisterPatients = _canRegisterPatients;

    return ResponsiveContentContainer(
      child: Column(
        children: [
          Expanded(
            child: patientsAsync.when(
              skipLoadingOnReload: true,
              data: (loadedPatients) {
                final patients = _scopeToClinic(loadedPatients);
                final barangays = _uniqueSorted(
                  patients.map((patient) => patient.barangay),
                );
                final puroks = _uniqueSorted(
                  patients
                      .where(
                        (patient) =>
                            _barangayFilter == null ||
                            patient.barangay == _barangayFilter,
                      )
                      .map((patient) => patient.purokSitio),
                );
                final filteredPatients = _filterPatients(patients);

                final header = _PatientsPageHeader(
                      totalCount: patients.length,
                      filteredCount: filteredPatients.length,
                      barangayCount: barangays.length,
                      onAddPatient: canRegisterPatients
                          ? () => _showAddPatientDialog(context)
                          : null,
                      onExportRegistry: () =>
                          _exportPatientRegistry(filteredPatients),
                    );
                final toolbar = _PatientsToolbar(
                      searchController: _searchController,
                      searchQuery: _searchQuery,
                      barangayFilter: _barangayFilter,
                      purokFilter: _purokFilter,
                      categoryFilter: _categoryFilter,
                      viewMode: _viewMode,
                      sortMode: _sortMode,
                      barangays: barangays,
                      puroks: puroks,
                      onSearchChanged: _onSearchChanged,
                      onClearSearch: () {
                        _searchDebounce?.cancel();
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      onBarangayChanged: (value) => setState(() {
                        _barangayFilter = value;
                        _purokFilter = null;
                      }),
                      onPurokChanged: (value) =>
                          setState(() => _purokFilter = value),
                      onCategoryChanged: (value) =>
                          setState(() => _categoryFilter = value),
                      onViewModeChanged: (value) =>
                          setState(() => _viewMode = value),
                      onSortModeChanged: (value) =>
                          setState(() => _sortMode = value),
                      onClearFilters: _clearFilters,
                    );
                final list = filteredPatients.isEmpty
                    ? _EmptyPatientsState(
                        hasFilters: _hasActiveFilters,
                        onClearFilters: _clearFilters,
                        onAddPatient: canRegisterPatients
                            ? () => _showAddPatientDialog(context)
                            : null,
                      )
                    : _buildMainContent(context, filteredPatients);

                // On phones the header and filters take most of the screen;
                // scroll them away with the list so patients stay visible.
                if (ResponsiveLayout.isMobile(context)) {
                  return NestedScrollView(
                    headerSliverBuilder: (context, _) => [
                      SliverToBoxAdapter(child: header),
                      SliverToBoxAdapter(child: toolbar),
                    ],
                    body: list,
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [header, toolbar, Expanded(child: list)],
                );
              },
              loading: () => const LoadingState(),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Unable to load patients.'),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        if (query.isEmpty) {
                          ref.invalidate(patientsProvider);
                        } else {
                          ref.invalidate(patientSearchProvider(query));
                        }
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _hasActiveFilters =>
      _searchQuery.trim().isNotEmpty ||
      _barangayFilter != null ||
      _purokFilter != null ||
      _categoryFilter != null;

  bool get _canRegisterPatients =>
      ref.read(currentUserProvider)?.canRegisterPatients == true;

  void _applyInitialSearch(String? value) {
    final search = value?.trim() ?? '';
    if (search == _searchQuery) return;
    _searchDebounce?.cancel();
    _searchController.text = search;
    _searchQuery = search;
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() => _searchQuery = '');
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _searchQuery = query);
    });
  }

  void _clearFilters() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _barangayFilter = null;
      _purokFilter = null;
      _categoryFilter = null;
    });
  }

  Future<void> _exportPatientRegistry(List<Patient> patients) async {
    if (patients.isEmpty) {
      AppNotification.warning(
        title: 'Export Registry',
        message: 'No patient records to export with current filters.',
      );
      return;
    }
    try {
      final rows = <String>[
        'Patient ID,Full Name,Gender,Birth Date,Age,Civil Status,Barangay,Purok,Contact Number,PhilHealth Number,Category,PWD',
      ];
      for (final p in patients) {
        final dobStr = p.dateOfBirth != null
            ? DateFormat('yyyy-MM-dd').format(p.dateOfBirth!)
            : '';
        rows.add([
          '"${p.id}"',
          '"${p.fullName.replaceAll('"', '""')}"',
          '"${p.gender ?? ''}"',
          '"$dobStr"',
          '"${p.age ?? ''}"',
          '"${p.civilStatus ?? ''}"',
          '"${p.barangay ?? ''}"',
          '"${p.purokSitio ?? ''}"',
          '"${p.contactNumber ?? ''}"',
          '"${p.philHealthNumber ?? ''}"',
          '"${p.category?.displayName ?? ''}"',
          '"${p.isPwd ? 'Yes' : 'No'}"',
        ].join(','));
      }
      final csvContent = rows.join('\r\n');
      final settings = ref.read(systemSettingsProvider).valueOrNull;
      final clinicPrefix = (settings?.clinicName.isNotEmpty == true
              ? settings!.clinicName
              : 'MedSentry_RHU')
          .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final filename =
          '${clinicPrefix}_Patient_Registry_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
      final path = await createFileExporter().exportTextFile(
        filename: filename,
        content: csvContent,
      );
      if (path.isNotEmpty) {
        await ref.read(auditServiceProvider).logAction(
              action: AuditAction.export,
              entityType: AuditEntityTypes.patient,
              details:
                  'Exported ${patients.length} patient records to CSV ($filename)',
            );
        AppNotification.success(
          title: 'Export Successful',
          message: 'Saved ${patients.length} patient records to $filename',
        );
      }
    } catch (e) {
      AppNotification.error(
        title: 'Export Failed',
        message: 'Could not export patient registry: $e',
      );
    }
  }

  List<String> _uniqueSorted(Iterable<String?> values) {
    final unique =
        values
            .whereType<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return unique;
  }

  List<Patient> _filterPatients(List<Patient> patients) {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = patients.where((patient) {
      final matchesSearch =
          query.isEmpty ||
          patient.fullName.toLowerCase().contains(query) ||
          patient.id.toLowerCase().contains(query) ||
          (patient.localLguIdNumber?.toLowerCase().contains(query) ?? false) ||
          (patient.philHealthNumber?.toLowerCase().contains(query) ?? false) ||
          (patient.contactNumber?.toLowerCase().contains(query) ?? false) ||
          (patient.barangay?.toLowerCase().contains(query) ?? false) ||
          (patient.purokSitio?.toLowerCase().contains(query) ?? false);
      final matchesBarangay =
          _barangayFilter == null || patient.barangay == _barangayFilter;
      final matchesPurok =
          _purokFilter == null || patient.purokSitio == _purokFilter;
      final matchesCategory =
          _categoryFilter == null || patient.category == _categoryFilter;

      return matchesSearch &&
          matchesBarangay &&
          matchesPurok &&
          matchesCategory;
    }).toList();

    filtered.sort((a, b) {
      final barangayCompare = _locationLabel(
        a.barangay,
        'Unassigned Barangay',
      ).compareTo(_locationLabel(b.barangay, 'Unassigned Barangay'));
      if (barangayCompare != 0) return barangayCompare;
      final purokCompare = _locationLabel(
        a.purokSitio,
        'Unassigned Purok',
      ).compareTo(_locationLabel(b.purokSitio, 'Unassigned Purok'));
      if (purokCompare != 0) return purokCompare;
      return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
    });

    return filtered;
  }

  /// A Super Admin viewing every facility sees patients grouped by facility,
  /// then barangay; everyone else groups by barangay, then purok.
  bool get _groupsByFacility =>
      widget.clinicId == null &&
      ref.read(currentUserProvider)?.isSuperAdmin == true;

  String _facilityName(String? clinicId) {
    final clinics = ref.read(clinicsProvider).valueOrNull ?? const <Clinic>[];
    for (final clinic in clinics) {
      if (clinic.id == clinicId) return clinic.name;
    }
    return 'No facility assigned';
  }

  List<Patient> _scopeToClinic(List<Patient> patients) {
    final clinicId = widget.clinicId;
    if (clinicId == null) return patients;
    return patients.where((patient) => patient.clinicId == clinicId).toList();
  }

  Map<String, Map<String, List<Patient>>> _groupPatients(
    List<Patient> patients,
  ) {
    final grouped = <String, Map<String, List<Patient>>>{};
    if (_groupsByFacility) {
      for (final patient in patients) {
        final facility = _facilityName(patient.clinicId);
        final barangay = _locationLabel(
          patient.barangay,
          'Unassigned Barangay',
        );
        grouped.putIfAbsent(facility, () => <String, List<Patient>>{});
        grouped[facility]!.putIfAbsent(barangay, () => <Patient>[]);
        grouped[facility]![barangay]!.add(patient);
      }
      return grouped;
    }
    for (final patient in patients) {
      final barangay = _locationLabel(patient.barangay, 'Unassigned Barangay');
      final purok = _locationLabel(patient.purokSitio, 'Unassigned Purok');
      grouped.putIfAbsent(barangay, () => <String, List<Patient>>{});
      grouped[barangay]!.putIfAbsent(purok, () => <Patient>[]);
      grouped[barangay]![purok]!.add(patient);
    }
    return grouped;
  }

  Widget _buildMainContent(
    BuildContext context,
    List<Patient> filteredPatients,
  ) {
    final isWide = MediaQuery.sizeOf(context).width >= 1100;
    Patient? selectedPatient;
    if (_selectedPatientId != null) {
      for (final p in filteredPatients) {
        if (p.id == _selectedPatientId) {
          selectedPatient = p;
          break;
        }
      }
    }

    final contentView = _PatientsContentView(
      patients: filteredPatients,
      groupedPatients: _groupPatients(filteredPatients),
      groupsByFacility: _groupsByFacility,
      viewMode: _viewMode,
      sortMode: _sortMode,
      selectedPatientId: selectedPatient?.id,
      onPatientTap: _handlePatientTap,
    );

    if (!isWide || selectedPatient == null) {
      return contentView;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: contentView),
        const SizedBox(width: 12),
        SizedBox(
          width: 380,
          child: Card(
            margin: const EdgeInsets.only(bottom: 18),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: Stack(
              children: [
                PatientPreviewPanel(
                  patient: selectedPatient,
                  onOpenRecord: () =>
                      context.push('/patients/${selectedPatient!.id}'),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close preview',
                    onPressed: () =>
                        setState(() => _selectedPatientId = null),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _handlePatientTap(Patient patient) {
    final isWide = MediaQuery.sizeOf(context).width >= 1100;
    if (isWide) {
      setState(() {
        _selectedPatientId =
            (_selectedPatientId == patient.id) ? null : patient.id;
      });
    } else {
      context.push('/patients/${patient.id}');
    }
  }
}

class _PatientsPageHeader extends StatelessWidget {
  final int totalCount;
  final int filteredCount;
  final int barangayCount;
  final VoidCallback? onAddPatient;
  final VoidCallback? onExportRegistry;

  const _PatientsPageHeader({
    required this.totalCount,
    required this.filteredCount,
    required this.barangayCount,
    this.onAddPatient,
    this.onExportRegistry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardSurface : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark
                    ? AppColors.borderSubtle
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 620;

                final titleSection = Row(
                  children: [
                    Icon(
                      Icons.people_alt_outlined,
                      size: 22,
                      color: isDark
                          ? AppColors.textSecondary
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Patient Registry',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                              color: isDark
                                  ? AppColors.textPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Search, filter, and open clinical records across RHU barangays',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.textSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final exportButton = onExportRegistry != null
                    ? OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          side: BorderSide(
                            color: isDark
                                ? AppColors.borderSubtle
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                        onPressed: onExportRegistry,
                        icon: const Icon(Icons.file_download_outlined, size: 15),
                        label: const Text(
                          'Export CSV',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      )
                    : null;

                final registerButton = onAddPatient != null
                    ? FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryEmerald,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: onAddPatient,
                        icon: const Icon(Icons.person_add_alt_1, size: 15),
                        label: const Text(
                          'Register Patient',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      )
                    : null;

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleSection,
                      if (exportButton != null || registerButton != null) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ?exportButton,
                            ?registerButton,
                          ],
                        ),
                      ],
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: titleSection),
                    if (exportButton != null) ...[
                      exportButton,
                      const SizedBox(width: 8),
                    ],
                    if (registerButton != null) ...[
                      registerButton,
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardSurface : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark
                    ? AppColors.borderSubtle
                    : const Color(0xFFE2E8F0),
              ),
            ),
            // Wraps onto a second line on phones instead of overflowing.
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 4,
              children: [
                Icon(
                  Icons.query_stats_rounded,
                  size: 15,
                  color: isDark
                      ? AppColors.textTertiary
                      : const Color(0xFF64748B),
                ),
                const SizedBox(width: 8),
                Text(
                  '$totalCount registered patients',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: isDark
                        ? AppColors.textPrimary
                        : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  ' · ',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textTertiary
                        : AppColors.lightTextMuted,
                  ),
                ),
                Text(
                  '$barangayCount barangays',
                  style: TextStyle(
                    fontSize: 12,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: isDark
                        ? AppColors.textSecondary
                        : const Color(0xFF64748B),
                  ),
                ),
                Text(
                  ' · ',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textTertiary
                        : AppColors.lightTextMuted,
                  ),
                ),
                Text(
                  '$filteredCount records showing',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: isDark
                        ? AppColors.primaryEmerald
                        : const Color(0xFF0F766E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _PatientsToolbar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final String? barangayFilter;
  final String? purokFilter;
  final PatientCategory? categoryFilter;
  final _PatientViewMode viewMode;
  final _PatientSortMode sortMode;
  final List<String> barangays;
  final List<String> puroks;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<String?> onBarangayChanged;
  final ValueChanged<String?> onPurokChanged;
  final ValueChanged<PatientCategory?> onCategoryChanged;
  final ValueChanged<_PatientViewMode> onViewModeChanged;
  final ValueChanged<_PatientSortMode> onSortModeChanged;
  final VoidCallback onClearFilters;

  const _PatientsToolbar({
    required this.searchController,
    required this.searchQuery,
    required this.barangayFilter,
    required this.purokFilter,
    required this.categoryFilter,
    required this.viewMode,
    required this.sortMode,
    required this.barangays,
    required this.puroks,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onBarangayChanged,
    required this.onPurokChanged,
    required this.onCategoryChanged,
    required this.onViewModeChanged,
    required this.onSortModeChanged,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final hasFilters =
        searchQuery.trim().isNotEmpty ||
        barangayFilter != null ||
        purokFilter != null ||
        categoryFilter != null;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 11,
              ),
              hintText: 'Search by patient name, PhilHealth number, ID, or contact...',
              hintStyle: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.textTertiary : AppColors.lightTextMuted,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 18,
                color: isDark ? AppColors.textTertiary : const Color(0xFF64748B),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: onClearSearch,
                    )
                  : null,
              filled: true,
              fillColor: isDark ? AppColors.inputSurface : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDark
                      ? AppColors.borderSubtle
                      : const Color(0xFFCBD5E1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDark
                      ? AppColors.borderSubtle
                      : const Color(0xFFCBD5E1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppColors.primaryEmerald,
                  width: 1.5,
                ),
              ),
            ),
            onChanged: onSearchChanged,
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final isVeryNarrow = width < 420;
              final isNarrow = width < 600;
              final dropdownWidth = isVeryNarrow
                  ? width
                  : isNarrow
                      ? (width - 8) / 2
                      : 180.0;

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: dropdownWidth,
                    child: _FilterDropdown<String>(
                      label: 'Barangay',
                      value: barangayFilter,
                      items: barangays,
                      itemLabel: (value) => value,
                      onChanged: onBarangayChanged,
                    ),
                  ),
                  SizedBox(
                    width: dropdownWidth,
                    child: _FilterDropdown<String>(
                      label: 'Purok',
                      value: purokFilter,
                      items: puroks,
                      itemLabel: (value) => value,
                      onChanged: onPurokChanged,
                    ),
                  ),
                  SizedBox(
                    width: dropdownWidth,
                    child: _FilterDropdown<PatientCategory>(
                      label: 'Category',
                      value: categoryFilter,
                      items: PatientCategory.values,
                      itemLabel: (value) => value.displayName,
                      onChanged: onCategoryChanged,
                    ),
                  ),
                  if (hasFilters)
                    ActionChip(
                      avatar: const Icon(
                        Icons.filter_alt_off_outlined,
                        size: 15,
                        color: AppColors.primaryEmerald,
                      ),
                      label: const Text(
                        'Clear filters',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      side: BorderSide(
                        color: isDark
                            ? AppColors.borderSubtle
                            : const Color(0xFFCBD5E1),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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
              SegmentedButton<_PatientSortMode>(
                style: ButtonStyle(
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                segments: const [
                  ButtonSegment(
                    value: _PatientSortMode.byLocation,
                    icon: Icon(Icons.map_outlined, size: 15),
                    label: Text('By Barangay', style: TextStyle(fontSize: 12)),
                  ),
                  ButtonSegment(
                    value: _PatientSortMode.alphabetical,
                    icon: Icon(Icons.sort_by_alpha, size: 15),
                    label: Text('A–Z', style: TextStyle(fontSize: 12)),
                  ),
                ],
                selected: {sortMode},
                onSelectionChanged: (value) => onSortModeChanged(value.first),
              ),
              SegmentedButton<_PatientViewMode>(
                style: ButtonStyle(
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                segments: const [
                  ButtonSegment(
                    value: _PatientViewMode.list,
                    icon: Icon(Icons.view_list_outlined, size: 15),
                    label: Text('List', style: TextStyle(fontSize: 12)),
                  ),
                  ButtonSegment(
                    value: _PatientViewMode.grid,
                    icon: Icon(Icons.grid_view_outlined, size: 15),
                    label: Text('Grid', style: TextStyle(fontSize: 12)),
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

class _FilterDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T value) itemLabel;
  final ValueChanged<T?> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final safeValue = (value != null && items.contains(value)) ? value : null;

    return DropdownButtonFormField<T?>(
      initialValue: safeValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 12.5,
          color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
        ),
        isDense: true,
        filled: true,
        fillColor: isDark ? AppColors.inputSurface : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDark ? AppColors.borderSubtle : const Color(0xFFCBD5E1),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDark ? AppColors.borderSubtle : const Color(0xFFCBD5E1),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AppColors.primaryEmerald,
            width: 1.5,
          ),
        ),
      ),
      items: [
        DropdownMenuItem<T?>(
          value: null,
          child: Text('All $label', style: const TextStyle(fontSize: 12)),
        ),
        ...items.map(
          (item) => DropdownMenuItem<T?>(
            value: item,
            child: Text(
              itemLabel(item),
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class _PatientsContentView extends StatelessWidget {
  final List<Patient> patients;
  final Map<String, Map<String, List<Patient>>> groupedPatients;

  /// True when the top-level groups are facilities rather than barangays.
  final bool groupsByFacility;
  final _PatientViewMode viewMode;
  final _PatientSortMode sortMode;
  final String? selectedPatientId;
  final ValueChanged<Patient> onPatientTap;

  const _PatientsContentView({
    required this.patients,
    required this.groupedPatients,
    this.groupsByFacility = false,
    required this.viewMode,
    required this.sortMode,
    this.selectedPatientId,
    required this.onPatientTap,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = _sortedPatients();

    if (viewMode == _PatientViewMode.grid) {
      return _PatientsGridView(
        patients: sorted,
        selectedPatientId: selectedPatientId,
        onPatientTap: onPatientTap,
      );
    }

    if (sortMode == _PatientSortMode.alphabetical) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
        itemCount: sorted.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final patient = sorted[index];
          return _PatientListTile(
            patient: patient,
            showLocation: true,
            isSelected: selectedPatientId == patient.id,
            onTap: () => onPatientTap(patient),
          );
        },
      );
    }

    final barangayEntries = groupedPatients.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      itemCount: barangayEntries.length,
      itemBuilder: (context, index) {
        final entry = barangayEntries[index];
        final sectionPatients =
            entry.value.values.expand((list) => list).toList()..sort(
              (a, b) =>
                  a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
            );

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BarangaySectionHeader(
                barangay: entry.key,
                patientCount: sectionPatients.length,
                icon: groupsByFacility
                    ? Icons.local_hospital_outlined
                    : Icons.holiday_village_outlined,
              ),
              const SizedBox(height: 8),
              ...sectionPatients.map(
                (patient) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PatientListTile(
                    patient: patient,
                    showLocation: true,
                    isSelected: selectedPatientId == patient.id,
                    onTap: () => onPatientTap(patient),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Patient> _sortedPatients() {
    if (sortMode == _PatientSortMode.byLocation) {
      return List<Patient>.from(patients);
    }
    final sorted = List<Patient>.from(patients)
      ..sort(
        (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
      );
    return sorted;
  }
}

class _BarangaySectionHeader extends StatelessWidget {
  final String barangay;
  final int patientCount;
  final IconData icon;

  const _BarangaySectionHeader({
    required this.barangay,
    required this.patientCount,
    this.icon = Icons.holiday_village_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryEmerald : Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.elevatedSurface : primary.withValues(alpha: 0.08),
        borderRadius: AppRadius.roundedSm,
        border: Border.all(
          color: isDark ? AppColors.border : primary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              barangay,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textPrimary : null,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? AppColors.primaryEmeraldSubtle : primary.withValues(alpha: 0.1),
              borderRadius: AppRadius.roundedSm,
            ),
            child: Text(
              '$patientCount',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientsGridView extends StatelessWidget {
  final List<Patient> patients;
  final String? selectedPatientId;
  final ValueChanged<Patient> onPatientTap;

  const _PatientsGridView({
    required this.patients,
    this.selectedPatientId,
    required this.onPatientTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1180
            ? 4
            : constraints.maxWidth >= 860
            ? 3
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        final width = (constraints.maxWidth - (12 * (columns - 1))) / columns;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: patients
                  .map(
                    (patient) => SizedBox(
                      width: width,
                      child: _PatientGridCard(
                        patient: patient,
                        isSelected: selectedPatientId == patient.id,
                        onTap: () => onPatientTap(patient),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyPatientsState extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback? onClearFilters;
  final VoidCallback? onAddPatient;

  const _EmptyPatientsState({
    required this.hasFilters,
    this.onClearFilters,
    this.onAddPatient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Container(
        padding: const EdgeInsets.all(28),
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardSurface : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? AppColors.borderSubtle : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasFilters ? Icons.search_off_rounded : Icons.people_outline_rounded,
              size: 38,
              color: isDark ? AppColors.textTertiary : const Color(0xFF94A3B8),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters ? 'No Matching Records' : 'No Patients Registered',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasFilters
                  ? 'No patient records match your active search and filters. Clear filters or adjust query.'
                  : 'Start building the RHU patient cohort by registering the first patient record.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            if (hasFilters && onClearFilters != null)
              OutlinedButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 15),
                label: const Text('Clear All Filters', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  side: BorderSide(
                    color: isDark ? AppColors.borderSubtle : const Color(0xFFCBD5E1),
                  ),
                ),
              )
            else if (onAddPatient != null)
              FilledButton.icon(
                onPressed: onAddPatient,
                icon: const Icon(Icons.person_add_alt_1, size: 15),
                label: const Text(
                  'Register New Patient',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryEmerald,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PatientRegistrationDialog extends ConsumerStatefulWidget {
  final VoidCallback onPatientAdded;

  /// Pre-selects the RHU (for example when registering from a facility
  /// page), so a Super Admin is not asked to choose it.
  final String? initialClinicId;

  const PatientRegistrationDialog({
    super.key,
    required this.onPatientAdded,
    this.initialClinicId,
  });

  @override
  ConsumerState<PatientRegistrationDialog> createState() =>
      _PatientRegistrationDialogState();
}

typedef _PatientRegistrationWizard = PatientRegistrationDialog;

class _PatientRegistrationDialogState
    extends ConsumerState<PatientRegistrationDialog> {
  bool _showValidationErrors = false;
  bool _isSubmitting = false;

  /// Super Admins have no clinic of their own, so they must choose the RHU a
  /// patient belongs to. A patient without a clinic can never be uploaded and
  /// would appear under every RHU.
  late String? _assignedClinicId = widget.initialClinicId;

  bool get _needsClinicChoice =>
      widget.initialClinicId == null &&
      ref.read(currentUserProvider)?.isSuperAdmin == true;

  static const List<String> _commonAllergies = [
    'Penicillin',
    'Amoxicillin',
    'Aspirin / NSAIDs',
    'Sulfa Drugs',
    'Seafood',
    'Iodine',
    'Latex',
    'No Known Allergies (NKDA)',
  ];

  void _toggleAllergy(String allergy) {
    final current = _allergiesController.text.trim();
    if (allergy == 'No Known Allergies (NKDA)') {
      setState(() => _allergiesController.text = 'NKDA');
      return;
    }
    final list = current.isEmpty
        ? <String>[]
        : current
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty && s != 'NKDA')
            .toList();

    if (list.contains(allergy)) {
      list.remove(allergy);
    } else {
      list.add(allergy);
    }
    setState(() {
      _allergiesController.text = list.join(', ');
    });
  }

  // Step 1: Personal Information
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  String _suffix = 'None';
  DateTime? _dateOfBirth;
  String? _gender;
  String? _civilStatus;
  int? _calculatedAge;

  // Step 2: Contact Information
  final _streetController = TextEditingController();
  final _purokController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _emailController = TextEditingController();

  final _mobileFormatter = MaskTextInputFormatter(
    mask: '09##-###-####',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  // Address dropdowns
  final String _selectedRegion = 'Caraga (Region XIII)';
  final String _selectedProvince = 'Surigao del Sur';
  String? _selectedCity;
  String? _selectedBarangay;
  String? _selectedPurok;

  // Step 3: Emergency Contact
  final _emergencyNameController = TextEditingController();
  final _emergencyRelationController = TextEditingController();
  final _emergencyContactController = TextEditingController();

  // Step 4: Medical & Administrative
  final _philHealthController = TextEditingController();
  final _philHealthFormatter = MaskTextInputFormatter(
    mask: '##-#########-#',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );
  String? _bloodType;
  String? _patientCategory;
  final _occupationController = TextEditingController();
  bool _isPwd = false;
  final _allergiesController = TextEditingController();
  final _medicalHistoryController = TextEditingController();

  List<String> get _municipalities => municipalityAddressData.keys.toList();

  List<String> get _barangays {
    final municipality = _selectedCity;
    if (municipality == null) return const [];
    return municipalityAddressData[municipality]?.barangayPuroks.keys
            .toList() ??
        const [];
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleNameController.dispose();
    _streetController.dispose();
    _purokController.dispose();
    _zipCodeController.dispose();
    _contactNumberController.dispose();
    _emailController.dispose();
    _emergencyNameController.dispose();
    _emergencyRelationController.dispose();
    _emergencyContactController.dispose();
    _philHealthController.dispose();
    _occupationController.dispose();
    _allergiesController.dispose();
    _medicalHistoryController.dispose();
    super.dispose();
  }

  // Calculate age from date of birth
  void _calculateAgeAndCategory() {
    if (_dateOfBirth != null) {
      final now = DateTime.now();
      int age = now.year - _dateOfBirth!.year;
      if (now.month < _dateOfBirth!.month ||
          (now.month == _dateOfBirth!.month && now.day < _dateOfBirth!.day)) {
        age--;
      }

      setState(() {
        _calculatedAge = age;

        _patientCategory = patientCategoryFromAge(age).name;
      });
    }
  }

  bool _isFormValid() {
    return isValidPersonName(_firstNameController.text) &&
        isValidPersonName(_lastNameController.text) &&
        _dateOfBirth != null &&
        _gender != null &&
        _civilStatus != null &&
        (_streetController.text.trim().isEmpty ||
            isValidPostalAddress(_streetController.text)) &&
        _selectedBarangay != null &&
        _selectedPurok != null &&
        _selectedCity != null &&
        _zipCodeController.text.trim().isNotEmpty &&
        _isValidOptionalMobile(_contactNumberController.text) &&
        _isValidOptionalEmail(_emailController.text) &&
        isValidPersonName(_emergencyNameController.text) &&
        _emergencyRelationController.text.trim().isNotEmpty &&
        _isValidMobile(_emergencyContactController.text) &&
        _isValidOptionalPhilHealth(_philHealthController.text);
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    try {
      if (!_isFormValid()) {
        setState(() => _showValidationErrors = true);
        final validationMessage = _validateBeforeSubmit();
        if (validationMessage != null) {
          AppNotification.warning(
            title: 'Incomplete Registration',
            message: validationMessage,
          );
        }
        return;
      }

      setState(() => _isSubmitting = true);

      final repository = ref.read(patientRepositoryProvider);
      final currentUser = ref.read(currentUserProvider);
      final duplicateMessage = _findPossibleDuplicate();
      final validationMessage = _validateBeforeSubmit();

      if (validationMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(validationMessage)));
        return;
      }

      if (duplicateMessage != null) {
        final shouldContinue = await _confirmPossibleDuplicate(
          duplicateMessage,
        );
        if (!shouldContinue) return;
      }

      await repository.createPatient(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        middleName: _middleNameController.text.trim().isNotEmpty
            ? _middleNameController.text.trim()
            : null,
        suffix: _suffix,
        dateOfBirth: _dateOfBirth,
        gender: _gender,
        civilStatus: _civilStatus,
        contactNumber: _contactNumberController.text.trim().isEmpty
            ? null
            : formatPhilippinePhone(_contactNumberController.text.trim()),
        email: _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
        address: _streetController.text.trim(),
        barangay: _selectedBarangay,
        purokSitio: _selectedPurok,
        city: _selectedCity,
        province: _selectedProvince,
        zipCode: _zipCodeController.text.trim().isNotEmpty
            ? _zipCodeController.text.trim()
            : null,
        philHealthNumber: _philHealthController.text.trim().isNotEmpty
            ? _philHealthController.text.trim()
            : null,
        bloodType: _bloodType,
        emergencyContactName: _emergencyNameController.text.trim(),
        emergencyContactNumber: formatPhilippinePhone(
          _emergencyContactController.text.trim(),
        ),
        emergencyContactRelation:
            _emergencyRelationController.text.trim().isNotEmpty
            ? _emergencyRelationController.text.trim()
            : null,
        allergies: _allergiesController.text.trim().isNotEmpty
            ? _allergiesController.text.trim()
            : null,
        occupation: _occupationController.text.trim().isNotEmpty
            ? _occupationController.text.trim()
            : null,
        isPwd: _isPwd,
        medicalHistory: _medicalHistoryController.text.trim().isNotEmpty
            ? _medicalHistoryController.text.trim()
            : null,
        category: patientCategoryFromDateOfBirth(_dateOfBirth),
        userId: currentUser?.id ?? 'system',
        clinicId: currentUser?.clinicId ?? _assignedClinicId,
      );

      // Notify parent to refresh list
      widget.onPatientAdded();

      if (mounted) {
        Navigator.pop(context);
        AppNotification.success(
          title: 'Registration Successful',
          message: 'Patient registered successfully.',
        );
      }
    } catch (e) {
      AppNotification.error(
        title: 'Registration Error',
        message: 'Failed to save patient: $e',
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String? _findPossibleDuplicate() {
    final existingPatients = ref.read(patientsProvider).valueOrNull ?? [];
    final firstName = _normalize(_firstNameController.text);
    final lastName = _normalize(_lastNameController.text);
    final contact = _digitsOnly(_contactNumberController.text);
    final philHealth = _digitsOnly(_philHealthController.text);

    for (final patient in existingPatients) {
      final samePhilHealth =
          philHealth.isNotEmpty &&
          _digitsOnly(patient.philHealthNumber ?? '') == philHealth;
      final sameContact =
          contact.isNotEmpty &&
          _digitsOnly(patient.contactNumber ?? '') == contact;
      final sameNameAndBirthdate =
          _normalize(patient.firstName) == firstName &&
          _normalize(patient.lastName) == lastName &&
          patient.dateOfBirth != null &&
          _dateOfBirth != null &&
          _isSameDate(patient.dateOfBirth!, _dateOfBirth!);

      if (samePhilHealth) {
        return 'A patient with the same PhilHealth number already exists: ${patient.fullName}.';
      }
      if (sameNameAndBirthdate) {
        return 'A patient with the same name and birth date already exists: ${patient.fullName}.';
      }
      if (sameContact) {
        return 'A patient with the same contact number already exists: ${patient.fullName}.';
      }
    }

    return null;
  }

  Future<bool> _confirmPossibleDuplicate(String message) async {
    return AppConfirmDialog.show(
      context,
      title: 'Possible Duplicate Patient',
      message:
          '$message\n\nReview the existing record before creating another patient profile.',
      confirmLabel: 'Create Anyway',
      cancelLabel: 'Review',
      isDestructive: false,
      icon: Icons.person_search_outlined,
      type: ConfirmDialogType.warning,
    );
  }

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  bool get _canDecreasePurokNumber {
    final match = RegExp(
      r'^(.*?)(\d+)$',
    ).firstMatch(_purokController.text.trim());
    final number = int.tryParse(match?.group(2) ?? '');
    return number != null && number > 1;
  }

  void _adjustPurokNumber(int adjustment) {
    final current = _purokController.text.trim();
    final match = RegExp(r'^(.*?)(\d+)$').firstMatch(current);
    late final String updated;

    if (match == null) {
      if (adjustment < 0) return;
      updated = current.isEmpty ? 'Purok 1' : '$current 1';
    } else {
      final number = int.tryParse(match.group(2)!);
      if (number == null || (adjustment < 0 && number <= 1)) return;
      updated = '${match.group(1)}${number + adjustment}';
    }

    _purokController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: updated.length),
    );
    setState(() => _selectedPurok = updated);
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String? _validateBeforeSubmit() {
    if (_needsClinicChoice && _assignedClinicId == null) {
      return 'Select the RHU this patient belongs to.';
    }
    if (!isValidPersonName(_firstNameController.text) ||
        !isValidPersonName(_lastNameController.text)) {
      return 'Enter valid first and last names (2-50 letters).';
    }
    if (_streetController.text.trim().isNotEmpty &&
        !isValidPostalAddress(_streetController.text)) {
      return 'Enter a valid street address (3-200 characters).';
    }
    if (!isValidPersonName(_emergencyNameController.text)) {
      return 'Enter a valid emergency contact name (2-50 letters).';
    }
    if (_gender == null) {
      return 'Please select gender.';
    }
    if (_civilStatus == null) {
      return 'Please select civil status.';
    }
    if (!_isValidOptionalMobile(_contactNumberController.text)) {
      return 'Patient mobile number must be 11 digits and start with 09.';
    }
    if (!_isValidMobile(_emergencyContactController.text)) {
      return 'Emergency contact number must be 11 digits and start with 09.';
    }
    if (!_isValidOptionalEmail(_emailController.text)) {
      return 'Enter a valid email address or leave it blank.';
    }
    if (_selectedCity == null ||
        _selectedBarangay == null ||
        _selectedPurok == null ||
        _zipCodeController.text.trim().isEmpty) {
      return 'Complete Municipality, Barangay, Purok, and ZIP Code before saving.';
    }
    if (!_isValidOptionalPhilHealth(_philHealthController.text)) {
      return 'PhilHealth number must contain 12 digits or be left blank.';
    }
    return null;
  }

  bool _isValidMobile(String value) {
    return isValidPhilippinePhone(value);
  }

  bool _isValidOptionalMobile(String value) {
    return value.trim().isEmpty || _isValidMobile(value);
  }

  bool _isValidOptionalEmail(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return true;
    return isValidEmailAddress(trimmed);
  }

  bool _isValidOptionalPhilHealth(String value) {
    final digits = _digitsOnly(value);
    return digits.isEmpty || digits.length == 12;
  }

  String? _requiredTextError(TextEditingController controller, String label) {
    if (!_showValidationErrors) {
      return null;
    }
    if (label == 'Street address' && controller.text.trim().isEmpty) {
      return null;
    }
    if (label == 'Street address' && isValidPostalAddress(controller.text)) {
      return null;
    }
    if (label == 'First name' ||
        label == 'Last name' ||
        label == 'Emergency contact name') {
      if (isValidPersonName(controller.text)) return null;
      return controller.text.trim().isEmpty
          ? '$label is required.'
          : 'Enter a valid name (2-50 letters).';
    }
    if (label != 'Street address' && controller.text.trim().isNotEmpty) {
      return null;
    }
    if (label == 'Street address' && controller.text.trim().isNotEmpty) {
      return 'Enter a valid address (3-200 characters).';
    }
    return '$label is required.';
  }

  String? _requiredValueError(Object? value, String label) {
    if (!_showValidationErrors || value != null) return null;
    return '$label is required.';
  }

  String? _mobileError(
    TextEditingController controller,
    String label, {
    bool required = true,
  }) {
    if (!_showValidationErrors) return null;
    final value = controller.text.trim();
    if (value.isEmpty) return required ? '$label is required.' : null;
    if (!_isValidMobile(value)) {
      return 'Use an 11-digit number starting with 09.';
    }
    return null;
  }

  String? _optionalEmailError() {
    if (!_showValidationErrors ||
        _isValidOptionalEmail(_emailController.text)) {
      return null;
    }
    return 'Enter a valid email address or leave it blank.';
  }

  String? _optionalPhilHealthError() {
    if (!_showValidationErrors ||
        _isValidOptionalPhilHealth(_philHealthController.text)) {
      return null;
    }
    return 'Use 12 digits or leave it blank.';
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog(
      icon: Icons.person_add_outlined,
      title: 'New Patient Registration',
      subtitle:
          'Complete patient demographic, residence, emergency contact, and medical details',
      maxWidth: 920,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppFormSection(
            title: 'Personal Demographics',
            subtitle: 'Official legal name, birth date, gender, and civil status',
            icon: Icons.badge_outlined,
            child: _buildStep1PersonalInfo(),
          ),
          const SizedBox(height: 16),
          AppFormSection(
            title: 'Address & Contact Details',
            subtitle: 'Residential location, contact numbers, and email address',
            icon: Icons.home_outlined,
            child: _buildStep2ContactInfo(),
          ),
          const SizedBox(height: 16),
          AppFormSection(
            title: 'Emergency Contact Person',
            subtitle:
                'Designated contact person and relationship for emergency situations',
            icon: Icons.contact_phone_outlined,
            child: _buildStep3EmergencyContact(),
          ),
          const SizedBox(height: 16),
          AppFormSection(
            title: 'Medical Profile & PhilHealth',
            subtitle:
                'PhilHealth ID, blood type, PWD status, allergies, and history',
            icon: Icons.health_and_safety_outlined,
            child: _buildStep4MedicalInfo(),
          ),
        ],
      ),
      actions: [
        AppDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
        AppDialogAction(
          label: _isSubmitting ? 'Registering...' : 'Register Patient',
          isPrimary: true,
          icon: _isSubmitting ? null : Icons.check_circle_outline,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
    );
  }

  Widget _buildStep1PersonalInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_needsClinicChoice) ...[
          _buildSectionHeader('Assigned RHU', Icons.local_hospital_outlined),
          _buildDropdownField(
            label: 'Rural Health Unit',
            hint: 'Select the RHU for this patient',
            required: true,
            value: _assignedClinicId,
            items: [
              for (final clinic in (ref.watch(clinicsProvider).valueOrNull ??
                      const <Clinic>[])
                  .where((clinic) => clinic.isActive))
                DropdownMenuItem(value: clinic.id, child: Text(clinic.name)),
            ],
            onChanged: (value) => setState(() => _assignedClinicId = value),
            errorText: _requiredValueError(_assignedClinicId, 'RHU'),
            icon: Icons.local_hospital_outlined,
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
        ],
        _buildSectionHeader('Personal Information (Full Name)', Icons.badge_outlined),
        _buildFormRow([
          _buildFormField(
            label: 'Last Name (LN)',
            hint: 'Family surname',
            required: true,
            controller: _lastNameController,
            onChanged: (_) => setState(() {}),
            errorText: _requiredTextError(_lastNameController, 'Last name'),
            icon: Icons.person_outline,
          ),
          _buildFormField(
            label: 'First Name (FN)',
            hint: 'Given name',
            required: true,
            controller: _firstNameController,
            onChanged: (_) => setState(() {}),
            errorText: _requiredTextError(_firstNameController, 'First name'),
            icon: Icons.person_outline,
          ),
          _buildFormField(
            label: 'Middle Initial (MI)',
            hint: 'e.g. Guerda or G.',
            controller: _middleNameController,
            onChanged: (_) => setState(() {}),
            width: 150,
            icon: Icons.person_outline,
          ),
          _buildDropdownField(
            label: 'Suffix',
            hint: 'Select suffix',
            value: _suffix,
            items: suffixOptions
                .map(
                  (suffix) =>
                      DropdownMenuItem(value: suffix, child: Text(suffix)),
                )
                .toList(),
            onChanged: (value) => setState(() => _suffix = value ?? 'None'),
            icon: Icons.arrow_drop_down_circle_outlined,
          ),
        ]),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),
        _buildSectionHeader('Demographics', Icons.cake_outlined),
        _buildFormRow([
          Expanded(
            child: AppFormField(
              label: 'Date of Birth',
              hint: 'Select birth date',
              required: true,
              field: OutlinedButton.icon(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().subtract(
                      const Duration(days: 365 * 30),
                    ),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => _dateOfBirth = date);
                    _calculateAgeAndCategory();
                  }
                },
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  _dateOfBirth != null
                      ? '${_dateOfBirth!.day.toString().padLeft(2, '0')}/${_dateOfBirth!.month.toString().padLeft(2, '0')}/${_dateOfBirth!.year}'
                      : 'Select date *',
                  style: TextStyle(
                    color: _dateOfBirth != null
                        ? null
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      _requiredValueError(_dateOfBirth, 'Date of birth') != null
                      ? Theme.of(context).colorScheme.error
                      : null,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
              errorText: _requiredValueError(_dateOfBirth, 'Date of birth'),
            ),
          ),
          if (_calculatedAge != null)
            Container(
              margin: const EdgeInsets.only(left: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Age: $_calculatedAge yrs',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
        ]),
        const SizedBox(height: 16),
        _buildFormRow([
          _buildDropdownField(
            label: 'Gender',
            hint: 'Select gender',
            required: true,
            value: _gender,
            items: const [
              DropdownMenuItem(value: 'male', child: Text('Male')),
              DropdownMenuItem(value: 'female', child: Text('Female')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (value) => setState(() => _gender = value),
            errorText: _requiredValueError(_gender, 'Gender'),
            icon: Icons.wc_outlined,
          ),
          _buildDropdownField(
            label: 'Civil Status',
            hint: 'Select status',
            required: true,
            value: _civilStatus,
            items: const [
              DropdownMenuItem(value: 'single', child: Text('Single')),
              DropdownMenuItem(value: 'married', child: Text('Married')),
              DropdownMenuItem(value: 'widowed', child: Text('Widowed')),
              DropdownMenuItem(value: 'separated', child: Text('Separated')),
              DropdownMenuItem(value: 'live-in', child: Text('Live-in')),
            ],
            onChanged: (value) => setState(() => _civilStatus = value),
            errorText: _requiredValueError(_civilStatus, 'Civil Status'),
            icon: Icons.favorite_outline,
          ),
        ]),
        const SizedBox(height: 16),
        _buildFormField(
          label: 'Occupation',
          hint: 'e.g., Farmer, Teacher, Student',
          controller: _occupationController,
          onChanged: (_) => setState(() {}),
          icon: Icons.work_outline,
        ),
      ],
    );
  }

  Widget _buildStep2ContactInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Philippine Address', Icons.home_outlined),

        _buildFormRow([
          _buildReadOnlyField(
            label: 'Region',
            value: _selectedRegion,
            icon: Icons.map_outlined,
          ),
          _buildReadOnlyField(
            label: 'Province',
            value: _selectedProvince,
            icon: Icons.location_city_outlined,
          ),
        ]),
        const SizedBox(height: 12),

        _buildDropdownField(
          label: 'Municipality',
          hint: 'Select municipality',
          required: true,
          value: _selectedCity,
          items: _municipalities
              .map((city) => DropdownMenuItem(value: city, child: Text(city)))
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedCity = value;
              _selectedBarangay = null;
              _selectedPurok = null;
              _purokController.clear();
              _zipCodeController.text =
                  municipalityAddressData[value]?.zipCode ?? '';
            });
          },
          errorText: _requiredValueError(_selectedCity, 'Municipality'),
          icon: Icons.apartment_outlined,
        ),
        const SizedBox(height: 12),

        _buildDropdownField(
          label: 'Barangay',
          hint: _selectedCity == null
              ? 'Select municipality first'
              : 'Select barangay',
          required: true,
          value: _selectedBarangay,
          enabled: _selectedCity != null,
          items: _barangays
              .map((brgy) => DropdownMenuItem(value: brgy, child: Text(brgy)))
              .toList(),
          onChanged: (value) => setState(() {
            _selectedBarangay = value;
            _selectedPurok = null;
            _purokController.clear();
          }),
          errorText: _requiredValueError(_selectedBarangay, 'Barangay'),
          icon: Icons.holiday_village_outlined,
        ),
        const SizedBox(height: 12),

        _buildFormField(
          label: 'Purok / Sitio',
          hint: 'Enter purok or sitio (e.g., Purok 1)',
          required: true,
          controller: _purokController,
          onChanged: (value) => setState(() {
            final trimmed = value.trim();
            _selectedPurok = trimmed.isEmpty ? null : trimmed;
          }),
          suffixIcon: SizedBox(
            width: 96,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Decrease Purok number',
                  onPressed: _canDecreasePurokNumber
                      ? () => _adjustPurokNumber(-1)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                IconButton(
                  tooltip: 'Increase Purok number',
                  onPressed: () => _adjustPurokNumber(1),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          errorText: _requiredValueError(_selectedPurok, 'Purok / Sitio'),
          icon: Icons.location_on_outlined,
        ),
        const SizedBox(height: 12),

        // Street Address
        _buildFormField(
          label: 'Street / House No.',
          hint: 'House #, Street name, Subdivision',
          controller: _streetController,
          onChanged: (_) => setState(() {}),
          errorText: _requiredTextError(_streetController, 'Street address'),
          icon: Icons.home_outlined,
        ),
        const SizedBox(height: 12),

        // ZIP Code
        _buildFormField(
          label: 'ZIP Code',
          hint: 'Auto-filled by municipality',
          controller: _zipCodeController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          readOnly: true,
          width: 120,
        ),

        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),

        _buildSectionHeader('Contact Details', Icons.contact_phone_outlined),
        _buildFormRow([
          _buildFormField(
            label: 'Mobile Number',
            hint: '09XXXXXXXXX',
            required: false,
            controller: _contactNumberController,
            onChanged: (_) => setState(() {}),
            keyboardType: TextInputType.phone,
            maxLength: 13,
            inputFormatters: [_mobileFormatter],
            errorText: _mobileError(
              _contactNumberController,
              'Mobile number',
              required: false,
            ),
            icon: Icons.phone_outlined,
          ),
          _buildFormField(
            label: 'Email Address',
            hint: 'patient@email.com',
            controller: _emailController,
            onChanged: (_) => setState(() {}),
            keyboardType: TextInputType.emailAddress,
            errorText: _optionalEmailError(),
            icon: Icons.email_outlined,
          ),
        ]),
      ],
    );
  }

  Widget _buildStep3EmergencyContact() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.errorContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Emergency contact is required for patient safety and regulatory compliance.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader(
          'Emergency Contact Person',
          Icons.emergency_outlined,
        ),
        _buildFormRow([
          _buildFormField(
            label: 'Full Name',
            hint: 'Contact person name',
            required: true,
            controller: _emergencyNameController,
            onChanged: (_) => setState(() {}),
            errorText: _requiredTextError(
              _emergencyNameController,
              'Emergency contact name',
            ),
            icon: Icons.person_outline,
          ),
          _buildDropdownField(
            label: 'Relationship',
            hint: 'Select relationship',
            required: true,
            value: _emergencyRelationController.text.isNotEmpty
                ? _emergencyRelationController.text
                : null,
            items: const [
              DropdownMenuItem(value: 'Spouse', child: Text('Spouse')),
              DropdownMenuItem(value: 'Parent', child: Text('Parent')),
              DropdownMenuItem(value: 'Child', child: Text('Child')),
              DropdownMenuItem(value: 'Sibling', child: Text('Sibling')),
              DropdownMenuItem(value: 'Relative', child: Text('Relative')),
              DropdownMenuItem(value: 'Friend', child: Text('Friend')),
              DropdownMenuItem(value: 'Guardian', child: Text('Guardian')),
            ],
            onChanged: (value) {
              setState(() {
                _emergencyRelationController.text = value ?? '';
              });
            },
            errorText: _requiredTextError(
              _emergencyRelationController,
              'Relationship',
            ),
            icon: Icons.people_outline,
          ),
        ]),
        const SizedBox(height: 16),
        _buildFormField(
          label: 'Emergency Contact Number',
          hint: '09XXXXXXXXX',
          required: true,
          controller: _emergencyContactController,
          onChanged: (_) => setState(() {}),
          keyboardType: TextInputType.phone,
          maxLength: 13,
          inputFormatters: [_mobileFormatter],
          errorText: _mobileError(
            _emergencyContactController,
            'Emergency contact number',
          ),
          icon: Icons.phone_outlined,
        ),
      ],
    );
  }

  Widget _buildStep4MedicalInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Government ID & Insurance',
          Icons.credit_card_outlined,
        ),
        _buildFormField(
          label: 'PhilHealth Number',
          hint: 'XX-XXXXXXXXX-X',
          controller: _philHealthController,
          onChanged: (_) => setState(() {}),
          maxLength: 14,
          inputFormatters: [_philHealthFormatter],
          errorText: _optionalPhilHealthError(),
          icon: Icons.health_and_safety_outlined,
        ),

        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),

        _buildSectionHeader(
          'Medical Information',
          Icons.medical_information_outlined,
        ),
        _buildFormRow([
          _buildDropdownField(
            label: 'Blood Type',
            hint: 'Select blood type',
            value: _bloodType,
            items: const [
              DropdownMenuItem(value: 'A+', child: Text('A+')),
              DropdownMenuItem(value: 'A-', child: Text('A-')),
              DropdownMenuItem(value: 'B+', child: Text('B+')),
              DropdownMenuItem(value: 'B-', child: Text('B-')),
              DropdownMenuItem(value: 'AB+', child: Text('AB+')),
              DropdownMenuItem(value: 'AB-', child: Text('AB-')),
              DropdownMenuItem(value: 'O+', child: Text('O+')),
              DropdownMenuItem(value: 'O-', child: Text('O-')),
            ],
            onChanged: (value) => setState(() => _bloodType = value),
            icon: Icons.bloodtype_outlined,
          ),
          _buildReadOnlyField(
            label: 'Patient Category',
            value: _patientCategory != null
                ? (PatientCategory.values
                        .where((e) => e.name == _patientCategory)
                        .firstOrNull
                        ?.displayName ??
                    _patientCategory!)
                : 'Select date of birth first',
            icon: Icons.category_outlined,
          ),
        ]),

        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Person with Disability (PWD)'),
          subtitle: const Text('Check if the patient is a registered PWD'),
          value: _isPwd,
          onChanged: (value) => setState(() => _isPwd = value),
          contentPadding: EdgeInsets.zero,
          secondary: Icon(
            Icons.accessible_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 24),

        _buildSectionHeader(
          'Medical History & Allergies',
          Icons.history_outlined,
        ),
        const SizedBox(height: 6),
        Text(
          'Common Allergies (tap chip to toggle):',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _commonAllergies.map((allergy) {
            final isSelected =
                _allergiesController.text.contains(allergy) ||
                (allergy == 'No Known Allergies (NKDA)' &&
                    _allergiesController.text.trim() == 'NKDA');
            return FilterChip(
              label: Text(allergy, style: const TextStyle(fontSize: 11)),
              selected: isSelected,
              onSelected: (_) => _toggleAllergy(allergy),
              selectedColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
              checkmarkColor: const Color(0xFFEF4444),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        _buildFormField(
          label: 'Known Allergies',
          hint: 'e.g., Penicillin, Shellfish, Latex, etc.',
          controller: _allergiesController,
          maxLines: 2,
          icon: Icons.warning_outlined,
        ),
        const SizedBox(height: 12),
        _buildFormField(
          label: 'Previous Medical Conditions',
          hint: 'e.g., Hypertension, Diabetes, Asthma, etc.',
          controller: _medicalHistoryController,
          maxLines: 2,
          icon: Icons.medical_services_outlined,
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),
        _buildRegistrationSummary(),
      ],
    );
  }

  Widget _buildRegistrationSummary() {
    final address = [
      _streetController.text.trim(),
      _selectedPurok,
      _selectedBarangay,
      _selectedCity,
      _selectedProvince,
    ].whereType<String>().where((value) => value.isNotEmpty).join(', ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.fact_check_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Review Before Saving',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            label: 'Patient',
            value:
                '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
                    .trim(),
          ),
          _SummaryRow(
            label: 'Age / Gender',
            value: '${_calculatedAge ?? 'N/A'} years old / ${_gender ?? 'N/A'}',
          ),
          _SummaryRow(
            label: 'Address',
            value: address.isEmpty ? 'Not completed' : address,
          ),
          _SummaryRow(
            label: 'Mobile',
            value: _contactNumberController.text.trim().isEmpty
                ? 'Not completed'
                : _contactNumberController.text.trim(),
          ),
          _SummaryRow(
            label: 'Emergency Contact',
            value:
                '${_emergencyNameController.text.trim()} (${_emergencyRelationController.text.trim()})'
                    .trim(),
          ),
          const SizedBox(height: 8),
          Text(
            'Confirm the details above before creating the patient record.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormRow(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        Widget unwrapFlex(Widget child) {
          if (child is Expanded) return child.child;
          if (child is Flexible) return child.child;
          return child;
        }

        if (constraints.maxWidth < 680) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children
                .map(
                  (child) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: unwrapFlex(child),
                  ),
                )
                .toList(),
          );
        }

        Widget wrapFlex(Widget child) {
          return child is Expanded || child is Flexible
              ? child
              : Expanded(child: child);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children.length == 1
              ? [wrapFlex(children.first)]
              : children.asMap().entries.expand((entry) {
                  final index = entry.key;
                  final child = entry.value;
                  if (index == 0) {
                    return [wrapFlex(child)];
                  } else {
                    return [const SizedBox(width: 12), wrapFlex(child)];
                  }
                }).toList(),
        );
      },
    );
  }

  Widget _buildFormField({
    required String label,
    required String hint,
    bool required = false,
    TextEditingController? controller,
    Function(String)? onChanged,
    TextInputType? keyboardType,
    int? maxLength,
    int? maxLines,
    double? width,
    IconData? icon,
    Widget? suffixIcon,
    String? errorText,
    bool readOnly = false,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final field = AppFormField(
      label: label,
      hint: hint,
      required: required,
      field: TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: keyboardType,
        maxLength: maxLength,
        maxLines: maxLines ?? 1,
        readOnly: readOnly,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          hintText: hint,
          border: const OutlineInputBorder(),
          prefixIcon: icon != null ? Icon(icon) : null,
          suffixIcon: suffixIcon,
          counterText: maxLength != null ? null : '',
          errorText: errorText,
        ),
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: field);
    }
    return field;
  }

  Widget _buildDropdownField({
    required String label,
    required String hint,
    bool required = false,
    String? value,
    bool enabled = true,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
    IconData? icon,
    String? errorText,
  }) {
    return AppFormField(
      label: label,
      hint: hint,
      required: required,
      field: DropdownButtonFormField<String>(
        initialValue: value,
        // Long hints and option names truncate instead of overflowing on
        // narrow screens.
        isExpanded: true,
        hint: Text(hint, overflow: TextOverflow.ellipsis),
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          prefixIcon: icon != null ? Icon(icon) : null,
          enabled: enabled,
          errorText: errorText,
        ),
        items: items,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    IconData? icon,
  }) {
    return AppFormField(
      label: label,
      hint: value,
      field: InputDecorator(
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          prefixIcon: icon != null ? Icon(icon) : null,
        ),
        child: Text(value),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.68),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not completed' : value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientListTile extends StatelessWidget {
  final Patient patient;
  final bool showLocation;
  final bool isSelected;
  final VoidCallback onTap;

  const _PatientListTile({
    required this.patient,
    this.showLocation = false,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _patientInitials(patient);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark
                ? AppColors.primaryEmeraldSubtle
                : const Color(0xFFF0FDF4))
            : (isDark ? AppColors.cardSurface : Colors.white),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? AppColors.primaryEmerald
              : (isDark
                  ? AppColors.borderSubtle
                  : const Color(0xFFE2E8F0)),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.inputSurface
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? AppColors.borderSubtle
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textPrimary
                        : const Color(0xFF334155),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
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
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.1,
                              color: isDark
                                  ? AppColors.textPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                        if (patient.category != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.elevatedSurface
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.borderSubtle
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              patient.category!.displayName,
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.textSecondary
                                    : const Color(0xFF475569),
                                fontWeight: FontWeight.w500,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${patient.age ?? 'N/A'} yrs · ${patient.gender?.toUpperCase() ?? 'N/A'} · PHN: ${patient.philHealthNumber ?? 'None'}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    if (showLocation) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: isDark
                                ? AppColors.textTertiary
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${_locationLabel(patient.barangay, 'Unassigned Barangay')} · ${_locationLabel(patient.purokSitio, 'Unassigned Purok')}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.textMuted
                                    : AppColors.lightTextMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: isSelected
                    ? AppColors.primaryEmerald
                    : (isDark
                        ? AppColors.textTertiary
                        : const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PatientGridCard extends StatelessWidget {
  final Patient patient;
  final bool isSelected;
  final VoidCallback onTap;

  const _PatientGridCard({
    required this.patient,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark
                ? AppColors.primaryEmeraldSubtle
                : const Color(0xFFF0FDF4))
            : (isDark ? AppColors.cardSurface : Colors.white),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? AppColors.primaryEmerald
              : (isDark
                  ? AppColors.borderSubtle
                  : const Color(0xFFE2E8F0)),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.inputSurface
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark
                            ? AppColors.borderSubtle
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _patientInitials(patient),
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textPrimary
                            : const Color(0xFF334155),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      patient.fullName,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                        color: isDark
                            ? AppColors.textPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _PatientMetaLine(
                icon: Icons.credit_card,
                text: 'PHN: ${patient.philHealthNumber ?? 'None'}',
              ),
              const SizedBox(height: 4),
              _PatientMetaLine(
                icon: Icons.cake_outlined,
                text:
                    '${patient.age ?? 'N/A'} yrs · ${patient.gender?.toUpperCase() ?? 'N/A'}',
              ),
              const SizedBox(height: 4),
              _PatientMetaLine(
                icon: Icons.location_on_outlined,
                text:
                    '${_locationLabel(patient.barangay, 'No barangay')} · ${_locationLabel(patient.purokSitio, 'No purok')}',
              ),
              if (patient.category != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.elevatedSurface
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isDark
                          ? AppColors.borderSubtle
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    patient.category!.displayName,
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textSecondary
                          : const Color(0xFF475569),
                      fontWeight: FontWeight.w500,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PatientMetaLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PatientMetaLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.55),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

String _patientInitials(Patient patient) {
  if (patient.firstName.isNotEmpty && patient.lastName.isNotEmpty) {
    return '${patient.firstName[0]}${patient.lastName[0]}'.toUpperCase();
  }
  return patient.firstName.isNotEmpty
      ? patient.firstName[0].toUpperCase()
      : '?';
}

String _locationLabel(String? value, String fallback) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? fallback : trimmed;
}


// Patient registration with Philippine address support and auto age/category detection
