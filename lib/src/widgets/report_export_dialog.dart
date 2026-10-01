import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

import '../models/generated_report.dart';
import '../models/system_settings.dart';
import '../providers/providers.dart';
import '../services/app_notification.dart';
import '../services/report_pdf_service.dart';
import '../services/report_service.dart';
import '../utils/context_extensions.dart';
import '../utils/report_date_filter.dart';

/// Modal dialog providing interactive preview, DOH/LGU official formatting,
/// and native "Save As... (Choose Location)" PDF export workflow.
class ReportExportDialog extends ConsumerStatefulWidget {
  final String initialReportType;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  const ReportExportDialog({
    super.key,
    required this.initialReportType,
    this.initialStartDate,
    this.initialEndDate,
  });

  /// Displays the interactive PDF export and preview dialog.
  static Future<void> show(
    BuildContext context, {
    required String reportType,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ReportExportDialog(
        initialReportType: reportType,
        initialStartDate: startDate,
        initialEndDate: endDate,
      ),
    );
  }

  @override
  ConsumerState<ReportExportDialog> createState() => _ReportExportDialogState();
}

class _ReportExportDialogState extends ConsumerState<ReportExportDialog>
    with SingleTickerProviderStateMixin {
  late String _selectedReportType;
  late DateTime _startDate;
  late DateTime _endDate;
  late TextEditingController _filenameController;
  late TextEditingController _preparedByNameController;
  late TextEditingController _preparedByRoleController;
  late TextEditingController _approvedByNameController;
  late TextEditingController _approvedByRoleController;

  final ReportPdfService _pdfService = const ReportPdfService();

  bool _isPreviewMode = false;
  bool _isSaving = false;
  Uint8List? _cachedPdfBytes;

  static const List<String> _availableReportTypes = [
    'Daily Consultation Report',
    'Disease Surveillance',
    'Medication Prescriptions',
    'Patient Statistics',
    'DOH Report',
    'FHSIS Export',
  ];

  @override
  void initState() {
    super.initState();
    _selectedReportType = widget.initialReportType;

    final now = DateTime.now();
    _startDate = widget.initialStartDate ?? DateTime(now.year, now.month, 1);
    _endDate = widget.initialEndDate ?? now;

    final currentUser = ref.read(currentUserProvider);
    final staffName = currentUser?.fullName ?? 'RHU Health Staff';
    final staffRole = currentUser?.roleDisplay ?? 'Public Health Personnel';

    _preparedByNameController = TextEditingController(text: staffName);
    _preparedByRoleController = TextEditingController(text: staffRole);
    _approvedByNameController =
        TextEditingController(text: 'Dr. Maria Santos, MD');
    _approvedByRoleController = TextEditingController(
      text: 'Municipal Health Officer (MHO) / Medical Officer IV',
    );

    _filenameController = TextEditingController();
    _updateDefaultFilename();
  }

  @override
  void dispose() {
    _filenameController.dispose();
    _preparedByNameController.dispose();
    _preparedByRoleController.dispose();
    _approvedByNameController.dispose();
    _approvedByRoleController.dispose();
    super.dispose();
  }

  void _updateDefaultFilename() {
    final settings = ref.read(systemSettingsProvider).valueOrNull ??
        const SystemSettings();
    final facility = settings.clinicName.isNotEmpty
        ? settings.clinicName
        : 'CantilanRHU';

    final generatedName = ReportPdfService.buildDefaultFileName(
      reportType: _selectedReportType,
      facilityName: facility,
      date: _endDate,
    );

    _filenameController.text = generatedName;
  }

  void _invalidatePdfCache() {
    setState(() {
      _cachedPdfBytes = null;
    });
  }

  Future<Uint8List> _generatePdfBytes() async {
    if (_cachedPdfBytes != null) return _cachedPdfBytes!;

    final db = ref.read(databaseProvider);
    final reportService = ReportService(db);
    final settings =
        (await db.getSystemSettings());

    final reportData = await reportService.generateRangeReport(
      reportType: _selectedReportType,
      startDate: _startDate,
      endDate: _endDate,
      grouping: ReportGrouping.day,
    );

    final bytes = await _pdfService.generateReportPdf(
      reportType: _selectedReportType,
      startDate: _startDate,
      endDate: _endDate,
      reportData: reportData,
      settings: settings,
      preparedByName: _preparedByNameController.text.trim().isNotEmpty
          ? _preparedByNameController.text.trim()
          : 'RHU Healthcare Staff',
      preparedByRole: _preparedByRoleController.text.trim().isNotEmpty
          ? _preparedByRoleController.text.trim()
          : 'Staff Nurse',
      approvedByName: _approvedByNameController.text.trim().isNotEmpty
          ? _approvedByNameController.text.trim()
          : 'Municipal Health Officer',
      approvedByRole: _approvedByRoleController.text.trim().isNotEmpty
          ? _approvedByRoleController.text.trim()
          : 'Municipal Health Officer (MHO)',
    );

    _cachedPdfBytes = bytes;
    return bytes;
  }

  Future<void> _handleSaveAsPdf() async {
    setState(() => _isSaving = true);
    try {
      final bytes = await _generatePdfBytes();
      var filename = _filenameController.text.trim();
      if (filename.isEmpty) {
        _updateDefaultFilename();
        filename = _filenameController.text.trim();
      }
      if (!filename.toLowerCase().endsWith('.pdf')) {
        filename = '$filename.pdf';
      }

      final reportService = ReportService(ref.read(databaseProvider));
      final savedPath = await reportService.exportReportToPdf(
        pdfBytes: bytes,
        filename: filename,
        dialogTitle: 'Save MedSentry Official PDF Report',
      );

      if (savedPath == null) {
        // User cancelled the native save dialog
        if (mounted) setState(() => _isSaving = false);
        return;
      }

      // Record in generated reports database history
      final now = DateTime.now();
      final reportId = const Uuid().v4();
      final title = '$_selectedReportType - ${DateFormat('yyyy-MM-dd').format(now)}';
      final newReport = GeneratedReport(
        id: reportId,
        title: title,
        type: _selectedReportType,
        generatedAt: now,
        startDate: _startDate,
        endDate: _endDate,
        filePath: savedPath,
      );

      await ref.read(databaseProvider).insertGeneratedReport(newReport);
      ref.invalidate(generatedReportsProvider);

      if (mounted) {
        Navigator.of(context).pop();

        AppNotification.success(
          title: 'Report Exported Successfully',
          message: 'Saved as $filename',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report saved to: $savedPath'),
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Open PDF',
              textColor: Colors.amberAccent,
              onPressed: () => reportService.openExportedReport(savedPath),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppNotification.error(
          title: 'Export Failed',
          message: 'Could not export PDF report: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleDirectPrint() async {
    try {
      final bytes = await _generatePdfBytes();
      var filename = _filenameController.text.trim();
      if (!filename.toLowerCase().endsWith('.pdf')) {
        filename = '$filename.pdf';
      }
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: filename,
      );
    } catch (e) {
      if (mounted) {
        AppNotification.error(
          title: 'Print Error',
          message: 'Unable to send report to printer: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 720;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 960,
          maxHeight: size.height * 0.92,
        ),
        child: Column(
          children: [
            // Modal Header
            _buildModalHeader(context),

            // Mode Selector Tabs (Configuration vs Live Preview)
            _buildModeTabBar(context),

            // Modal Body
            Expanded(
              child: _isPreviewMode
                  ? _buildPreviewTab(context)
                  : _buildConfigurationTab(context, isCompact),
            ),

            // Bottom Action Footer
            _buildModalFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildModalHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.semanticColors.info.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.picture_as_pdf_outlined,
              color: context.semanticColors.info,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Export Official DOH / RHU Report (PDF)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Client-side offline generation with official headers, FHSIS compliance, and custom save location.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTabBar(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: false,
                label: Text('Report Settings'),
                icon: Icon(Icons.tune_outlined, size: 16),
              ),
              ButtonSegment<bool>(
                value: true,
                label: Text('Interactive Live Preview'),
                icon: Icon(Icons.remove_red_eye_outlined, size: 16),
              ),
            ],
            selected: {_isPreviewMode},
            onSelectionChanged: (selected) {
              setState(() {
                _isPreviewMode = selected.first;
              });
            },
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
          ),
          const Spacer(),
          if (_isPreviewMode) ...[
            TextButton.icon(
              onPressed: () {
                _invalidatePdfCache();
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh Preview'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConfigurationTab(BuildContext context, bool isCompact) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Report Type Selection
          Text(
            '1. SELECT REPORT TYPE',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: context.semanticColors.info,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedReportType,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.assignment_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            items: _availableReportTypes
                .map((type) => DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    ))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedReportType = val;
                  _updateDefaultFilename();
                  _invalidatePdfCache();
                });
              }
            },
          ),
          const SizedBox(height: 18),

          // 2. Reporting Period Date Range
          Text(
            '2. REPORTING PERIOD / DATE RANGE',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: context.semanticColors.info,
            ),
          ),
          const SizedBox(height: 8),
          _buildDateRangeSelector(context),
          const SizedBox(height: 18),

          // 3. Document Metadata & Signatures
          Text(
            '3. DOCUMENT SIGN-OFFS & OFFICIAL AUDIT BLOCK',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: context.semanticColors.info,
            ),
          ),
          const SizedBox(height: 8),
          isCompact
              ? Column(
                  children: [
                    _buildSignOffInputs(
                      title: 'Prepared By (Staff / Nurse)',
                      nameController: _preparedByNameController,
                      roleController: _preparedByRoleController,
                      icon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: 12),
                    _buildSignOffInputs(
                      title: 'Approved By (Municipal Health Officer)',
                      nameController: _approvedByNameController,
                      roleController: _approvedByRoleController,
                      icon: Icons.verified_user_outlined,
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildSignOffInputs(
                        title: 'Prepared By (Staff / Nurse)',
                        nameController: _preparedByNameController,
                        roleController: _preparedByRoleController,
                        icon: Icons.badge_outlined,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildSignOffInputs(
                        title: 'Approved By (Municipal Health Officer)',
                        nameController: _approvedByNameController,
                        roleController: _approvedByRoleController,
                        icon: Icons.verified_user_outlined,
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 18),

          // 4. File Naming & Target Location Info
          Text(
            '4. FILE NAME & SAVE DESTINATION',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: context.semanticColors.info,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _filenameController,
            decoration: InputDecoration(
              labelText: 'Target File Name',
              hintText: 'e.g. MedSentry_Report_2026-10-01.pdf',
              prefixIcon: const Icon(Icons.insert_drive_file_outlined),
              suffixIcon: IconButton(
                icon: const Icon(Icons.restore_outlined),
                tooltip: 'Reset to standard naming convention',
                onPressed: _updateDefaultFilename,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            onChanged: (_) => _invalidatePdfCache(),
          ),
          const SizedBox(height: 10),

          // Interactive native location callout banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.semanticColors.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: context.semanticColors.info.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.folder_open_outlined,
                  size: 20,
                  color: context.semanticColors.info,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Interactive Save Location Selection',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.semanticColors.info,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'When you tap "Save As PDF...", your operating system\'s native Save Dialog opens. You can select your preferred local directory (Desktop, Documents, Flash Drive, or Downloads) without silent background saving.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeSelector(BuildContext context) {
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime(2020),
                    lastDate: now,
                  );
                  if (picked != null) {
                    setState(() {
                      _startDate = picked;
                      if (_endDate.isBefore(_startDate)) {
                        _endDate = _startDate;
                      }
                      _updateDefaultFilename();
                      _invalidatePdfCache();
                    });
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Start Date',
                    prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  child: Text(DateFormat('yyyy-MM-dd').format(_startDate)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _endDate,
                    firstDate: _startDate,
                    lastDate: now,
                  );
                  if (picked != null) {
                    setState(() {
                      _endDate = picked;
                      _updateDefaultFilename();
                      _invalidatePdfCache();
                    });
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'End Date',
                    prefixIcon: const Icon(Icons.event_available_outlined, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  child: Text(DateFormat('yyyy-MM-dd').format(_endDate)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Quick Presets
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _buildPresetChip('Today', () {
              final today = DateTime(now.year, now.month, now.day);
              setState(() {
                _startDate = today;
                _endDate = today;
                _updateDefaultFilename();
                _invalidatePdfCache();
              });
            }),
            _buildPresetChip('Last 7 Days', () {
              setState(() {
                _startDate = now.subtract(const Duration(days: 7));
                _endDate = now;
                _updateDefaultFilename();
                _invalidatePdfCache();
              });
            }),
            _buildPresetChip('This Month', () {
              setState(() {
                _startDate = DateTime(now.year, now.month, 1);
                _endDate = now;
                _updateDefaultFilename();
                _invalidatePdfCache();
              });
            }),
            _buildPresetChip('This Year', () {
              setState(() {
                _startDate = DateTime(now.year, 1, 1);
                _endDate = now;
                _updateDefaultFilename();
                _invalidatePdfCache();
              });
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onSelected) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      onPressed: onSelected,
    );
  }

  Widget _buildSignOffInputs({
    required String title,
    required TextEditingController nameController,
    required TextEditingController roleController,
    required IconData icon,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            onChanged: (_) => _invalidatePdfCache(),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: roleController,
            decoration: const InputDecoration(
              labelText: 'Designation / Title',
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            onChanged: (_) => _invalidatePdfCache(),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewTab(BuildContext context) {
    return PdfPreview(
      build: (format) => _generatePdfBytes(),
      allowPrinting: false, // We provide unified action buttons in modal footer
      allowSharing: false,
      canChangePageFormat: false,
      canChangeOrientation: false,
      pdfFileName: _filenameController.text.trim(),
      loadingWidget: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Generating official PDF report...'),
          ],
        ),
      ),
      onError: (context, error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 36, color: Colors.red),
              const SizedBox(height: 10),
              Text('Error rendering PDF: $error'),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _invalidatePdfCache,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalFooter(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _isSaving ? null : _handleDirectPrint,
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('Print Document'),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: _isSaving ? null : _handleSaveAsPdf,
            style: FilledButton.styleFrom(
              backgroundColor: context.semanticColors.info,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Icon(Icons.file_download_outlined, size: 18),
            label: Text(
              _isSaving ? 'Exporting...' : 'Save As PDF... (Choose Location)',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
