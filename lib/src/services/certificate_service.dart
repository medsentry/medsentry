import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/models.dart';

enum CertificateType {
  medicalCertificate,
  patientSummary,
}

extension CertificateTypeExtension on CertificateType {
  String get displayName {
    switch (this) {
      case CertificateType.medicalCertificate:
        return 'Medical Certificate';
      case CertificateType.patientSummary:
        return 'Patient Record Summary';
    }
  }
}

class CertificateService {
  Future<Uint8List> generateCertificate({
    required CertificateType type,
    required Patient patient,
    required SystemSettings settings,
    String? purpose,
    String? findings,
    String? recommendations,
    int? restDays,
    String? issuedBy,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (context) {
          switch (type) {
            case CertificateType.medicalCertificate:
              return _buildMedicalCertificate(
                patient: patient,
                settings: settings,
                purpose: purpose ?? 'Medical clearance',
                findings: findings ?? 'N/A',
                recommendations: recommendations ?? 'Follow-up as needed',
                restDays: restDays,
                issuedBy: issuedBy ?? 'RHU Medical Officer',
              );
            case CertificateType.patientSummary:
              return _buildPatientSummary(
                patient: patient,
                settings: settings,
              );
          }
        },
      ),
    );

    return pdf.save();
  }

  Future<void> printCertificate(Uint8List pdfBytes, String name) async {
    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: name,
    );
  }

  pw.Widget _buildHeader(SystemSettings settings, String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          'Republic of the Philippines',
          style: pw.TextStyle(fontSize: 10),
        ),
        pw.Text(
          settings.clinicName,
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        if (settings.clinicAddress.isNotEmpty)
          pw.Text(settings.clinicAddress, style: const pw.TextStyle(fontSize: 10)),
        if (settings.clinicContact.isNotEmpty)
          pw.Text(settings.clinicContact, style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 8),
        pw.Divider(thickness: 2),
        pw.SizedBox(height: 12),
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 16),
      ],
    );
  }

  pw.Widget _buildMedicalCertificate({
    required Patient patient,
    required SystemSettings settings,
    required String purpose,
    required String findings,
    required String recommendations,
    required String issuedBy,
    int? restDays,
  }) {
    final dateStr = _formatDate(DateTime.now());
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildHeader(settings, 'MEDICAL CERTIFICATE'),
        pw.Text('Date: $dateStr'),
        pw.SizedBox(height: 16),
        pw.Text(
          'This is to certify that ${patient.fullName}, '
          '${patient.age != null ? "${patient.age} years old" : "age not specified"}, '
          '${patient.gender ?? ""}, '
          'was examined at this facility on $dateStr.',
        ),
        pw.SizedBox(height: 12),
        pw.Text('Purpose: $purpose'),
        pw.SizedBox(height: 8),
        pw.Text('Clinical Findings: $findings'),
        if (restDays != null) ...[
          pw.SizedBox(height: 8),
          pw.Text('Recommended rest: $restDays day(s)'),
        ],
        pw.SizedBox(height: 8),
        pw.Text('Recommendations: $recommendations'),
        pw.Spacer(),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SizedBox(height: 40),
              pw.Text(issuedBy),
              pw.Text('Authorized Signatory'),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPatientSummary({
    required Patient patient,
    required SystemSettings settings,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildHeader(settings, 'PATIENT RECORD SUMMARY'),
        _buildPatientInfo(patient),
        pw.SizedBox(height: 12),
        if (patient.allergies != null && patient.allergies!.isNotEmpty)
          pw.Text('Allergies: ${patient.allergies}'),
        if (patient.medicalHistory != null &&
            patient.medicalHistory!.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Text('Medical History: ${patient.medicalHistory}'),
        ],
        pw.Spacer(),
        pw.Text(
          'Generated: ${_formatDate(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ],
    );
  }

  pw.Widget _buildPatientInfo(Patient patient) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Patient ID: ${patient.id}'),
        pw.Text('Name: ${patient.fullName}'),
        if (patient.dateOfBirth != null)
          pw.Text('Date of Birth: ${_formatDate(patient.dateOfBirth!)}'),
        if (patient.age != null) pw.Text('Age: ${patient.age}'),
        if (patient.gender != null) pw.Text('Gender: ${patient.gender}'),
        if (patient.contactNumber != null)
          pw.Text('Contact: ${patient.contactNumber}'),
        if (patient.address != null) pw.Text('Address: ${patient.address}'),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
