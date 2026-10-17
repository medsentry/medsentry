import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/certificate_service.dart';
import '../utils/file_exporter/file_exporter.dart';
import '../widgets/app_card.dart';
import '../widgets/app_form_dialog.dart';
import '../widgets/layout/responsive_layout.dart';
import '../widgets/loading_state.dart';

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
      maxWidth: 1320,
      padding: ResponsiveLayout.pagePadding(context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final hasBoundedHeight = constraints.maxHeight.isFinite;
          final tabView = TabBarView(
            controller: _tabController,
            children: [
              _buildIssuanceTab(context, isDark),
              _buildArchiveTab(context, isDark, archiveAsync),
            ],
          );

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
                          'Official Certificates & Medical Clearances',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.textPrimary : null,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Generate DOH-compliant medical certificates, return-to-work clearances, and patient summaries.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: isDark
                                        ? AppColors.textSecondary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.68),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: AppColors.primaryEmerald,
                unselectedLabelColor: isDark
                    ? AppColors.textSecondary
                    : AppColors.lightTextSecondary,
                indicatorColor: AppColors.primaryEmerald,
                tabs: [
                  const Tab(
                    icon: Icon(Icons.edit_document, size: 18),
                    child: Text('Issue Certificate & Live Preview'),
                  ),
                  Tab(
                    icon: const Icon(Icons.history_edu, size: 18),
                    child: Text('Issued Certificates Registry ($archiveCount)'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (hasBoundedHeight)
                Expanded(child: tabView)
              else
                SizedBox(height: 760, child: tabView),
            ],
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            child: _buildCertificateForm(context, isDark, settings),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            child: _buildLivePreviewCard(context, isDark, settings),
          ),
        ),
      ],
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

    return AppCard(
      padding: EdgeInsets.all(ResponsiveLayout.isMobile(context) ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.assignment_outlined,
                size: 20,
                color: AppColors.primaryEmerald,
              ),
              const SizedBox(width: 8),
              Text(
                'Document Parameters',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: CertificateType.values.map((type) {
              return ChoiceChip(
                label: Text(type.displayName),
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
                    : AppColors.primaryEmerald.withValues(alpha: 0.05),
                borderRadius: AppRadius.roundedMd,
                border: Border.all(
                  color: isDark
                      ? AppColors.borderSubtle
                      : AppColors.primaryEmerald.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt, size: 16, color: Colors.amber),
                      const SizedBox(width: 6),
                      const Text(
                        '1-Click Clinical Presets',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Tap to prefill findings',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.textMuted
                              : AppColors.lightTextMuted,
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
                        label: const Text(
                          'Fit to Work',
                          style: TextStyle(fontSize: 12),
                        ),
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
                        label: const Text(
                          'School / P.E.',
                          style: TextStyle(fontSize: 12),
                        ),
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
                        label: const Text(
                          'Bed Rest (3 Days)',
                          style: TextStyle(fontSize: 12),
                        ),
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
                        avatar:
                            const Icon(Icons.local_hospital_outlined, size: 14),
                        label: const Text(
                          'Referral Slip',
                          style: TextStyle(fontSize: 12),
                        ),
                        onPressed: () => _applyPreset(
                          purpose:
                              'Tertiary Level Evaluation & Diagnostic Work-up',
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
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          patientsAsync.when(
            data: (patientsList) => AppSearchableDropdown<Patient>(
              label: 'Patient',
              hint: 'Search patient by name, ID, phone, or barangay...',
              value: _resolveSelectedPatient(patientsList),
              items: patientsList,
              itemLabel: (p) => '${p.fullName} (${p.id})',
              itemSubtitle: (p) =>
                  'Age: ${p.age ?? 'N/A'} • ${p.gender ?? ''} • Brgy. ${p.barangay ?? 'N/A'}',
              itemLeading: (p) => CircleAvatar(
                radius: 18,
                backgroundColor:
                    AppColors.primaryEmerald.withValues(alpha: 0.15),
                child: Text(
                  p.initials,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryEmerald,
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
                color: isDark
                    ? AppColors.cardSurface
                    : Colors.blue.shade50.withValues(alpha: 0.5),
                borderRadius: AppRadius.roundedSm,
                border: Border.all(
                  color: isDark ? AppColors.borderSubtle : Colors.blue.shade200,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_pin, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Selected: ${selectedPatient.fullName} | Age ${selectedPatient.age ?? 'N/A'} | ${selectedPatient.gender ?? 'N/A'} | Brgy. ${selectedPatient.barangay ?? 'Unspecified'}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _selectedPatientId = null),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('Change', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          ],
          if (_selectedType == CertificateType.medicalCertificate) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _purposeController,
              decoration: const InputDecoration(
                labelText: 'Purpose',
                border: OutlineInputBorder(),
                hintText:
                    'e.g. Employment, School clearance, Legal, Sick leave',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _findingsController,
              decoration: const InputDecoration(
                labelText: 'Clinical Findings & Examination Observations',
                border: OutlineInputBorder(),
                hintText:
                    'e.g. Afebrile, BP 120/80 mmHg, clear breath sounds...',
                prefixIcon: Icon(Icons.medical_services_outlined),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _recommendationsController,
              decoration: const InputDecoration(
                labelText: 'Medical Recommendations & Plan',
                border: OutlineInputBorder(),
                hintText:
                    'e.g. Fit to work, rest for 3 days, avoid heavy lifting...',
                prefixIcon: Icon(Icons.thumb_up_alt_outlined),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _restDaysController,
              decoration: const InputDecoration(
                labelText: 'Recommended Rest Days (optional)',
                border: OutlineInputBorder(),
                hintText: 'e.g. 3',
                prefixIcon: Icon(Icons.hotel_outlined),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.icon(
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
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.print_outlined),
                label: Text(
                  _isGenerating ? 'Generating...' : 'Generate & Print',
                ),
              ),
              OutlinedButton.icon(
                onPressed: _isGenerating || selectedPatient == null
                    ? null
                    : () => _generate(
                          context,
                          settings,
                          selectedPatient,
                          exportPdf: true,
                        ),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Export Official PDF'),
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

    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.preview_outlined,
                size: 18,
                color: AppColors.primaryEmerald,
              ),
              const SizedBox(width: 8),
              const Text(
                'LIVE DOCUMENT PREVIEW',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 1.1,
                  color: AppColors.primaryEmerald,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: AppRadius.roundedSm,
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'A4 Standard • $clinicName',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: isDark ? AppColors.modalSurface : Colors.white,
              borderRadius: AppRadius.roundedMd,
              border: Border.all(
                color: isDark ? AppColors.borderActive : Colors.grey.shade300,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
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
                          ? AppColors.appBackground
                          : Colors.grey.shade100,
                      borderRadius: AppRadius.roundedSm,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          size: 14,
                          color: AppColors.primaryEmerald,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Official $clinicName Record • RA 10173 Compliant • Valid without physical seal if digitally authenticated.',
                            style: TextStyle(
                              fontSize: 9,
                              color: isDark
                                  ? AppColors.textMuted
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
          child: Text(
            value,
            style: const TextStyle(fontSize: 11, height: 1.4),
          ),
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

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchArchiveController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText:
                        'Search archive by certificate ID, patient name, or purpose...',
                    border: const OutlineInputBorder(),
                    suffixIcon: _searchArchiveController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchArchiveController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: archiveAsync.when(
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
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.folder_off_outlined,
                          size: 48,
                          color: isDark
                              ? AppColors.textMuted
                              : AppColors.lightTextMuted,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          query.isEmpty
                              ? 'No certificates have been issued yet.'
                              : 'No certificates found matching "$query"',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.textMuted
                                : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            AppColors.primaryEmerald.withValues(alpha: 0.15),
                        child: const Icon(
                          Icons.description_outlined,
                          color: AppColors.primaryEmerald,
                          size: 20,
                        ),
                      ),
                      title: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            item.patientName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.inputSurface
                                  : Colors.grey.shade200,
                              borderRadius: AppRadius.roundedSm,
                            ),
                            child: Text(
                              item.id,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        '${item.certificateType} • Purpose: ${item.purpose} • Issued on ${DateFormat('MMM d, yyyy h:mm a').format(item.issuedAt)} by ${item.issuedBy}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textMuted
                              : AppColors.lightTextMuted,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Re-print Certificate',
                            icon: const Icon(Icons.print_outlined, size: 20),
                            onPressed: () => _reissueArchivedCertificate(
                              context,
                              item,
                              exportPdf: false,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Export PDF',
                            icon: const Icon(
                              Icons.picture_as_pdf_outlined,
                              size: 20,
                            ),
                            onPressed: () => _reissueArchivedCertificate(
                              context,
                              item,
                              exportPdf: true,
                            ),
                          ),
                          if (canDelete)
                            IconButton(
                              tooltip: 'Delete Record',
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: AppColors.dangerRed,
                              ),
                              onPressed: () async {
                                await ref
                                    .read(databaseProvider)
                                    .deleteIssuedCertificate(item.id);
                                await ref.read(auditServiceProvider).logAction(
                                      action: AuditAction.delete,
                                      entityType: AuditEntityTypes.certificate,
                                      entityId: item.id,
                                      details:
                                          'Deleted issued certificate record ${item.id} for ${item.patientName}',
                                    );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
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

      final filename = '${item.id}_${item.patientName}'
          .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

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

      await ref.read(auditServiceProvider).logAction(
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
      final recommendationsText =
          _recommendationsController.text.trim().isEmpty
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
      await ref.read(auditServiceProvider).logAction(
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
