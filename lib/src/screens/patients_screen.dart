import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/patient.dart';
import '../providers/providers.dart';
import '../services/app_notification.dart';
import '../utils/patient_address_data.dart';
import '../widgets/app_form_dialog.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../widgets/loading_state.dart';

class PatientsScreen extends ConsumerStatefulWidget {
  final bool openAddPatient;
  final String? initialSearch;

  const PatientsScreen({
    super.key,
    this.openAddPatient = false,
    this.initialSearch,
  });

  @override
  ConsumerState<PatientsScreen> createState() => _PatientsScreenState();
}

enum _PatientViewMode { list, grid }

enum _PatientSortMode { byLocation, alphabetical }

class _PatientsScreenState extends ConsumerState<PatientsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _barangayFilter;
  String? _purokFilter;
  PatientCategory? _categoryFilter;
  _PatientViewMode _viewMode = _PatientViewMode.list;
  _PatientSortMode _sortMode = _PatientSortMode.byLocation;

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
    _searchController.dispose();
    super.dispose();
  }

  void _showAddPatientDialog(BuildContext context) {
    if (!_canRegisterPatients) return;

    showDialog(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (context, ref, child) => _PatientRegistrationWizard(
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
    final patientsAsync = ref.watch(patientsProvider);
    final canRegisterPatients = _canRegisterPatients;

    return Column(
      children: [
        Expanded(
          child: patientsAsync.when(
            skipLoadingOnReload: true,
            data: (patients) {
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

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PatientsPageHeader(
                    totalCount: patients.length,
                    filteredCount: filteredPatients.length,
                    barangayCount: barangays.length,
                    onAddPatient: canRegisterPatients
                        ? () => _showAddPatientDialog(context)
                        : null,
                  ),
                  _PatientsToolbar(
                    searchController: _searchController,
                    searchQuery: _searchQuery,
                    barangayFilter: _barangayFilter,
                    purokFilter: _purokFilter,
                    categoryFilter: _categoryFilter,
                    viewMode: _viewMode,
                    sortMode: _sortMode,
                    barangays: barangays,
                    puroks: puroks,
                    onSearchChanged: (value) =>
                        setState(() => _searchQuery = value),
                    onClearSearch: () {
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
                  ),
                  Expanded(
                    child: filteredPatients.isEmpty
                        ? _EmptyPatientsState(
                            hasFilters: _hasActiveFilters,
                            onClearFilters: _clearFilters,
                            onAddPatient: canRegisterPatients
                                ? () => _showAddPatientDialog(context)
                                : null,
                          )
                        : _PatientsContentView(
                            patients: filteredPatients,
                            groupedPatients: _groupPatients(filteredPatients),
                            viewMode: _viewMode,
                            sortMode: _sortMode,
                            onPatientTap: (patient) =>
                                context.push('/patients/${patient.id}'),
                          ),
                  ),
                ],
              );
            },
            loading: () => const LoadingState(),
            error: (error, stack) => Center(
              child: Text(
                'Unable to load patients: $error',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        ),
      ],
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
    _searchController.text = search;
    _searchQuery = search;
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _barangayFilter = null;
      _purokFilter = null;
      _categoryFilter = null;
    });
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

  Map<String, Map<String, List<Patient>>> _groupPatients(
    List<Patient> patients,
  ) {
    final grouped = <String, Map<String, List<Patient>>>{};
    for (final patient in patients) {
      final barangay = _locationLabel(patient.barangay, 'Unassigned Barangay');
      final purok = _locationLabel(patient.purokSitio, 'Unassigned Purok');
      grouped.putIfAbsent(barangay, () => <String, List<Patient>>{});
      grouped[barangay]!.putIfAbsent(purok, () => <Patient>[]);
      grouped[barangay]![purok]!.add(patient);
    }
    return grouped;
  }
}

class _PatientsPageHeader extends StatelessWidget {
  final int totalCount;
  final int filteredCount;
  final int barangayCount;
  final VoidCallback? onAddPatient;

  const _PatientsPageHeader({
    required this.totalCount,
    required this.filteredCount,
    required this.barangayCount,
    this.onAddPatient,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primary, primary.withValues(alpha: 0.82)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.people_alt_outlined,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Patient Registry',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Search, filter, and open patient records',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onAddPatient != null)
                  FilledButton.icon(
                    onPressed: onAddPatient,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: primary,
                    ),
                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                    label: const Text('Register'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatChip(
                icon: Icons.groups_outlined,
                label: 'Total',
                value: totalCount.toString(),
              ),
              _StatChip(
                icon: Icons.filter_list_outlined,
                label: 'Showing',
                value: filteredCount.toString(),
              ),
              _StatChip(
                icon: Icons.holiday_village_outlined,
                label: 'Barangays',
                value: barangayCount.toString(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search name, PhilHealth #, contact, barangay...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.clear),
                      onPressed: onClearSearch,
                    )
                  : null,
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: onSearchChanged,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 180,
                child: _FilterDropdown<String>(
                  label: 'Barangay',
                  value: barangayFilter,
                  items: barangays,
                  itemLabel: (value) => value,
                  onChanged: onBarangayChanged,
                ),
              ),
              SizedBox(
                width: 180,
                child: _FilterDropdown<String>(
                  label: 'Purok',
                  value: purokFilter,
                  items: puroks,
                  itemLabel: (value) => value,
                  onChanged: onPurokChanged,
                ),
              ),
              SizedBox(
                width: 180,
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
              SegmentedButton<_PatientSortMode>(
                segments: const [
                  ButtonSegment(
                    value: _PatientSortMode.byLocation,
                    icon: Icon(Icons.map_outlined, size: 16),
                    label: Text('By Barangay'),
                  ),
                  ButtonSegment(
                    value: _PatientSortMode.alphabetical,
                    icon: Icon(Icons.sort_by_alpha, size: 16),
                    label: Text('A–Z'),
                  ),
                ],
                selected: {sortMode},
                onSelectionChanged: (value) => onSortModeChanged(value.first),
              ),
              SegmentedButton<_PatientViewMode>(
                segments: const [
                  ButtonSegment(
                    value: _PatientViewMode.list,
                    icon: Icon(Icons.view_list_outlined, size: 16),
                    label: Text('List'),
                  ),
                  ButtonSegment(
                    value: _PatientViewMode.grid,
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
    return DropdownButtonFormField<T?>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        DropdownMenuItem<T?>(value: null, child: Text('All $label')),
        ...items.map(
          (item) => DropdownMenuItem<T?>(
            value: item,
            child: Text(itemLabel(item), overflow: TextOverflow.ellipsis),
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
  final _PatientViewMode viewMode;
  final _PatientSortMode sortMode;
  final ValueChanged<Patient> onPatientTap;

  const _PatientsContentView({
    required this.patients,
    required this.groupedPatients,
    required this.viewMode,
    required this.sortMode,
    required this.onPatientTap,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = _sortedPatients();

    if (viewMode == _PatientViewMode.grid) {
      return _PatientsGridView(patients: sorted, onPatientTap: onPatientTap);
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
              ),
              const SizedBox(height: 8),
              ...sectionPatients.map(
                (patient) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PatientListTile(
                    patient: patient,
                    showLocation: true,
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

  const _BarangaySectionHeader({
    required this.barangay,
    required this.patientCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.holiday_village_outlined,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              barangay,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            '$patientCount',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientsGridView extends StatelessWidget {
  final List<Patient> patients;
  final ValueChanged<Patient> onPatientTap;

  const _PatientsGridView({required this.patients, required this.onPatientTap});

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
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasFilters ? Icons.search_off_rounded : Icons.people_outline,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              hasFilters ? 'No Matches Found' : 'No Patients Yet',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              hasFilters
                  ? 'We couldn\'t find any patients matching your current filters. Try adjusting them or clearing the search.'
                  : 'Start building your patient registry by adding your first patient record to the system.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 32),
            if (hasFilters && onClearFilters != null)
              FilledButton.tonalIcon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.filter_alt_off),
                label: const Text('Clear All Filters'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              )
            else if (onAddPatient != null)
              FilledButton.icon(
                onPressed: onAddPatient,
                icon: const Icon(Icons.person_add),
                label: const Text('Register New Patient'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PatientRegistrationWizard extends ConsumerStatefulWidget {
  final VoidCallback onPatientAdded;

  const _PatientRegistrationWizard({required this.onPatientAdded});

  @override
  ConsumerState<_PatientRegistrationWizard> createState() =>
      _PatientRegistrationWizardState();
}

class _PatientRegistrationWizardState
    extends ConsumerState<_PatientRegistrationWizard> {
  int _currentStep = 0;
  final int _totalSteps = 4;
  bool _showValidationErrors = false;

  // Step 1: Personal Information
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  String _suffix = 'None';
  DateTime? _dateOfBirth;
  String? _gender;
  String? _civilStatus;
  int? _calculatedAge;
  final _religionController = TextEditingController();

  // Step 2: Contact Information
  final _streetController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _emailController = TextEditingController();

  final _mobileFormatter = MaskTextInputFormatter(
    mask: '09##-###-####',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  // Address dropdowns
  String? _selectedRegion;
  String? _selectedProvince;
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

  List<String> get _puroks {
    final municipality = _selectedCity;
    final barangay = _selectedBarangay;
    if (municipality == null || barangay == null) return const [];
    return municipalityAddressData[municipality]?.barangayPuroks[barangay] ??
        const [];
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleNameController.dispose();
    _religionController.dispose();
    _streetController.dispose();
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

  bool _isStepValid() {
    switch (_currentStep) {
      case 0:
        return _firstNameController.text.trim().isNotEmpty &&
            _lastNameController.text.trim().isNotEmpty &&
            _dateOfBirth != null &&
            _gender != null &&
            _civilStatus != null;
      case 1:
        return _streetController.text.trim().isNotEmpty &&
            _selectedBarangay != null &&
            _selectedPurok != null &&
            _selectedCity != null &&
            _selectedProvince != null &&
            _zipCodeController.text.trim().isNotEmpty &&
            _isValidMobile(_contactNumberController.text) &&
            _isValidOptionalEmail(_emailController.text);
      case 2:
        return _emergencyNameController.text.trim().isNotEmpty &&
            _emergencyRelationController.text.trim().isNotEmpty &&
            _isValidMobile(_emergencyContactController.text);
      case 3:
        return _isValidOptionalPhilHealth(_philHealthController.text);
      default:
        return false;
    }
  }

  void _nextStep() {
    if (!_isStepValid()) {
      setState(() => _showValidationErrors = true);
      return;
    }

    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
        _showValidationErrors = false;
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _showValidationErrors = false;
      });
    }
  }

  Future<void> _submit() async {
    try {
      if (!_isStepValid()) {
        setState(() => _showValidationErrors = true);
        return;
      }

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
        contactNumber: _contactNumberController.text.trim(),
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
        emergencyContactNumber: _emergencyContactController.text.trim(),
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
        religion: _religionController.text.trim().isNotEmpty
            ? _religionController.text.trim()
            : null,
        isPwd: _isPwd,
        medicalHistory: _medicalHistoryController.text.trim().isNotEmpty
            ? _medicalHistoryController.text.trim()
            : null,
        category: patientCategoryFromDateOfBirth(_dateOfBirth),
        userId: currentUser?.id ?? 'system',
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
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Possible Duplicate Patient'),
        content: Text(
          '$message\n\nReview the existing record before creating another patient profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Review'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Create Anyway'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String? _validateBeforeSubmit() {
    if (_gender == null) {
      return 'Please select gender.';
    }
    if (_civilStatus == null) {
      return 'Please select civil status.';
    }
    if (!_isValidMobile(_contactNumberController.text)) {
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
    final digits = _digitsOnly(value);
    return digits.length == 11 && digits.startsWith('09');
  }

  bool _isValidOptionalEmail(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return true;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed);
  }

  bool _isValidOptionalPhilHealth(String value) {
    final digits = _digitsOnly(value);
    return digits.isEmpty || digits.length == 12;
  }

  String? _requiredTextError(TextEditingController controller, String label) {
    if (!_showValidationErrors || controller.text.trim().isNotEmpty) {
      return null;
    }
    return '$label is required.';
  }

  String? _requiredValueError(Object? value, String label) {
    if (!_showValidationErrors || value != null) return null;
    return '$label is required.';
  }

  String? _mobileError(TextEditingController controller, String label) {
    if (!_showValidationErrors) return null;
    final value = controller.text.trim();
    if (value.isEmpty) return '$label is required.';
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
      subtitle: 'Step ${_currentStep + 1} of $_totalSteps: ${_getStepTitle()}',
      maxWidth: 900,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStepProgress(),
          const SizedBox(height: 18),
          _buildCurrentStep(),
        ],
      ),
      actions: [
        if (_currentStep > 0)
          AppDialogAction(label: 'Back', onPressed: _previousStep)
        else
          AppDialogAction(
            label: 'Cancel',
            onPressed: () => Navigator.pop(context),
          ),
        if (_currentStep < _totalSteps - 1)
          AppDialogAction(
            label: 'Next',
            isPrimary: true,
            icon: Icons.arrow_forward,
            onPressed: _nextStep,
          )
        else
          AppDialogAction(
            label: 'Register Patient',
            isPrimary: true,
            icon: Icons.check,
            onPressed: _submit,
          ),
      ],
    );
  }

  Widget _buildStepProgress() {
    final steps = List.generate(_totalSteps, (index) => index);
    return Row(
      children: steps.expand((index) {
        final isActive = index == _currentStep;
        final isDone = index < _currentStep;
        final color = isDone || isActive
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline.withValues(alpha: 0.45);

        final marker = AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: isDone || isActive
                ? color
                : Theme.of(context).colorScheme.surface,
            border: Border.all(color: color),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isActive
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        );

        return [
          Tooltip(message: _getStepTitleFor(index), child: marker),
          if (index < _totalSteps - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: color.withValues(alpha: isDone ? 1 : 0.35),
              ),
            ),
        ];
      }).toList(),
    );
  }

  String _getStepTitle() {
    return _getStepTitleFor(_currentStep);
  }

  String _getStepTitleFor(int step) {
    switch (step) {
      case 0:
        return 'Personal Information';
      case 1:
        return 'Contact & Address';
      case 2:
        return 'Emergency Contact';
      case 3:
        return 'Medical & Administrative';
      default:
        return '';
    }
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep1PersonalInfo();
      case 1:
        return _buildStep2ContactInfo();
      case 2:
        return _buildStep3EmergencyContact();
      case 3:
        return _buildStep4MedicalInfo();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1PersonalInfo() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Full Name', Icons.badge_outlined),
          _buildFormRow([
            _buildFormField(
              label: 'First Name',
              hint: 'Given name',
              required: true,
              controller: _firstNameController,
              onChanged: (_) => setState(() {}),
              errorText: _requiredTextError(_firstNameController, 'First name'),
              icon: Icons.person_outline,
            ),
            _buildFormField(
              label: 'Middle Initial',
              hint: 'Middle initial',
              controller: _middleNameController,
              maxLength: 2,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')),
              ],
              onChanged: (value) {
                final formatted = formatMiddleInitial(value);
                if (formatted != null &&
                    _middleNameController.text != formatted) {
                  _middleNameController.value = TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(
                      offset: formatted.length,
                    ),
                  );
                }
                setState(() {});
              },
              width: 150,
            ),
            _buildFormField(
              label: 'Last Name',
              hint: 'Family name',
              required: true,
              controller: _lastNameController,
              onChanged: (_) => setState(() {}),
              errorText: _requiredTextError(_lastNameController, 'Last name'),
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
                        _requiredValueError(_dateOfBirth, 'Date of birth') !=
                            null
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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
          _buildFormRow([
            _buildFormField(
              label: 'Religion',
              hint: 'e.g., Catholic, INC, Islam',
              controller: _religionController,
              onChanged: (_) => setState(() {}),
              icon: Icons.church_outlined,
            ),
            _buildFormField(
              label: 'Occupation',
              hint: 'e.g., Farmer, Teacher, Student',
              controller: _occupationController,
              onChanged: (_) => setState(() {}),
              icon: Icons.work_outline,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildStep2ContactInfo() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Philippine Address', Icons.home_outlined),

          _buildFormRow([
            _buildDropdownField(
              label: 'Region',
              hint: 'Caraga (Region XIII)',
              required: true,
              value: _selectedRegion,
              items: const [
                DropdownMenuItem(
                  value: 'Caraga (Region XIII)',
                  child: Text('Caraga (Region XIII)'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedRegion = value;
                  _selectedProvince = 'Surigao del Sur';
                });
              },
              errorText: _requiredValueError(_selectedRegion, 'Region'),
              icon: Icons.map_outlined,
            ),
            _buildDropdownField(
              label: 'Province',
              hint: 'Surigao del Sur',
              required: true,
              value: _selectedProvince,
              enabled: _selectedRegion != null,
              items: const [
                DropdownMenuItem(
                  value: 'Surigao del Sur',
                  child: Text('Surigao del Sur'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedProvince = value;
                  _selectedCity = null;
                  _selectedBarangay = null;
                  _selectedPurok = null;
                  _zipCodeController.clear();
                });
              },
              errorText: _requiredValueError(_selectedProvince, 'Province'),
              icon: Icons.location_city_outlined,
            ),
          ]),
          const SizedBox(height: 12),

          _buildDropdownField(
            label: 'Municipality',
            hint: _selectedProvince == null
                ? 'Select province first'
                : 'Select municipality',
            required: true,
            value: _selectedCity,
            enabled: _selectedProvince != null,
            items: _municipalities
                .map((city) => DropdownMenuItem(value: city, child: Text(city)))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedCity = value;
                _selectedBarangay = null;
                _selectedPurok = null;
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
            }),
            errorText: _requiredValueError(_selectedBarangay, 'Barangay'),
            icon: Icons.holiday_village_outlined,
          ),
          const SizedBox(height: 12),

          _buildDropdownField(
            label: 'Purok / Sitio',
            hint: _selectedBarangay == null
                ? 'Select barangay first'
                : 'Select purok',
            required: true,
            value: _selectedPurok,
            enabled: _selectedBarangay != null,
            items: _puroks
                .map(
                  (purok) => DropdownMenuItem(value: purok, child: Text(purok)),
                )
                .toList(),
            onChanged: (value) => setState(() => _selectedPurok = value),
            errorText: _requiredValueError(_selectedPurok, 'Purok / Sitio'),
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 12),

          // Street Address
          _buildFormField(
            label: 'Street / House No.',
            hint: 'House #, Street name, Subdivision',
            required: true,
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
              required: true,
              controller: _contactNumberController,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.phone,
              maxLength: 13,
              inputFormatters: [_mobileFormatter],
              errorText: _mobileError(
                _contactNumberController,
                'Mobile number',
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
      ),
    );
  }

  Widget _buildStep3EmergencyContact() {
    return SingleChildScrollView(
      child: Column(
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
                color: Theme.of(
                  context,
                ).colorScheme.error.withValues(alpha: 0.3),
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
      ),
    );
  }

  Widget _buildStep4MedicalInfo() {
    return SingleChildScrollView(
      child: Column(
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
                  ? PatientCategory.values.byName(_patientCategory!).displayName
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

          _buildSectionHeader('Medical History', Icons.history_outlined),
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
      ),
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
        if (constraints.maxWidth < 680) {
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
        hint: Text(hint),
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
  final VoidCallback onTap;

  const _PatientListTile({
    required this.patient,
    this.showLocation = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final categoryColor = _patientCategoryColor(patient.category);
    final initials = _patientInitials(patient);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: categoryColor,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
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
                        Expanded(
                          child: Text(
                            patient.fullName,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (patient.category != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              patient.category!.displayName,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: categoryColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${patient.age ?? 'N/A'} yrs • ${patient.gender?.toUpperCase() ?? 'N/A'} • PHN: ${patient.philHealthNumber ?? 'N/A'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                    if (showLocation) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${_locationLabel(patient.barangay, 'No barangay')} • ${_locationLabel(patient.purokSitio, 'No purok')}',
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.35),
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
  final VoidCallback onTap;

  const _PatientGridCard({required this.patient, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final categoryColor = _patientCategoryColor(patient.category);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: categoryColor,
                    child: Text(
                      _patientInitials(patient),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      patient.fullName,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _PatientMetaLine(
                icon: Icons.credit_card,
                text: 'PHN: ${patient.philHealthNumber ?? 'N/A'}',
              ),
              const SizedBox(height: 6),
              _PatientMetaLine(
                icon: Icons.cake_outlined,
                text:
                    '${patient.age ?? 'N/A'} years old - ${patient.gender?.toUpperCase() ?? 'N/A'}',
              ),
              const SizedBox(height: 6),
              _PatientMetaLine(
                icon: Icons.location_on_outlined,
                text:
                    '${_locationLabel(patient.barangay, 'No barangay')} / ${_locationLabel(patient.purokSitio, 'No purok')}',
              ),
              if (patient.category != null) ...[
                const SizedBox(height: 10),
                Chip(
                  label: Text(patient.category!.displayName),
                  backgroundColor: categoryColor.withValues(alpha: 0.1),
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

Color _patientCategoryColor(PatientCategory? category) {
  if (category == null) {
    return Colors.grey;
  }

  switch (category) {
    case PatientCategory.infant:
    case PatientCategory.toddler:
    case PatientCategory.preschool:
    case PatientCategory.schoolAge:
    case PatientCategory.adolescent:
    case PatientCategory.pediatric:
      return const Color(0xFF059669);
    case PatientCategory.adult:
      return const Color(0xFF16A34A);
    case PatientCategory.senior:
    case PatientCategory.seniorCitizen:
      return const Color(0xFF15803D);
    case PatientCategory.pregnant:
      return const Color(0xFF10B981);
    case PatientCategory.pwd:
      return const Color(0xFF047857);
  }
}

// Patient registration with Philippine address support and auto age/category detection
