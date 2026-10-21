import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/certificate_service.dart';
import '../utils/file_exporter/file_exporter.dart';
import '../widgets/app_form_dialog.dart';
import '../widgets/layout/responsive_layout.dart';
import '../widgets/loading_state.dart';
import '../widgets/scrolling_tab_layout.dart';

class CertificatesScreen extends ConsumerStatefulWidget {
  const CertificatesScreen({super.key});

  @override
  ConsumerState<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends ConsumerState<CertificatesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  CertificateType _selectedType = CertificateType.medicalCertificate;
  String? _selectedPatientId;
  final _purposeController = TextEditingController();
  final _findingsController = TextEditingController();
  final _recommendationsController = TextEditingController();
  final _restDaysController = TextEditingController();
  final _searchArchiveController = TextEditingController();
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _purposeController.addListener(_onFieldChanged);
    _findingsController.addListener(_onFieldChanged);
    _recommendationsController.addListener(_onFieldChanged);
    _restDaysController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    _purposeController.dispose();
    _findingsController.dispose();
    _recommendationsController.dispose();
    _restDaysController.dispose();
    _searchArchiveController.dispose();
    super.dispose();
  }

  Patient? _resolveSelectedPatient(List<Patient> patients) {
    if (_selectedPatientId == null) return null;
    for (final p in patients) {
      if (p.id == _selectedPatientId) return p;
    }
    return null;
  }

  void _applyPreset({
    required String purpose,
    required String findings,
    required String recommendations,
    String restDays = '',
  }) {
    _purposeController.text = purpose;
    _findingsController.text = findings;
    _recommendationsController.text = recommendations;
    _restDaysController.text = restDays;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied preset: $purpose'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final archiveAsync = ref.watch(issuedCertificatesProvider);
    final archiveCount = archiveAsync.valueOrNull?.length ?? 0;

    return ResponsiveContentContainer(
      padding: ResponsiveLayout.pagePadding(context),
      child: Builder(
        builder: (context) {
          final tabView = TabBarView(
            controller: _tabController,
            children: [
              _buildIssuanceTab(context, isDark),
              _buildArchiveTab(context, isDark, archiveAsync),
            ],
          );

          // The whole page scrolls with the open tab, not just the tab.
          return ScrollingTabLayout(
            header: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardSurface : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppColors.borderSubtle : AppColors.lightBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.verified_outlined,
                      size: 22,
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.lightTextSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Official Certificates & Medical Clearances',
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
                            'Generate DOH-compliant medical certificates, return-to-work clearances, and patient summaries',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.textSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardSurface : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppColors.borderSubtle : AppColors.lightBorder,
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
                          : AppColors.lightTextSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$archiveCount certificates issued',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: isDark
                            ? AppColors.textPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    Text(
                      ' · ',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textTertiary
                            : AppColors.lightTextMuted,
                      ),
                    ),
                    Text(
                      'Based on DOH AO No. 2021-0037',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            tabBar: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: isDark ? AppColors.primaryEmerald : AppColors.primaryEmeraldDark,
                unselectedLabelColor: isDark
                    ? AppColors.textSecondary
                    : AppColors.lightTextSecondary,
                indicatorColor: isDark ? AppColors.primaryEmerald : AppColors.primaryEmeraldDark,
                indicatorWeight: 2,
                tabs: [
                  const Tab(
                    icon: Icon(Icons.edit_document, size: 16),
                    child: Text('Issue Certificate & Live Preview', style: TextStyle(fontSize: 14)),
                  ),
                  Tab(
                    icon: const Icon(Icons.history_edu, size: 16),
                    child: Text('Issued Registry ($archiveCount)', style: TextStyle(fontSize: 14)),
                  ),
                ],
              ),
            tabView: tabView,
          );
        },
      ),
    );
  }

  Widget _buildIssuanceTab(BuildContext context, bool isDark) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final settingsAsync = ref.watch(systemSettingsProvider);
    final settings = settingsAsync.valueOrNull;

    if (isMobile) {
      return SingleChildScrollView(
        child: Column(
          children: [
            _buildCertificateForm(context, isDark, settings),
            const SizedBox(height: 20),
            _buildLivePreviewCard(context, isDark, settings),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: _buildCertificateForm(context, isDark, settings),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 5,
            child: _buildLivePreviewCard(context, isDark, settings),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificateForm(
    BuildContext context,
    bool isDark,
    SystemSettings? settings,
  ) {
    final patientsAsync = ref.watch(patientsProvider);
    final patients = patientsAsync.valueOrNull ?? const <Patient>[];
    final selectedPatient = _resolveSelectedPatient(patients);

    return Container(
      padding: EdgeInsets.all(ResponsiveLayout.isMobile(context) ? 14 : 18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardSurface : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.borderSubtle : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.assignment_outlined,
                size: 18,
                color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Document Parameters',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: CertificateType.values.map((type) {
              return ChoiceChip(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                label: Text(type.displayName, style: const TextStyle(fontSize: 13)),
                selected: _selectedType == type,
                onSelected: (_) => setState(() => _selectedType = type),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          if (_selectedType == CertificateType.medicalCertificate) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.inputSurface
                    : AppColors.lightAppBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark
                      ? AppColors.borderSubtle
                      : AppColors.lightBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.bolt,
                        size: 15,
                        color: isDark ? AppColors.pending : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '1-Click Clinical Presets',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tap to prefill findings',
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textTertiary
                                : AppColors.lightTextMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.work_outline, size: 14),
                        label: const Text('Fit to Work', style: TextStyle(fontSize: 13)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        side: BorderSide(color: isDark ? AppColors.borderSubtle : AppColors.lightBorderActive),
                        onPressed: () => _applyPreset(
                          purpose: 'Employment & Return-to-Work Clearance',
                          findings:
                              'Physical examination shows patient is afebrile, alert, conscious, ambulatory, with stable vital signs. Cardiopulmonary findings are normal with no residual signs of communicable illness.',
                          recommendations:
                              'Fit to resume normal employment and occupational duties. Practice proper hand hygiene.',
                        ),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.school_outlined, size: 14),
                        label: const Text('School / P.E.', style: TextStyle(fontSize: 13)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        side: BorderSide(color: isDark ? AppColors.borderSubtle : AppColors.lightBorderActive),
                        onPressed: () => _applyPreset(
                          purpose: 'School Readmission & P.E. Clearance',
                          findings:
                              'Patient was evaluated and found physically fit with normal heart and lung sounds. No contraindications to academic or physical activity.',
                          recommendations:
                              'Cleared to attend classes and participate in physical education and sports activities.',
                        ),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.bed_outlined, size: 14),
                        label: const Text('Bed Rest (3 Days)', style: TextStyle(fontSize: 13)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        side: BorderSide(color: isDark ? AppColors.borderSubtle : AppColors.lightBorderActive),
                        onPressed: () => _applyPreset(
                          purpose: 'Medical Excusal / Sick Leave',
                          findings:
                              'Patient presented with acute upper respiratory tract symptoms, low-grade fever, and malaise. Physical evaluation indicates need for convalescence.',
                          recommendations:
                              'Home isolation, prescribed medication compliance, adequate hydration, and strict bed rest for 3 consecutive days.',
                          restDays: '3',
                        ),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.local_hospital_outlined, size: 14),
                        label: const Text('Referral Slip', style: TextStyle(fontSize: 13)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        side: BorderSide(color: isDark ? AppColors.borderSubtle : AppColors.lightBorderActive),
                        onPressed: () => _applyPreset(
                          purpose: 'Tertiary Level Evaluation & Diagnostic Work-up',
                          findings:
                              'Clinical findings warrant advanced diagnostic work-up and specialized medical management unavailable at the primary RHU tier.',
                          recommendations:
                              'Advised prompt transfer and clinical evaluation at the Provincial/District Hospital.',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'Target Patient',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          patientsAsync.when(
            skipLoadingOnReload: true,
            data: (patientsList) => AppSearchableDropdown<Patient>(
              label: 'Patient',
              hint: 'Search patient by name, ID, phone, or barangay...',
              value: _resolveSelectedPatient(patientsList),
              items: patientsList,
              itemLabel: (p) => '${p.fullName} (${p.id})',
              itemSubtitle: (p) =>
                  'Age: ${p.age ?? 'N/A'} • ${p.gender ?? ''} • Brgy. ${p.barangay ?? 'N/A'}',
              itemLeading: (p) => Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.inputSurface : AppColors.lightElevatedSurface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? AppColors.borderSubtle : AppColors.lightBorder,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  p.initials,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ),
              searchMatcher: (p, q) {
                final haystack = [
                  p.fullName,
                  p.id,
                  p.contactNumber ?? '',
                  p.barangay ?? '',
                  p.philHealthNumber ?? '',
                ].join(' ').toLowerCase();
                return haystack.contains(q);
              },
              onChanged: (p) {
                setState(() => _selectedPatientId = p?.id);
              },
            ),
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => AppErrorState(
              title: 'Patient list could not be loaded',
              error: error,
              onRetry: () => ref.invalidate(patientsProvider),
            ),
          ),
          if (selectedPatient != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.inputSurface : AppColors.lightAppBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? AppColors.borderSubtle : AppColors.lightBorderActive,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 15,
                    color: isDark ? AppColors.primaryEmerald : AppColors.primaryEmeraldDark,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Selected: ${selectedPatient.fullName} | Age ${selectedPatient.age ?? "—"} | ${selectedPatient.gender ?? "—"} | Brgy. ${selectedPatient.barangay ?? "Unspecified"}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _selectedPatientId = null),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('Change', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
          if (_selectedType == CertificateType.medicalCertificate) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _purposeController,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                labelText: 'Purpose',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.borderSubtle : AppColors.lightBorderActive,
                  ),
                ),
                hintText:
                    'e.g. Employment, School clearance, Legal, Sick leave',
                prefixIcon: const Icon(Icons.flag_outlined, size: 16),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _findingsController,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                labelText: 'Clinical Findings & Examination Observations',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.borderSubtle : AppColors.lightBorderActive,
                  ),
                ),
                hintText:
                    'e.g. Afebrile, BP 120/80 mmHg, clear breath sounds...',
                prefixIcon: const Icon(Icons.medical_services_outlined, size: 16),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _recommendationsController,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                labelText: 'Medical Recommendations & Plan',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.borderSubtle : AppColors.lightBorderActive,
                  ),
                ),
                hintText:
                    'e.g. Fit to work, rest for 3 days, avoid heavy lifting...',
                prefixIcon: const Icon(Icons.thumb_up_alt_outlined, size: 16),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _restDaysController,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                labelText: 'Recommended Rest Days (optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.borderSubtle : AppColors.lightBorderActive,
                  ),
                ),
                hintText: 'e.g. 3',
                prefixIcon: const Icon(Icons.hotel_outlined, size: 16),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent(
                    Theme.of(context).brightness == Brightness.dark,
                  ),
                  foregroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.textOnEmerald : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isGenerating || selectedPatient == null
                    ? null
                    : () => _generate(
                        context,
                        settings,
                        selectedPatient,
                        exportPdf: false,
                      ),
                icon: _isGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.print_outlined, size: 16),
                label: Text(
                  _isGenerating ? 'Generating...' : 'Generate & Print',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: BorderSide(
                    color: isDark ? AppColors.borderSubtle : AppColors.lightBorderActive,
                  ),
                ),
                onPressed: _isGenerating || selectedPatient == null
                    ? null
                    : () => _generate(
                        context,
                        settings,
                        selectedPatient,
                        exportPdf: true,
                      ),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                label: const Text(
                  'Export Official PDF',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLivePreviewCard(
    BuildContext context,
    bool isDark,
    SystemSettings? settings,
  ) {
    final user = ref.watch(currentUserProvider);
    final clinics = ref.watch(clinicsProvider).valueOrNull ?? const <Clinic>[];
    final patients =
        ref.watch(patientsProvider).valueOrNull ?? const <Patient>[];
    final selectedPatient = _resolveSelectedPatient(patients);

    final targetClinicId = selectedPatient?.clinicId ?? user?.clinicId;
    Clinic? matchedClinic;
    if (targetClinicId != null) {
      for (final c in clinics) {
        if (c.id == targetClinicId) {
          matchedClinic = c;
          break;
        }
      }
    }

    final clinicName = matchedClinic?.name.isNotEmpty == true
        ? matchedClinic!.name
        : (settings?.clinicName.isNotEmpty == true
              ? settings!.clinicName
              : 'Rural Health Unit');
    final clinicAddress = matchedClinic?.address?.isNotEmpty == true
        ? matchedClinic!.address!
        : (settings?.clinicAddress.isNotEmpty == true
              ? settings!.clinicAddress
              : 'Surigao del Sur');
    final municipalityLabel = matchedClinic?.municipality?.isNotEmpty == true
        ? matchedClinic!.municipality!.toUpperCase()
        : clinicAddress.toUpperCase();
    final signatoryName = user?.fullName.isNotEmpty == true
        ? user!.fullName
        : 'Attending Health Officer';
    final signatoryRole = user?.roleDisplayName ?? 'Health Officer';
    final licenseNo = user?.licenseNumber?.trim();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardSurface : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.borderSubtle : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.preview_outlined,
                size: 16,
                color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'LIVE DOCUMENT PREVIEW',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.8,
                  color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(width: 8),
              const Spacer(),
              // Long clinic names truncate instead of pushing the row wide.
              Flexible(
                flex: 4,
                child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.inputSurface : AppColors.lightElevatedSurface,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isDark ? AppColors.borderSubtle : AppColors.lightBorderActive,
                  ),
                ),
                child: Text(
                  'A4 Standard • $clinicName',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.modalSurface : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark ? AppColors.borderActive : AppColors.lightBorderActive,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Republic of the Philippines',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'DEPARTMENT OF HEALTH • $municipalityLabel',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  clinicName.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  clinicAddress,
                  style: TextStyle(
                    fontSize: 9,
                    color: isDark
                        ? AppColors.textMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 12),
                Divider(
                  thickness: 1.5,
                  color: isDark ? AppColors.border : Colors.grey.shade400,
                ),
                const SizedBox(height: 14),
                Text(
                  _selectedType == CertificateType.medicalCertificate
                      ? 'MEDICAL CERTIFICATE'
                      : 'PATIENT RECORD SUMMARY',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    decoration: TextDecoration.underline,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Date: ${DateFormat('MMMM d, yyyy').format(DateTime.now())}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'TO WHOM IT MAY CONCERN:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 12),
                if (selectedPatient == null)
                  Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(
                          Icons.touch_app_outlined,
                          size: 36,
                          color: isDark
                              ? AppColors.textMuted
                              : AppColors.lightTextMuted,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select a patient on the left to see live document preview with official certification text.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textMuted
                                : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'This is to certify that ${selectedPatient.fullName.toUpperCase()}, '
                      '${selectedPatient.age ?? "—"} years of age, ${selectedPatient.gender ?? "—"}, '
                      'resident of Barangay ${selectedPatient.barangay ?? clinicAddress}, '
                      'was clinically examined and attended to at this health facility on '
                      '${DateFormat('MMMM d, yyyy').format(DateTime.now())}.',
                      textAlign: TextAlign.justify,
                      style: const TextStyle(fontSize: 12, height: 1.6),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_selectedType == CertificateType.medicalCertificate) ...[
                    _buildPreviewRow(
                      'PURPOSE:',
                      _purposeController.text.trim().isEmpty
                          ? '[Specify Purpose]'
                          : _purposeController.text.trim(),
                    ),
                    const SizedBox(height: 10),
                    _buildPreviewRow(
                      'CLINICAL FINDINGS:',
                      _findingsController.text.trim().isEmpty
                          ? '[Specify Findings]'
                          : _findingsController.text.trim(),
                    ),
                    const SizedBox(height: 10),
                    _buildPreviewRow(
                      'RECOMMENDATIONS:',
                      _recommendationsController.text.trim().isEmpty
                          ? '[Specify Recommendations]'
                          : _recommendationsController.text.trim(),
                    ),
                    if (_restDaysController.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _buildPreviewRow(
                        'MEDICAL REST:',
                        'Patient is advised to observe ${_restDaysController.text.trim()} day(s) of bed rest for full recovery.',
                      ),
                    ],
                  ],
                  const SizedBox(height: 28),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 220,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            height: 38,
                            alignment: Alignment.bottomCenter,
                            child: const Text(
                              '[Digitally Signed / E-Signature]',
                              style: TextStyle(
                                fontSize: 9,
                                fontStyle: FontStyle.italic,
                                color: Colors.blueGrey,
                              ),
                            ),
                          ),
                          Container(
                            height: 1,
                            color: isDark
                                ? AppColors.borderActive
                                : Colors.black87,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            signatoryName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            signatoryRole,
                            style: const TextStyle(fontSize: 10),
                          ),
                          if (licenseNo != null && licenseNo.isNotEmpty)
                            Text(
                              'PRC License No. $licenseNo',
                              style: const TextStyle(fontSize: 9),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.inputSurface
                          : AppColors.lightAppBackground,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isDark ? AppColors.borderSubtle : AppColors.lightBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 13,
                          color: isDark ? AppColors.primaryEmerald : AppColors.primaryEmeraldDark,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Official $clinicName Record • RA 10173 Compliant • Valid without physical seal if digitally authenticated.',
                            style: TextStyle(
                              fontSize: 9,
                              color: isDark
                                  ? AppColors.textTertiary
                                  : AppColors.lightTextMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 11, height: 1.4)),
        ),
      ],
    );
  }

  Widget _buildArchiveTab(
    BuildContext context,
    bool isDark,
    AsyncValue<List<IssuedCertificate>> archiveAsync,
  ) {
    final query = _searchArchiveController.text.trim().toLowerCase();
    final currentUser = ref.watch(currentUserProvider);
    final canDelete = currentUser?.permissions.canDeletePatientRecords ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardSurface : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.borderSubtle : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchArchiveController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 11,
              ),
              hintText: 'Search archive by certificate ID, patient name, or purpose...',
              hintStyle: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.textTertiary : AppColors.lightTextMuted,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 18,
                color: isDark ? AppColors.textTertiary : AppColors.lightTextSecondary,
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
              suffixIcon: _searchArchiveController.text.isNotEmpty
                  ? IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () {
                        _searchArchiveController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              filled: true,
              fillColor: isDark ? AppColors.inputSurface : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDark ? AppColors.borderSubtle : AppColors.lightBorderActive,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDark ? AppColors.borderSubtle : AppColors.lightBorderActive,
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
          ),
          const SizedBox(height: 12),
          Expanded(
            child: archiveAsync.when(
              skipLoadingOnReload: true,
              data: (records) {
                final filtered = records.where((rec) {
                  if (query.isEmpty) return true;
                  return rec.patientName.toLowerCase().contains(query) ||
                      rec.patientId.toLowerCase().contains(query) ||
                      rec.id.toLowerCase().contains(query) ||
                      (rec.purpose ?? '').toLowerCase().contains(query) ||
                      rec.issuedBy.toLowerCase().contains(query);
                }).toList();

                if (filtered.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.inputSurface : AppColors.lightAppBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? AppColors.borderSubtle : AppColors.lightBorder,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.folder_open_outlined,
                            size: 32,
                            color: isDark ? AppColors.textTertiary : AppColors.lightTextMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            query.isEmpty
                                ? 'No certificates have been issued yet'
                                : 'No certificates found matching "$query"',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            query.isEmpty
                                ? 'Issued medical certificates and patient summaries will appear here.'
                                : 'Try clearing the search query to see all issued certificates.',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.inputSurface : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark
                              ? AppColors.borderSubtle
                              : AppColors.lightBorder,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Row: Type Badge + Cert ID + Action Buttons
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.inputSurface : AppColors.lightAppBackground,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isDark ? AppColors.borderSubtle : AppColors.lightBorderActive,
                                  ),
                                ),
                                child: Text(
                                  item.certificateType,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'ID: ${item.id}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? AppColors.textTertiary
                                      : AppColors.lightTextMuted,
                                ),
                              ),
                              const Spacer(),
                              // Actions
                              OutlinedButton.icon(
                                onPressed: () => _reissueArchivedCertificate(
                                  context,
                                  item,
                                  exportPdf: false,
                                ),
                                icon: const Icon(
                                  Icons.print_outlined,
                                  size: 14,
                                ),
                                label: const Text(
                                  'Print',
                                  style: TextStyle(fontSize: 13),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  side: BorderSide(color: isDark ? AppColors.borderSubtle : AppColors.lightBorderActive),
                                ),
                              ),
                              const SizedBox(width: 6),
                              OutlinedButton.icon(
                                onPressed: () => _reissueArchivedCertificate(
                                  context,
                                  item,
                                  exportPdf: true,
                                ),
                                icon: const Icon(
                                  Icons.picture_as_pdf_outlined,
                                  size: 14,
                                ),
                                label: const Text(
                                  'Export PDF',
                                  style: TextStyle(fontSize: 13),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  side: BorderSide(color: isDark ? AppColors.borderSubtle : AppColors.lightBorderActive),
                                ),
                              ),
                              if (canDelete) ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  tooltip: 'Delete Record',
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 16,
                                    color: AppColors.dangerRed,
                                  ),
                                  onPressed: () async {
                                    await ref
                                        .read(databaseProvider)
                                        .deleteIssuedCertificate(item.id);
                                    await ref
                                        .read(auditServiceProvider)
                                        .logAction(
                                          action: AuditAction.delete,
                                          entityType:
                                              AuditEntityTypes.certificate,
                                          entityId: item.id,
                                          details:
                                              'Deleted issued certificate record ${item.id} for ${item.patientName}',
                                        );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Deleted certificate ${item.id}.',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Patient Name & Details
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.cardSurface : AppColors.lightElevatedSurface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isDark ? AppColors.borderSubtle : AppColors.lightBorder,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  item.patientName.isNotEmpty
                                      ? item.patientName[0].toUpperCase()
                                      : 'P',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.textPrimary
                                        : AppColors.lightTextPrimary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.patientName,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                                      ),
                                    ),
                                    if (item.patientId.isNotEmpty)
                                      Text(
                                        'Patient ID: ${item.patientId}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontFeatures: const [FontFeature.tabularFigures()],
                                          color: isDark
                                              ? AppColors.textTertiary
                                              : AppColors.lightTextMuted,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // Purpose Highlight
                          if (item.purpose != null && item.purpose!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Purpose: ${item.purpose}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? AppColors.textSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],

                          // Metadata Footer: Issued By Doctor, License, 12h Timestamp
                          const SizedBox(height: 8),
                          Divider(
                            height: 1,
                            color: isDark ? AppColors.borderSubtle : AppColors.lightElevatedSurface,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 13,
                                color: isDark
                                    ? AppColors.textTertiary
                                    : AppColors.lightTextMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                item.issuedBy.isNotEmpty
                                    ? item.issuedBy
                                    : 'Attending Officer',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? AppColors.textSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                              if (item.licenseNumber != null &&
                                  item.licenseNumber!.isNotEmpty) ...[
                                Text(
                                  ' (PRC #${item.licenseNumber})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                    color: isDark
                                        ? AppColors.textTertiary
                                        : AppColors.lightTextMuted,
                                  ),
                                ),
                              ],
                              const Spacer(),
                              Icon(
                                Icons.access_time,
                                size: 12,
                                color: isDark
                                    ? AppColors.textTertiary
                                    : AppColors.lightTextMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat(
                                  'MMM d, yyyy · h:mm a',
                                ).format(item.issuedAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                  color: isDark
                                      ? AppColors.textSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => AppErrorState(
                title: 'Failed to load issued certificates',
                error: error,
                onRetry: () => ref.invalidate(issuedCertificatesProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reissueArchivedCertificate(
    BuildContext context,
    IssuedCertificate item, {
    required bool exportPdf,
  }) async {
    try {
      final service = ref.read(certificateServiceProvider);
      final db = ref.read(databaseProvider);
      final clinicSettings = await ref.read(systemSettingsProvider.future);

      var patient = await db.getPatientById(item.patientId);
      patient ??= Patient(
        id: item.patientId,
        firstName: item.patientName,
        lastName: '',
        clinicId: item.clinicId,
      );

      final certType = item.certificateType.toLowerCase().contains('summary')
          ? CertificateType.patientSummary
          : CertificateType.medicalCertificate;

      final pdfBytes = await service.generateCertificate(
        type: certType,
        patient: patient,
        settings: clinicSettings,
        purpose: item.purpose,
        findings: item.findings,
        recommendations: item.recommendations,
        restDays: item.restDays,
        issuedBy: item.issuedBy,
        licenseNumber: item.licenseNumber,
      );

      final filename = '${item.id}_${item.patientName}'.replaceAll(
        RegExp(r'[^A-Za-z0-9_-]'),
        '_',
      );

      if (exportPdf) {
        final path = await createFileExporter().saveBinaryFile(
          filename: '$filename.pdf',
          bytes: pdfBytes,
          dialogTitle: 'Export ${item.certificateType} as PDF',
        );
        if (path == null) return;
      } else {
        await service.printCertificate(pdfBytes, filename);
      }

      await ref
          .read(auditServiceProvider)
          .logAction(
            action: exportPdf ? AuditAction.export : AuditAction.print,
            entityType: AuditEntityTypes.certificate,
            entityId: item.id,
            details:
                '${exportPdf ? "Exported" : "Re-printed"} certificate ${item.id} for ${item.patientName}',
          );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              exportPdf
                  ? 'Certificate ${item.id} exported as PDF.'
                  : 'Certificate ${item.id} sent to print.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process certificate: $e')),
        );
      }
    }
  }

  Future<void> _generate(
    BuildContext context,
    SystemSettings? settings,
    Patient selectedPatient, {
    required bool exportPdf,
  }) async {
    setState(() => _isGenerating = true);
    try {
      final service = ref.read(certificateServiceProvider);
      final user = ref.read(currentUserProvider);
      final clinicSettings =
          settings ?? await ref.read(systemSettingsProvider.future);

      if (clinicSettings == null) {
        throw StateError('Clinic settings are unavailable.');
      }

      final restDays = int.tryParse(_restDaysController.text.trim());
      final purposeText = _purposeController.text.trim().isEmpty
          ? 'General Clearance'
          : _purposeController.text.trim();
      final findingsText = _findingsController.text.trim().isEmpty
          ? null
          : _findingsController.text.trim();
      final recommendationsText = _recommendationsController.text.trim().isEmpty
          ? null
          : _recommendationsController.text.trim();
      final issuerName = user?.fullName.isNotEmpty == true
          ? user!.fullName
          : 'Attending Health Officer';

      final pdfBytes = await service.generateCertificate(
        type: _selectedType,
        patient: selectedPatient,
        settings: clinicSettings,
        purpose: purposeText,
        findings: findingsText,
        recommendations: recommendationsText,
        restDays: restDays,
        issuedBy: issuerName,
        licenseNumber: user?.licenseNumber,
      );

      final certId =
          'CERT-${DateTime.now().year}-${const Uuid().v4().substring(0, 6).toUpperCase()}';
      final filename = '${_selectedType.displayName}_${selectedPatient.id}'
          .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

      if (exportPdf) {
        final path = await createFileExporter().saveBinaryFile(
          filename: '$filename.pdf',
          bytes: pdfBytes,
          dialogTitle: 'Export ${_selectedType.displayName} as PDF',
        );
        if (path == null) return;
      } else {
        await service.printCertificate(pdfBytes, filename);
      }

      final newRecord = IssuedCertificate(
        id: certId,
        patientId: selectedPatient.id,
        patientName: selectedPatient.fullName,
        certificateType: _selectedType.displayName,
        purpose: purposeText,
        findings: findingsText,
        recommendations: recommendationsText,
        restDays: restDays,
        issuedAt: DateTime.now(),
        issuedBy: issuerName,
        licenseNumber: user?.licenseNumber,
        clinicId: selectedPatient.clinicId ?? user?.clinicId,
      );

      await ref.read(databaseProvider).insertIssuedCertificate(newRecord);
      await ref
          .read(auditServiceProvider)
          .logAction(
            action: exportPdf ? AuditAction.export : AuditAction.print,
            entityType: AuditEntityTypes.certificate,
            entityId: certId,
            details:
                'Issued ${_selectedType.displayName} ($certId) for ${selectedPatient.fullName}',
          );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              exportPdf
                  ? '${_selectedType.displayName} ($certId) exported and recorded.'
                  : '${_selectedType.displayName} ($certId) sent to print and recorded.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate certificate: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
}
