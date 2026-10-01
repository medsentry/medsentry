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

    test('buildDefaultFileName formats filename according to DOH/LGU standard', () {
      final date = DateTime(2026, 10, 1);
      final filename = ReportPdfService.buildDefaultFileName(
        reportType: 'Morbidity Report',
        facilityName: 'Cantilan RHU',
        date: date,
      );

      expect(filename, equals('MedSentry_MorbidityReport_CantilanRHU_2026-10-01.pdf'));
    });

    test('buildDefaultFileName strips invalid filesystem characters', () {
      final date = DateTime(2026, 10, 1);
      final filename = ReportPdfService.buildDefaultFileName(
        reportType: 'Disease & Surveillance / Weekly*',
        facilityName: 'Cantilan (Main) RHU #1',
        date: date,
      );

      expect(
        filename,
        equals('MedSentry_DiseaseSurveillanceWeekly_CantilanMainRHU1_2026-10-01.pdf'),
      );
    });

    test('generateReportPdf generates valid PDF bytes for Daily Consultation Report', () async {
      final startDate = DateTime(2026, 10, 1);
      final endDate = DateTime(2026, 10, 1);

      final reportData = {
        'summary': {
          'consultations': 5,
          'patients_with_consultations': 4,
          'new_patients': 2,
          'completed_visits': 5,
        },
        'consultation_records': [
          {
            'id': 'c-1',
            'patient_id': 'P-001',
            'patient_name': 'Juan Dela Cruz',
            'patient_age': 45,
            'patient_gender': 'Male',
            'patient_barangay': 'Parang',
            'date': DateTime(2026, 10, 1, 9, 30).toIso8601String(),
            'diagnosis': 'Essential (primary) hypertension',
            'created_by': 'Dr. Santos',
          },
        ],
        'top_diagnoses': [
          {'diagnosis': 'I10 - Essential Hypertension', 'count': 3},
          {'diagnosis': 'J06 - Acute Upper Respiratory Infection', 'count': 2},
        ],
      };

      final pdfBytes = await pdfService.generateReportPdf(
        reportType: 'Daily Consultation Report',
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

    test('generateReportPdf generates valid PDF bytes for Disease Surveillance & Morbidity', () async {
      final startDate = DateTime(2026, 9, 1);
      final endDate = DateTime(2026, 9, 30);

      final reportData = {
        'summary': {
          'consultations': 25,
          'patients_with_consultations': 20,
          'new_patients': 6,
          'completed_visits': 24,
        },
        'top_diagnoses': [
          {'diagnosis': 'A09 - Infectious Gastroenteritis', 'count': 10},
          {'diagnosis': 'J18 - Pneumonia', 'count': 6},
        ],
        'notifiable_diseases': [
          {
            'patient_id': 'P-099',
            'icd10_code': 'A09',
            'date': DateTime(2026, 9, 15).toIso8601String(),
          },
        ],
      };

      final pdfBytes = await pdfService.generateReportPdf(
        reportType: 'Disease Surveillance',
        startDate: startDate,
        endDate: endDate,
        reportData: reportData,
        settings: settings,
        preparedByName: 'Staff Nurse',
        preparedByRole: 'Epidemiology Surveillance Officer',
        approvedByName: 'Municipal Health Officer',
      );

      expect(pdfBytes, isNotEmpty);
      final header = ascii.decode(pdfBytes.sublist(0, 5));
      expect(header, equals('%PDF-'));
    });

    test('generateReportPdf generates valid PDF bytes for Medication Prescriptions', () async {
      final startDate = DateTime(2026, 10, 1);
      final endDate = DateTime(2026, 10, 1);

      final reportData = {
        'summary': {
          'consultations': 8,
          'patients_with_consultations': 8,
          'new_patients': 1,
          'completed_visits': 8,
        },
        'prescriptions': [
          {
            'medication': 'Amoxicillin 500mg',
            'generic_name': 'Amoxicillin',
            'dosage': '1 capsule 3x a day',
            'frequency': 'Every 8 hours',
            'quantity': 21,
          },
          {
            'medication': 'Paracetamol 500mg',
            'generic_name': 'Paracetamol',
            'dosage': '1 tablet as needed',
            'frequency': 'Every 4-6 hours',
            'quantity': 10,
          },
        ],
      };

      final pdfBytes = await pdfService.generateReportPdf(
        reportType: 'Medication Prescriptions',
        startDate: startDate,
        endDate: endDate,
        reportData: reportData,
        settings: settings,
        preparedByName: 'Pharmacist Staff',
        preparedByRole: 'RHU Pharmacy Dispenser',
        approvedByName: 'MHO Physician',
      );

      expect(pdfBytes, isNotEmpty);
      final header = ascii.decode(pdfBytes.sublist(0, 5));
      expect(header, equals('%PDF-'));
    });

    test('generateReportPdf generates valid PDF bytes for FHSIS & DOH Programmatic Report', () async {
      final startDate = DateTime(2026, 1, 1);
      final endDate = DateTime(2026, 9, 30);

      final reportData = {
        'summary': {
          'consultations': 150,
          'patients_with_consultations': 120,
          'new_patients': 45,
          'completed_visits': 148,
        },
        'top_diagnoses': [
          {'diagnosis': 'I10 - Essential Hypertension', 'count': 40},
          {'diagnosis': 'E11 - Type 2 Diabetes Mellitus', 'count': 25},
        ],
      };

      final pdfBytes = await pdfService.generateReportPdf(
        reportType: 'FHSIS Export',
        startDate: startDate,
        endDate: endDate,
        reportData: reportData,
        settings: settings,
        preparedByName: 'RHU Nurse Supervisor',
        preparedByRole: 'FHSIS Coordinator',
        approvedByName: 'Municipal Health Officer',
      );

      expect(pdfBytes, isNotEmpty);
      final header = ascii.decode(pdfBytes.sublist(0, 5));
      expect(header, equals('%PDF-'));
    });
  });
}

