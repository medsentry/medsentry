import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/certificate_service.dart';
import '../utils/file_exporter/file_exporter.dart';
import '../widgets/app_form_dialog.dart';
import '../widgets/layout/responsive_layout.dart';
import '../widgets/loading_state.dart';

class CertificatesScreen extends ConsumerStatefulWidget {
  const CertificatesScreen({super.key});

  @override
  ConsumerState<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends ConsumerState<CertificatesScreen> {
  CertificateType _selectedType = CertificateType.medicalCertificate;
  Patient? _selectedPatient;
  final _purposeController = TextEditingController();
  final _findingsController = TextEditingController();
  final _recommendationsController = TextEditingController();
  final _restDaysController = TextEditingController();
  bool _isGenerating = false;

  @override
  void dispose() {
    _purposeController.dispose();
    _findingsController.dispose();
    _recommendationsController.dispose();
    _restDaysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(patientsProvider);
    final settingsAsync = ref.watch(systemSettingsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: ResponsiveContentContainer(
        maxWidth: 960,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Certificate Generation',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Generate medical certificates and patient record summaries.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.68),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Document Type',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: CertificateType.values.map((type) {
                        return ChoiceChip(
                          label: Text(type.displayName),
                          selected: _selectedType == type,
                          onSelected: (_) =>
                              setState(() => _selectedType = type),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Select Patient',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    patientsAsync.when(
                      data: (patients) => AppSearchableDropdown<Patient>(
                        label: 'Patient',
                        hint:
                            'Search patient by name, ID, phone, or barangay...',
                        value: _selectedPatient,
                        items: patients,
                        itemLabel: (p) => '${p.fullName} (${p.id})',
                        itemSubtitle: (p) =>
                            'Age: ${p.age ?? 'N/A'} • ${p.gender ?? ''} • Brgy. ${p.barangay ?? 'N/A'}',
                        itemLeading: (p) => CircleAvatar(
                          radius: 18,
                          child: Text(
                            p.initials,
                            style: const TextStyle(fontSize: 12),
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
                          setState(() => _selectedPatient = p);
                        },
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (error, _) => AppErrorState(
                        title: 'Patient list could not be loaded',
                        error: error,
                        onRetry: () => ref.invalidate(patientsProvider),
                      ),
                    ),
                    if (_selectedType ==
                        CertificateType.medicalCertificate) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _purposeController,
                        decoration: const InputDecoration(
                          labelText: 'Purpose',
                          border: OutlineInputBorder(),
                          hintText: 'e.g. Employment, School clearance',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _findingsController,
                        decoration: const InputDecoration(
                          labelText: 'Clinical Findings',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _recommendationsController,
                        decoration: const InputDecoration(
                          labelText: 'Recommendations',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _restDaysController,
                        decoration: const InputDecoration(
                          labelText: 'Rest Days (optional)',
                          border: OutlineInputBorder(),
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
                          onPressed: _isGenerating || _selectedPatient == null
                              ? null
                              : () => _generate(
                                  context,
                                  settingsAsync.valueOrNull,
                                  exportPdf: false,
                                ),
                          icon: _isGenerating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.print_outlined),
                          label: Text(
                            _isGenerating
                                ? 'Generating...'
                                : 'Generate & Print',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _isGenerating || _selectedPatient == null
                              ? null
                              : () => _generate(
                                  context,
                                  settingsAsync.valueOrNull,
                                  exportPdf: true,
                                ),
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('Export PDF'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generate(
    BuildContext context,
    SystemSettings? settings, {
    required bool exportPdf,
  }) async {
    if (_selectedPatient == null) return;

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

      final pdfBytes = await service.generateCertificate(
        type: _selectedType,
        patient: _selectedPatient!,
        settings: clinicSettings,
        purpose: _purposeController.text.trim().isEmpty
            ? null
            : _purposeController.text.trim(),
        findings: _findingsController.text.trim().isEmpty
            ? null
            : _findingsController.text.trim(),
        recommendations: _recommendationsController.text.trim().isEmpty
            ? null
            : _recommendationsController.text.trim(),
        restDays: restDays,
        issuedBy: user?.fullName,
      );

      final filename = '${_selectedType.displayName}_${_selectedPatient!.id}'
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

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              exportPdf
                  ? '${_selectedType.displayName} exported as PDF.'
                  : '${_selectedType.displayName} sent to print.',
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
