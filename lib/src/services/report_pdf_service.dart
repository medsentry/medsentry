import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/models.dart';
import '../utils/logo_utils.dart';

/// Service responsible for client-side, 100% offline generation of official
/// Philippine DOH / LGU Rural Health Unit (RHU) PDF Reports compliant with
/// DOH administrative guidelines, FHSIS standards, and RA 10173 (Data Privacy Act).
class ReportPdfService {
  const ReportPdfService();

  /// Generates the complete official PDF document bytes completely offline.
  Future<Uint8List> generateReportPdf({
    required String reportType,
    required DateTime startDate,
    required DateTime endDate,
    required Map<String, dynamic> reportData,
    required SystemSettings settings,
    required String preparedByName,
    required String preparedByRole,
    required String approvedByName,
    String approvedByRole = 'Municipal Health Officer (MHO) / Medical Officer IV',
  }) async {
    if (reportType != 'Patient Statistics') {
      throw ArgumentError.value(reportType, 'reportType', 'Unsupported report');
    }

    final pdf = pw.Document(
      title: 'MedSentry - $reportType',
      author: 'MedSentry RHU Healthcare System',
      creator: 'MedSentry Health Information System',
      subject: 'Official RHU Health Record - DOH / LGU Compliance',
    );

    final generatedAt = DateTime.now();
    final logoBytes = decodeLogoDataUri(settings.logoDataUri);
    final summary = (reportData['summary'] as Map<String, dynamic>?) ?? {};
    final patientRecords =
        (reportData['patient_records'] as List<dynamic>?) ?? [];
    final patientsByGender =
        (reportData['patients_by_gender'] as Map<String, dynamic>?) ?? {};
    final patientsByCategory =
        (reportData['patients_by_category'] as Map<String, dynamic>?) ?? {};

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
        header: (pw.Context context) {
          if (context.pageNumber == 1) {
            return _buildFirstPageHeader(settings, logoBytes: logoBytes);
          } else {
            return _buildRunningHeader(
              settings: settings,
              reportType: reportType,
              startDate: startDate,
              endDate: endDate,
              logoBytes: logoBytes,
            );
          }
        },
        footer: (pw.Context context) => _buildPageFooter(context, settings),
        build: (pw.Context context) {
          return [
            // Metadata Block
            _buildMetadataBlock(
              reportType: reportType,
              startDate: startDate,
              endDate: endDate,
              settings: settings,
              preparedByName: preparedByName,
              preparedByRole: preparedByRole,
              generatedAt: generatedAt,
            ),
            pw.SizedBox(height: 14),

            // Summary Callout Cards
            _buildSummaryCalloutCards(summary),
            pw.SizedBox(height: 16),

            // Report Body Content Based on Type
            ..._buildReportBody(
              patientRecords: patientRecords,
              patientsByGender: patientsByGender,
              patientsByCategory: patientsByCategory,
            ),

            pw.SizedBox(height: 24),

            // Official Sign-Off Block
            _buildSignOffBlock(
              preparedByName: preparedByName,
              preparedByRole: preparedByRole,
              approvedByName: approvedByName,
              approvedByRole: approvedByRole,
              clinicName: settings.clinicName,
              date: generatedAt,
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // ==========================================
  // HEADER FORMATTING
  // ==========================================

  pw.Widget _buildFirstPageHeader(
    SystemSettings settings, {
    Uint8List? logoBytes,
  }) {
    final province = settings.province.isNotEmpty
        ? settings.province
        : 'Surigao del Sur';
    final municipality = settings.municipality.isNotEmpty
        ? settings.municipality
        : 'Municipality';

    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            // Left DOH / LGU Seal
            _buildDohSeal(),

            // Centered Official Heading
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'REPUBLIC OF THE PHILIPPINES',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.2,
                      color: PdfColors.blueGrey800,
                    ),
                  ),
                  pw.Text(
                    'DEPARTMENT OF HEALTH | CENTER FOR HEALTH DEVELOPMENT',
                    style: const pw.TextStyle(
                      fontSize: 7.5,
                      color: PdfColors.blueGrey700,
                    ),
                  ),
                  pw.SizedBox(height: 1),
                  pw.Text(
                    'Province of $province | Municipality of $municipality',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey900,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    settings.clinicName.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 12.5,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.5,
                      color: PdfColors.teal900,
                    ),
                  ),
                  if (settings.clinicAddress.isNotEmpty ||
                      settings.clinicContact.isNotEmpty)
                    pw.Text(
                      [
                        if (settings.clinicAddress.isNotEmpty)
                          settings.clinicAddress,
                        if (settings.clinicContact.isNotEmpty)
                          'Contact: ${settings.clinicContact}',
                      ].join(' | '),
                      style: const pw.TextStyle(
                        fontSize: 7.5,
                        color: PdfColors.blueGrey600,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                ],
              ),
            ),

            // Right MedSentry Healthcare MIS Crest
            _buildMedSentrySeal(logoBytes),
          ],
        ),
        pw.SizedBox(height: 8),

        // Double Horizontal Divider
        pw.Container(
          height: 2.2,
          color: PdfColors.teal800,
        ),
        pw.SizedBox(height: 1.5),
        pw.Container(
          height: 0.8,
          color: PdfColors.blueGrey300,
        ),
        pw.SizedBox(height: 10),
      ],
    );
  }

  pw.Widget _buildRunningHeader({
    required SystemSettings settings,
    required String reportType,
    required DateTime startDate,
    required DateTime endDate,
    Uint8List? logoBytes,
  }) {
    final dateRangeStr =
        '${DateFormat('MMM dd, yyyy').format(startDate)} - ${DateFormat('MMM dd, yyyy').format(endDate)}';

    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                if (logoBytes != null) ...[
                  pw.SizedBox(
                    width: 18,
                    height: 18,
                    child: pw.Image(
                      pw.MemoryImage(logoBytes),
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                  pw.SizedBox(width: 5),
                ],
                pw.Text(
                  '${settings.clinicName} | $reportType',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey800,
                  ),
                ),
              ],
            ),
            pw.Text(
              'Period: $dateRangeStr',
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.blueGrey600,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Container(height: 0.8, color: PdfColors.blueGrey200),
        pw.SizedBox(height: 10),
      ],
    );
  }

  pw.Widget _buildDohSeal() {
    return pw.Container(
      width: 48,
      height: 48,
      decoration: pw.BoxDecoration(
        shape: pw.BoxShape.circle,
        border: pw.Border.all(color: PdfColors.teal800, width: 2),
        color: PdfColors.teal50,
      ),
      alignment: pw.Alignment.center,
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            'DOH',
            style: pw.TextStyle(
              color: PdfColors.teal900,
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            'RHU',
            style: pw.TextStyle(
              color: PdfColors.teal800,
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildMedSentrySeal(Uint8List? logoBytes) {
    return pw.Container(
      width: 48,
      height: 48,
      decoration: pw.BoxDecoration(
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: PdfColors.blueGrey700, width: 1.5),
        color: PdfColors.blueGrey50,
      ),
      alignment: pw.Alignment.center,
      child: logoBytes == null
          ? pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  '+',
                  style: pw.TextStyle(
                    color: PdfColors.teal800,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'MEDSENTRY',
                  style: pw.TextStyle(
                    color: PdfColors.blueGrey900,
                    fontSize: 5.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            )
          : pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Image(
                pw.MemoryImage(logoBytes),
                fit: pw.BoxFit.contain,
              ),
            ),
    );
  }

  // ==========================================
  // METADATA BLOCK
  // ==========================================

  pw.Widget _buildMetadataBlock({
    required String reportType,
    required DateTime startDate,
    required DateTime endDate,
    required SystemSettings settings,
    required String preparedByName,
    required String preparedByRole,
    required DateTime generatedAt,
  }) {
    final dateFormat = DateFormat('MMMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');
    final periodStr =
        '${dateFormat.format(startDate)} to ${dateFormat.format(endDate)}';

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
        border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.8),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                reportType.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey900,
                  letterSpacing: 0.4,
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.teal800,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                ),
                child: pw.Text(
                  'OFFICIAL REPORT',
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Divider(thickness: 0.5, color: PdfColors.blueGrey200),
          pw.SizedBox(height: 6),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Left Column
              pw.Expanded(
                flex: 5,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildMetaRow('Reporting Period:', periodStr),
                    pw.SizedBox(height: 3),
                    _buildMetaRow(
                      'Facility Code:',
                      '${settings.clinicCode.isNotEmpty ? settings.clinicCode : "RHU-01"} (${settings.clinicType})',
                    ),
                    pw.SizedBox(height: 3),
                    _buildMetaRow(
                      'Classification:',
                      'Official Public Health Data | RA 10173 Protected',
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 14),
              // Right Column
              pw.Expanded(
                flex: 5,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildMetaRow(
                      'Prepared By:',
                      '$preparedByName ($preparedByRole)',
                    ),
                    pw.SizedBox(height: 3),
                    _buildMetaRow(
                      'Generated Date:',
                      '${dateFormat.format(generatedAt)} at ${timeFormat.format(generatedAt)}',
                    ),
                    pw.SizedBox(height: 3),
                    _buildMetaRow(
                      'System Verification:',
                      'MedSentry Verified Local Storage',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildMetaRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 90,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey700,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: const pw.TextStyle(
              fontSize: 7.5,
              color: PdfColors.blueGrey900,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // SUMMARY CALLOUT CARDS
  // ==========================================

  pw.Widget _buildSummaryCalloutCards(
    Map<String, dynamic> summary,
  ) {
    final totalPatients = summary['total_patients'] ?? 0;
    final newPatients = summary['new_patients'] ?? 0;
    final documents = summary['documents'] ?? 0;
    return pw.Row(
      children: [
        _buildKpiCard(
          title: 'REGISTERED PATIENTS',
          value: '$totalPatients',
          subtitle: 'Active patient records',
          accentColor: PdfColors.teal800,
        ),
        pw.SizedBox(width: 8),
        _buildKpiCard(
          title: 'NEW REGISTRATIONS',
          value: '$newPatients',
          subtitle: 'Newly enrolled records',
          accentColor: PdfColors.blue800,
        ),
        pw.SizedBox(width: 8),
        _buildKpiCard(
          title: 'DOCUMENTS',
          value: '$documents',
          subtitle: 'Added in selected period',
          accentColor: PdfColors.indigo800,
        ),
      ],
    );
  }

  pw.Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required PdfColor accentColor,
  }) {
    return pw.Expanded(
      child: pw.Container(
        decoration: pw.BoxDecoration(
          color: PdfColors.grey50,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          border: pw.Border.all(color: PdfColors.grey300, width: 0.7),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              height: 3,
              decoration: pw.BoxDecoration(
                color: accentColor,
                borderRadius: const pw.BorderRadius.only(
                  topLeft: pw.Radius.circular(4),
                  topRight: pw.Radius.circular(4),
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 6.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey600,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    value,
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                  pw.SizedBox(height: 1),
                  pw.Text(
                    subtitle,
                    style: const pw.TextStyle(
                      fontSize: 6,
                      color: PdfColors.grey600,
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

  // ==========================================
  // BODY CONTENT / TABLES PER REPORT TYPE
  // ==========================================

  List<pw.Widget> _buildReportBody({
    required List<dynamic> patientRecords,
    required Map<String, dynamic> patientsByGender,
    required Map<String, dynamic> patientsByCategory,
  }) {
    return _buildPatientStatisticsBody(
      patientRecords: patientRecords,
      patientsByGender: patientsByGender,
      patientsByCategory: patientsByCategory,
    );
  }

  // 4. Patient Statistics Body
  List<pw.Widget> _buildPatientStatisticsBody({
    required List<dynamic> patientRecords,
    required Map<String, dynamic> patientsByGender,
    required Map<String, dynamic> patientsByCategory,
  }) {
    return [
      _buildSectionTitle('DEMOGRAPHIC BREAKDOWN (BY SEX & PATIENT CATEGORY)'),
      pw.SizedBox(height: 6),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Gender Table
          pw.Expanded(
            flex: 5,
            child: pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
              headerHeight: 20,
              cellHeight: 17,
              cellStyle: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey900),
              headers: ['Biological Sex', 'Total Count'],
              data: patientsByGender.entries.map((e) => [e.key, '${e.value}']).toList(),
            ),
          ),
          pw.SizedBox(width: 14),
          // Category Table
          pw.Expanded(
            flex: 5,
            child: pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
              headerHeight: 20,
              cellHeight: 17,
              cellStyle: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey900),
              headers: ['Target Category', 'Total Count'],
              data: patientsByCategory.entries.map((e) => [e.key, '${e.value}']).toList(),
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 14),
      _buildSectionTitle('REGISTERED PATIENT MASTER LIST (IN REPORT PERIOD)'),
      pw.SizedBox(height: 6),
      if (patientRecords.isEmpty)
        _buildEmptyState('No new patients registered during this reporting period.')
      else
        pw.TableHelper.fromTextArray(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          headerStyle: pw.TextStyle(
            fontSize: 7.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
          headerHeight: 22,
          cellHeight: 18,
          cellStyle: const pw.TextStyle(fontSize: 6.5, color: PdfColors.blueGrey900),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          headers: [
            '#',
            'Patient ID',
            'Full Name (LN, FN, MI)',
            'Age/Sex',
            'Barangay & Purok',
            'PhilHealth ID',
            'Category',
            'Reg. Date',
          ],
          columnWidths: {
            0: const pw.FixedColumnWidth(18),
            1: const pw.FixedColumnWidth(55),
            2: const pw.FlexColumnWidth(2.6),
            3: const pw.FixedColumnWidth(44),
            4: const pw.FlexColumnWidth(2.2),
            5: const pw.FixedColumnWidth(65),
            6: const pw.FlexColumnWidth(1.8),
            7: const pw.FixedColumnWidth(55),
          },
          data: patientRecords.asMap().entries.map((entry) {
            final item = entry.value as Map<String, dynamic>;
            final rawDate = item['registered_at'];
            final parsedDate = rawDate != null ? DateTime.tryParse(rawDate.toString()) : null;
            final regDate = parsedDate != null
                ? DateFormat('MM/dd/yyyy').format(parsedDate)
                : (rawDate?.toString() ?? '-');
            final age = item['age'] != null ? '${item['age']}y' : '-';
            final gender = (item['gender']?.toString().isNotEmpty == true)
                ? item['gender'].toString().substring(0, 1).toUpperCase()
                : '-';
            final brgy = item['barangay']?.toString() ?? '-';
            final purok = item['purok_sitio']?.toString();
            final address = (purok != null && purok.isNotEmpty) ? '$brgy ($purok)' : brgy;

            final fn = item['first_name']?.toString() ?? '';
            final ln = item['last_name']?.toString() ?? '';
            final mi = item['middle_name']?.toString() ?? '';
            final suffix = item['suffix']?.toString();
            String formattedName;
            if (ln.isNotEmpty && fn.isNotEmpty) {
              final miStr = mi.isNotEmpty ? (mi.length <= 2 ? '$mi.' : mi) : '';
              final sufStr = (suffix != null && suffix.isNotEmpty && suffix != 'None') ? ' $suffix' : '';
              formattedName = '$ln, $fn $miStr$sufStr'.trim();
            } else {
              formattedName = item['name'] ?? '-';
            }

            return [
              '${entry.key + 1}',
              item['id'] ?? '-',
              formattedName,
              '$age/$gender',
              address,
              item['philhealth_number'] ?? 'None',
              item['category'] ?? '-',
              regDate,
            ];
          }).toList(),
        ),
    ];
  }

  // SHARED TABLE & UI WIDGETS
  // ==========================================

  pw.Widget _buildSectionTitle(String title) {
    return pw.Row(
      children: [
        pw.Container(
          width: 3.5,
          height: 11,
          color: PdfColors.teal800,
        ),
        pw.SizedBox(width: 5),
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey900,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildEmptyState(String message) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
      ),
      alignment: pw.Alignment.center,
      child: pw.Text(
        message,
        style: pw.TextStyle(
          fontSize: 7.5,
          color: PdfColors.grey700,
          fontStyle: pw.FontStyle.italic,
        ),
      ),
    );
  }

  // ==========================================
  // SIGN-OFF BLOCKS
  // ==========================================

  pw.Widget _buildSignOffBlock({
    required String preparedByName,
    required String preparedByRole,
    required String approvedByName,
    required String approvedByRole,
    required String clinicName,
    required DateTime date,
  }) {
    final dateStr = DateFormat('MMMM dd, yyyy').format(date);

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        // Left: Prepared By
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'PREPARED AND CERTIFIED CORRECT BY:',
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey700,
                ),
              ),
              pw.SizedBox(height: 32),
              pw.Container(
                width: 190,
                height: 0.8,
                color: PdfColors.blueGrey800,
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                preparedByName.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey900,
                ),
              ),
              pw.Text(
                preparedByRole,
                style: const pw.TextStyle(
                  fontSize: 7.5,
                  color: PdfColors.blueGrey700,
                ),
              ),
              pw.Text(
                clinicName,
                style: const pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Text(
                'Date: $dateStr',
                style: const pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 24),

        // Right: Approved By (MHO)
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'VERIFIED, REVIEWED AND APPROVED BY:',
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey700,
                ),
              ),
              pw.SizedBox(height: 32),
              pw.Container(
                width: 190,
                height: 0.8,
                color: PdfColors.blueGrey800,
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                approvedByName.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey900,
                ),
              ),
              pw.Text(
                approvedByRole,
                style: const pw.TextStyle(
                  fontSize: 7.5,
                  color: PdfColors.blueGrey700,
                ),
              ),
              pw.Text(
                'PRC License No.: ________________________',
                style: const pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Text(
                'Date: $dateStr',
                style: const pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // PAGE FOOTER & RA 10173 DISCLAIMER
  // ==========================================

  pw.Widget _buildPageFooter(pw.Context context, SystemSettings settings) {
    return pw.Column(
      children: [
        pw.Container(height: 0.6, color: PdfColors.grey300),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'CONFIDENTIAL HEALTH RECORD | Data Privacy Act of 2012 (RA 10173)',
              style: const pw.TextStyle(
                fontSize: 6,
                color: PdfColors.grey600,
              ),
            ),
            pw.Text(
              'MedSentry RHU MIS | ${settings.clinicName}',
              style: const pw.TextStyle(
                fontSize: 6,
                color: PdfColors.grey600,
              ),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(
                fontSize: 6.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // NAMING CONVENTION HELPER
  // ==========================================

  /// Generates an official, comprehensive individual patient health record PDF.
  Future<Uint8List> generateIndividualPatientRecordPdf({
    required Patient patient,
    required SystemSettings settings,
    required String preparedByName,
    required String preparedByRole,
    String? approvedByName,
    String approvedByRole = 'Municipal Health Officer (MHO) / Medical Officer IV',
    List<MedicalDocument> documents = const [],
  }) async {
    final logoBytes = decodeLogoDataUri(settings.logoDataUri);
    final pdf = pw.Document(
      title: 'MedSentry - Health Record - ${patient.fullName}',
      author: 'MedSentry RHU Healthcare System',
      creator: 'MedSentry Health Information System',
      subject: 'Official RHU Health Record - DOH / LGU Compliance',
    );

    final generatedAt = DateTime.now();
    final effectiveApprovedByName =
        (approvedByName != null && approvedByName.trim().isNotEmpty)
        ? approvedByName.trim()
        : preparedByName;
    final defaultMunicipality = settings.municipality.isNotEmpty
        ? settings.municipality
        : 'N/A';
    final defaultProvince = settings.province.isNotEmpty
        ? settings.province
        : 'N/A';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
        header: (pw.Context context) {
          if (context.pageNumber == 1) {
            return _buildFirstPageHeader(settings, logoBytes: logoBytes);
          } else {
            return pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      '${settings.clinicName} | PATIENT HEALTH RECORD',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey800,
                      ),
                    ),
                    pw.Text(
                      'Patient: ${patient.fullName} (ID: ${patient.id})',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.blueGrey600,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Container(height: 0.8, color: PdfColors.blueGrey200),
                pw.SizedBox(height: 10),
              ],
            );
          }
        },
        footer: (pw.Context context) => _buildPageFooter(context, settings),
        build: (pw.Context context) {
          final dobStr = patient.dateOfBirth != null
              ? DateFormat('MMMM dd, yyyy').format(patient.dateOfBirth!)
              : 'N/A';
          final regDateStr = patient.createdAt != null
              ? DateFormat('MMMM dd, yyyy').format(patient.createdAt!)
              : 'N/A';

          return [
            // Title Header Banner
            pw.Container(
              decoration: const pw.BoxDecoration(
                color: PdfColors.teal900,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'INDIVIDUAL PATIENT HEALTH RECORD & CLINICAL SUMMARY',
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.Text(
                    'RECORD ID: ${patient.id}',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.teal100,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Section 1: Demographics & Identification
            _buildSectionTitle('1. PATIENT DEMOGRAPHICS & IDENTIFICATION'),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              headerHeight: 0,
              cellHeight: 18,
              cellStyle: const pw.TextStyle(fontSize: 7.5, color: PdfColors.blueGrey900),
              data: [
                ['Full Name', patient.fullName, 'PhilHealth Identification', patient.philHealthNumber ?? 'None / Unenrolled'],
                ['Last Name', patient.lastName, 'First Name', patient.firstName],
                ['Middle Initial', patient.middleName?.isNotEmpty == true ? patient.middleName! : 'N/A', 'Suffix', patient.suffix ?? 'None'],
                ['Date of Birth', dobStr, 'Age / Sex', '${patient.age ?? 'N/A'} yrs / ${(patient.gender ?? 'N/A').toUpperCase()}'],
                ['Civil Status', (patient.civilStatus ?? 'N/A').toUpperCase(), 'Blood Type', patient.bloodType ?? 'Unspecified'],
                ['Target Category', patient.category?.displayName ?? 'General Patient', 'Registration Date', regDateStr],
                ['Religion', patient.religion ?? 'Not recorded', 'Local LGU ID', patient.localLguIdNumber ?? 'Not recorded'],
                ['PhilHealth Category', patient.philHealthCategory?.displayName ?? 'Not recorded', 'Last Visit', patient.lastVisitDate == null ? 'Not recorded' : DateFormat('MMMM dd, yyyy').format(patient.lastVisitDate!)],
              ],
            ),
            pw.SizedBox(height: 12),

            // Section 2: Residential Address & Contact
            _buildSectionTitle('2. RESIDENTIAL ADDRESS & CONTACT DETAILS'),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              headerHeight: 0,
              cellHeight: 18,
              cellStyle: const pw.TextStyle(fontSize: 7.5, color: PdfColors.blueGrey900),
              data: [
                ['Street / House No.', patient.address?.isNotEmpty == true ? patient.address! : 'N/A', 'Barangay', patient.barangay ?? 'N/A'],
                ['Purok / Sitio', patient.purokSitio ?? 'N/A', 'Municipality / City', patient.city ?? defaultMunicipality],
                ['Province', patient.province ?? defaultProvince, 'ZIP Code', patient.zipCode ?? 'N/A'],
                ['Mobile / Contact', patient.contactNumber ?? 'None', 'Email Address', patient.email ?? 'None'],
                ['Emergency Contact', patient.emergencyContactName ?? 'None', 'Relationship / Number', '${patient.emergencyContactRelation ?? 'N/A'} / ${patient.emergencyContactNumber ?? 'None'}'],
              ],
            ),
            pw.SizedBox(height: 12),

            // Section 3: Household and FHSIS details already on the patient record.
            _buildSectionTitle('3. HOUSEHOLD, ELIGIBILITY & ENVIRONMENT'),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              headerHeight: 0,
              cellHeight: 18,
              cellStyle: const pw.TextStyle(fontSize: 7.5, color: PdfColors.blueGrey900),
              data: [
                ['Occupation', patient.occupation ?? 'Not recorded', 'Employer', patient.employer ?? 'Not recorded'],
                ['Person with Disability', patient.isPwd ? 'Yes' : 'No', 'Solo Parent', patient.isSoloParent ? 'Yes' : 'No'],
                ['Indigenous Person', patient.isIndigenousPerson ? 'Yes' : 'No', 'Ethnolinguistic Group', patient.tribeEthnolinguisticGroup ?? 'Not recorded'],
                ['4Ps Beneficiary', patient.is4PsBeneficiary ? 'Yes' : 'No', 'Household ID', patient.householdIdNumber ?? 'Not recorded'],
                ['Water Source', patient.waterSource?.displayName ?? 'Not recorded', 'Toilet Facility', patient.toiletFacility?.displayName ?? 'Not recorded'],
              ],
            ),
            pw.SizedBox(height: 12),

            // Section 4: Clinical Alerts & Medical History
            _buildSectionTitle('4. CLINICAL ALERTS & MEDICAL HISTORY'),
            pw.SizedBox(height: 6),
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                color: PdfColors.grey50,
              ),
              padding: const pw.EdgeInsets.all(10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Text('Known Allergies: ', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: patient.allergies?.isNotEmpty == true ? PdfColors.red800 : PdfColors.blueGrey800)),
                      pw.Text(patient.allergies?.isNotEmpty == true ? patient.allergies! : 'No known drug or environmental allergies recorded.', style: pw.TextStyle(fontSize: 8, color: patient.allergies?.isNotEmpty == true ? PdfColors.red900 : PdfColors.blueGrey900)),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    children: [
                      pw.Text('Recorded Height / Weight: ', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                      pw.Text(
                        '${patient.height == null ? 'Not recorded' : '${patient.height} cm'} / ${patient.weight == null ? 'Not recorded' : '${patient.weight} kg'}',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey900),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Past Medical History: ', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                      pw.Expanded(
                        child: pw.Text(patient.medicalHistory?.isNotEmpty == true ? patient.medicalHistory! : 'No significant medical history reported.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey900)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Section 5: Attached Medical Documents & Files
            _buildSectionTitle('5. ATTACHED MEDICAL DOCUMENTS & FILES'),
            pw.SizedBox(height: 6),
            if (documents.isEmpty)
              _buildEmptyState('No external medical documents attached to this record.')
            else
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                headerHeight: 20,
                cellHeight: 18,
                cellStyle: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey900),
                oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                headers: ['#', 'Document Title', 'Classification', 'Date Added', 'File Size'],
                columnWidths: {
                  0: const pw.FixedColumnWidth(20),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FixedColumnWidth(70),
                  4: const pw.FixedColumnWidth(60),
                },
                data: documents.asMap().entries.map((entry) {
                  final doc = entry.value;
                  final date = doc.scanDate ?? doc.createdAt;
                  final dateStr = date != null ? DateFormat('MM/dd/yyyy').format(date) : '-';
                  final sizeStr = '${(doc.fileSize / 1024).toStringAsFixed(1)} KB';
                  return [
                    '${entry.key + 1}',
                    doc.title,
                    doc.typeDisplay,
                    dateStr,
                    sizeStr,
                  ];
                }).toList(),
              ),
            pw.SizedBox(height: 24),

            // Section 6: Official Sign-off Block
            _buildSignOffBlock(
              preparedByName: preparedByName,
              preparedByRole: preparedByRole,
              approvedByName: effectiveApprovedByName,
              approvedByRole: approvedByRole,
              clinicName: settings.clinicName,
              date: generatedAt,
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Builds a sanitized default filename adhering to:
  /// `MedSentry_[ReportType]_[FacilityName]_[YYYY-MM-DD].pdf`
  static String buildDefaultFileName({
    required String reportType,
    required String facilityName,
    required DateTime date,
  }) {
    final cleanType = reportType
        .replaceAll(' ', '')
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final cleanFacility = facilityName
        .replaceAll(' ', '')
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    return 'MedSentry_${cleanType}_${cleanFacility}_$dateStr.pdf';
  }
}
