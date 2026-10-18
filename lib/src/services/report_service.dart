import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../database/simple_database.dart';
import '../models/models.dart';
import '../utils/file_exporter/file_exporter.dart';
import '../utils/report_date_filter.dart';

/// Generates reports using patient and document data only.
class ReportService {
  final SimpleDatabase _db;
  final FileExporter _fileExporter = createFileExporter();

  ReportService(this._db);

  Future<Map<String, dynamic>> generateRangeReport({
    required String reportType,
    required DateTime startDate,
    required DateTime endDate,
    required ReportGrouping grouping,
    String? clinicId,
  }) async {
    if (reportType != 'Patient Statistics' &&
        reportType != 'Document & Registry Summary') {
      throw ArgumentError.value(reportType, 'reportType', 'Unsupported report');
    }

    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    if (end.isBefore(start)) {
      throw ArgumentError('Report end date cannot be before its start date');
    }
    final today = DateTime.now();
    if (end.isAfter(DateTime(today.year, today.month, today.day))) {
      throw ArgumentError('Report dates cannot be in the future');
    }
    final endExclusive = end.add(const Duration(days: 1));
    bool inRange(DateTime? value) =>
        isWithinReportInterval(value, start, endExclusive);

    final allPatients = await _db.getAllPatients(
      includeArchived: true,
      clinicId: clinicId,
    );
    final patientMap = {for (final p in allPatients) p.id: p};
    final patients = allPatients
        .where((patient) => !patient.isArchived && inRange(patient.createdAt))
        .toList();
    final allDocuments = await _db.getDocuments(clinicId: clinicId);
    final documents = allDocuments
        .where((document) => inRange(document.createdAt))
        .toList();

    final genderCounts = <String, int>{};
    final categoryCounts = <String, int>{};
    final registrationCounts = <String, int>{};
    for (final patient in patients) {
      final gender = patient.gender ?? 'Unknown';
      genderCounts[gender] = (genderCounts[gender] ?? 0) + 1;

      final category = patient.category?.displayName ?? 'Uncategorized';
      categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;

      if (patient.createdAt case final createdAt?) {
        final bucket = reportBucketStart(createdAt, grouping);
        final key = _reportBucketLabel(bucket, grouping);
        registrationCounts[key] = (registrationCounts[key] ?? 0) + 1;
      }
    }

    final documentTypeCounts = <String, int>{};
    final documentPeriodCounts = <String, int>{};
    for (final doc in documents) {
      final typeLabel = doc.typeDisplay;
      documentTypeCounts[typeLabel] = (documentTypeCounts[typeLabel] ?? 0) + 1;

      final dt = doc.scanDate ?? doc.createdAt;
      if (dt != null) {
        final bucket = reportBucketStart(dt, grouping);
        final key = _reportBucketLabel(bucket, grouping);
        documentPeriodCounts[key] = (documentPeriodCounts[key] ?? 0) + 1;
      }
    }

    final associatedPatientIds =
        documents.map((d) => d.patientId).where((id) => id.isNotEmpty).toSet();

    return {
      'report_type': reportType,
      'period': {
        'start_date': start.toIso8601String(),
        'end_date': end.toIso8601String(),
        'grouping': grouping.name,
      },
      'summary': {
        'new_patients': patients.length,
        'total_patients': allPatients
            .where((patient) => !patient.isArchived)
            .length,
        'documents': documents.length,
        'total_documents': documents.length,
        'verified_documents':
            documents.where((d) => d.status == DocumentStatus.active).length,
        'pending_verification':
            documents.where((d) => d.status != DocumentStatus.active).length,
        'associated_patients': associatedPatientIds.length,
      },
      'patient_registrations_by_period': registrationCounts,
      'patients_by_gender': genderCounts,
      'patients_by_category': categoryCounts,
      'documents_by_type': documentTypeCounts,
      'documents_by_period': documentPeriodCounts,
      'patient_records': patients
          .map(
            (patient) => {
              'id': patient.id,
              'name': patient.fullName,
              'first_name': patient.firstName,
              'last_name': patient.lastName,
              'middle_name': patient.middleName,
              'suffix': patient.suffix,
              'age': patient.age,
              'gender': patient.gender ?? 'Unknown',
              'category': patient.category?.displayName ?? 'Uncategorized',
              'barangay': patient.barangay ?? 'Unspecified',
              'purok_sitio': patient.purokSitio ?? '',
              'philhealth_number': patient.philHealthNumber ?? 'None',
              'blood_type': patient.bloodType ?? '',
              'contact_number': patient.contactNumber ?? '',
              'registered_at': patient.createdAt?.toIso8601String(),
            },
          )
          .toList(),
      'document_records': documents
          .map(
            (doc) => {
              'id': doc.id,
              'title': doc.title,
              'type': doc.typeDisplay,
              'patient_id': doc.patientId,
              'patient_name':
                  patientMap[doc.patientId]?.fullName ?? 'Unknown Patient',
              'is_verified': doc.status == DocumentStatus.active,
              'mime_type': doc.mimeType ?? 'unknown',
              'scan_date': doc.scanDate?.toIso8601String(),
              'created_at': doc.createdAt?.toIso8601String(),
            },
          )
          .toList(),
      'generated_at': DateTime.now().toIso8601String(),
    };
  }

  String _reportBucketLabel(DateTime date, ReportGrouping grouping) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return switch (grouping) {
      ReportGrouping.day => '${date.year}-$month-$day',
      ReportGrouping.week => 'Week of ${date.year}-$month-$day',
      ReportGrouping.month => '${date.year}-$month',
      ReportGrouping.year => '${date.year}',
    };
  }

  Future<String> exportReportToJson(
    Map<String, dynamic> report, {
    String? filename,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final actualFilename = filename ?? 'report_$timestamp.json';
    try {
      return await _fileExporter.exportTextFile(
        filename: actualFilename,
        content: const JsonEncoder.withIndent('  ').convert(report),
      );
    } catch (error) {
      debugPrint('Error exporting report: $error');
      throw Exception('Failed to export report: $error');
    }
  }

  Future<void> shareReport(String filePath) async {
    try {
      await _fileExporter.shareFile(
        filePath,
        subject: 'MedSentry Report',
        text: 'Please find the attached report from MedSentry.',
      );
    } catch (error) {
      debugPrint('Error sharing report: $error');
      throw Exception('Failed to share report: $error');
    }
  }

  Future<String?> exportReportToPdf({
    required Uint8List pdfBytes,
    required String filename,
    String? dialogTitle,
  }) async {
    try {
      return await _fileExporter.saveBinaryFile(
        filename: filename,
        bytes: pdfBytes,
        dialogTitle: dialogTitle ?? 'Save Report PDF',
        mimeType: 'application/pdf',
      );
    } catch (error) {
      debugPrint('Error exporting PDF report: $error');
      throw Exception('Failed to export PDF report: $error');
    }
  }

  Future<bool> openExportedReport(String filePath) =>
      _fileExporter.openFile(filePath);
}
