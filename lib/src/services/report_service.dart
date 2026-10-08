import 'dart:convert';
import 'dart:typed_data';

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
  }) async {
    if (reportType != 'Patient Statistics') {
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

    final allPatients = await _db.getAllPatients(includeArchived: true);
    final patients = allPatients
        .where((patient) => !patient.isArchived && inRange(patient.createdAt))
        .toList();
    final documents = (await _db.getDocuments())
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

    return {
      'report_type': reportType,
      'period': {
        'start_date': start.toIso8601String(),
        'end_date': end.toIso8601String(),
        'grouping': grouping.name,
      },
      'summary': {
        'new_patients': patients.length,
        'total_patients': allPatients.where((patient) => !patient.isArchived).length,
        'documents': documents.length,
      },
      'patient_registrations_by_period': registrationCounts,
      'patients_by_gender': genderCounts,
      'patients_by_category': categoryCounts,
      'patient_records': patients
          .map(
            (patient) => {
              'id': patient.id,
              'name': patient.fullName,
              'age': patient.age,
              'gender': patient.gender ?? 'Unknown',
              'category': patient.category?.displayName ?? 'Uncategorized',
              'barangay': patient.barangay ?? 'Unspecified',
              'registered_at': patient.createdAt?.toIso8601String(),
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
