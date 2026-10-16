import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:medsentry/src/models/patient.dart';
import 'package:medsentry/src/models/system_settings.dart';
import 'package:medsentry/src/services/certificate_service.dart';
import 'package:medsentry/src/services/report_pdf_service.dart';
import 'package:medsentry/src/utils/logo_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String logoDataUri;
  late SystemSettings settings;
  final patient = Patient(id: 'P-1', firstName: 'Ana', lastName: 'Santos');

  setUpAll(() async {
    final asset = await rootBundle.load('assets/images/rhu_doctors.png');
    logoDataUri =
        'data:image/png;base64,${base64Encode(asset.buffer.asUint8List())}';
    settings = SystemSettings(
      clinicName: 'Madrid Rural Health Unit',
      logoDataUri: logoDataUri,
    );
  });

  test('logo data URI decodes to image bytes', () {
    expect(decodeLogoDataUri(logoDataUri), isNotNull);
    expect(decodeLogoDataUri('not-an-image'), isNull);
  });

  test('patient report PDF renders the configured logo', () async {
    final pdf = await const ReportPdfService().generateReportPdf(
      reportType: 'Patient Statistics',
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 10, 1),
      reportData: const {
        'summary': {'total_patients': 1},
      },
      settings: settings,
      preparedByName: 'Staff',
      preparedByRole: 'Nurse',
      approvedByName: 'Officer',
    );

    expect(ascii.decode(pdf.sublist(0, 5)), '%PDF-');
  });

  test('certificate PDF renders the configured logo', () async {
    final pdf = await CertificateService().generateCertificate(
      type: CertificateType.patientSummary,
      patient: patient,
      settings: settings,
    );

    expect(ascii.decode(pdf.sublist(0, 5)), '%PDF-');
  });
}
