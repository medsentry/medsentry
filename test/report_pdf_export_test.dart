import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/models/system_settings.dart';
import 'package:medsentry/src/services/report_pdf_service.dart';

void main() {
  group('ReportPdfService Tests', () {
    const pdfService = ReportPdfService();
    const settings = SystemSettings(
      clinicName: 'Cantilan Rural Health Unit',
      clinicCode: 'RHU-01',
      municipality: 'Cantilan',
      province: 'Surigao del Sur',
    );

    test(
      'buildDefaultFileName formats filename according to DOH/LGU standard',
      () {
        final date = DateTime(2026, 10, 1);
        final filename = ReportPdfService.buildDefaultFileName(
          reportType: 'Morbidity Report',
          facilityName: 'Cantilan RHU',
          date: date,
        );

        expect(
          filename,
          equals('MedSentry_MorbidityReport_CantilanRHU_2026-10-01.pdf'),
        );
      },
    );

    test('buildDefaultFileName strips invalid filesystem characters', () {
      final date = DateTime(2026, 10, 1);
      final filename = ReportPdfService.buildDefaultFileName(
        reportType: 'Disease & Surveillance / Weekly*',
        facilityName: 'Cantilan (Main) RHU #1',
        date: date,
      );

      expect(
        filename,
        equals(
          'MedSentry_DiseaseSurveillanceWeekly_CantilanMainRHU1_2026-10-01.pdf',
        ),
      );
    });

    test('generateReportPdf generates patient statistics PDF bytes', () async {
        final startDate = DateTime(2026, 10, 1);
        final endDate = DateTime(2026, 10, 1);

        final reportData = {
          'summary': {
            'total_patients': 15,
            'new_patients': 2,
            'documents': 3,
          },
          'patient_records': [
            {
              'id': 'P-001',
              'name': 'Juan Dela Cruz',
              'registered_at': DateTime(2026, 10, 1).toIso8601String(),
            },
          ],
          'patients_by_gender': {'Male': 1},
          'patients_by_category': {'Adult': 1},
        };

        final pdfBytes = await pdfService.generateReportPdf(
          reportType: 'Patient Statistics',
          startDate: startDate,
          endDate: endDate,
          reportData: reportData,
          settings: settings,
          preparedByName: 'Maria Santos, RN',
          preparedByRole: 'Public Health Nurse',
          approvedByName: 'Dr. Roberto Cruz, MD',
        );

        expect(pdfBytes, isNotEmpty);
        // Verify PDF file signature (%PDF-)
        final header = ascii.decode(pdfBytes.sublist(0, 5));
        expect(header, equals('%PDF-'));
    });

    test('generateReportPdf rejects removed clinical report types', () async {
      expect(
        () => pdfService.generateReportPdf(
          reportType: 'Daily Consultation Report',
          startDate: DateTime(2026, 10, 1),
          endDate: DateTime(2026, 10, 1),
          reportData: const {},
          settings: settings,
          preparedByName: 'Staff',
          preparedByRole: 'Staff',
          approvedByName: 'Officer',
        ),
        throwsArgumentError,
      );
    });
  });
}
