import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../database/simple_database.dart';
import '../models/models.dart';
import '../utils/report_date_filter.dart';
import '../utils/file_exporter/file_exporter.dart';

/// Service for generating DOH reports and analytics
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
    bool inRange(DateTime? value) {
      return isWithinReportInterval(value, start, endExclusive);
    }

    final allPatients = await _db.getAllPatients(includeArchived: true);
    final consultations = (await _db.getAllConsultations())
        .where((item) => inRange(item.createdAt))
        .toList();
    final patients = allPatients
        .where((item) => !item.isArchived && inRange(item.createdAt))
        .toList();
    final queueItems = (await _db.getQueueItems()).where((item) {
      return item.status == QueueStatus.completed &&
          inRange(item.endTime ?? item.updatedAt ?? item.arrivalTime);
    }).toList();
    final documents = (await _db.getDocuments())
        .where((item) => inRange(item.createdAt))
        .toList();

    final patientById = {
      for (final patient in allPatients) patient.id: patient,
    };
    final visitingPatientIds = consultations
        .map((item) => item.patientId)
        .toSet();
    final newPatientIds = patients.map((item) => item.id).toSet();
    final diagnosisCounts = <String, int>{};
    for (final consultation in consultations) {
      final code = consultation.icd10Code ?? 'Unspecified';
      diagnosisCounts[code] = (diagnosisCounts[code] ?? 0) + 1;
    }

    final groupedConsultations = <String, int>{};
    for (final consultation in consultations) {
      final date = consultation.createdAt;
      if (date == null) continue;
      final bucket = reportBucketStart(date, grouping);
      final key = _reportBucketLabel(bucket, grouping);
      groupedConsultations[key] = (groupedConsultations[key] ?? 0) + 1;
    }

    final period = {
      'start_date': start.toIso8601String(),
      'end_date': end.toIso8601String(),
      'grouping': grouping.name,
    };
    final summary = {
      'new_patients': patients.length,
      'patients_with_consultations': visitingPatientIds.length,
      'returning_patients': visitingPatientIds.difference(newPatientIds).length,
      'consultations': consultations.length,
      'completed_visits': queueItems.length,
      'documents': documents.length,
    };
    final common = {
      'report_type': reportType,
      'period': period,
      'summary': summary,
      'consultations_by_period': groupedConsultations,
      'top_diagnoses': _getTopDiagnoses(consultations, 10),
      'generated_at': DateTime.now().toIso8601String(),
    };

    switch (reportType) {
      case 'Patient Statistics':
        final genderCounts = <String, int>{};
        final categoryCounts = <String, int>{};
        for (final patient in patients) {
          final gender = patient.gender ?? 'Unknown';
          genderCounts[gender] = (genderCounts[gender] ?? 0) + 1;
          final category = patient.category?.displayName ?? 'Uncategorized';
          categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
        }
        return {
          ...common,
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
        };
      case 'Disease Surveillance':
        return {
          ...common,
          'disease_breakdown': diagnosisCounts,
          'notifiable_diseases': _extractNotifiableDiseases(consultations),
        };
      case 'Medication Prescriptions':
        final consultationById = {
          for (final item in await _db.getAllConsultations()) item.id: item,
        };
        final prescriptions = (await _db.getAllPrescriptions()).where((item) {
          final date =
              item.createdAt ??
              consultationById[item.consultationId]?.createdAt;
          return inRange(date);
        }).toList();
        final medicationCounts = <String, int>{};
        for (final prescription in prescriptions) {
          medicationCounts[prescription.medicationName] =
              (medicationCounts[prescription.medicationName] ?? 0) +
              prescription.quantity;
        }
        return {
          ...common,
          'prescription_count': prescriptions.length,
          'total_quantity': prescriptions.fold<int>(
            0,
            (total, item) => total + item.quantity,
          ),
          'quantity_by_medication': medicationCounts,
          'prescriptions': prescriptions
              .map(
                (item) => {
                  'medication': item.medicationName,
                  'generic_name': item.genericName,
                  'quantity': item.quantity,
                  'dosage': item.dosage,
                  'frequency': item.frequency,
                  'consultation_id': item.consultationId,
                },
              )
              .toList(),
        };
      default:
        return {
          ...common,
          'consultation_records': consultations
              .map(
                (item) {
                  final patient = patientById[item.patientId];
                  return {
                    'id': item.id,
                    'patient_id': item.patientId,
                    'patient_name': patient?.fullName ?? 'Unknown',
                    'patient_age': patient?.age,
                    'patient_gender': patient?.gender ?? 'Unknown',
                    'patient_barangay': patient?.barangay ?? 'Unspecified',
                    'date': item.createdAt?.toIso8601String(),
                    'diagnosis_code': item.icd10Code,
                    'diagnosis': item.icd10Description,
                    'follow_up': item.isFollowUp,
                    'created_by': item.createdBy,
                  };
                },
              )
              .toList(),
        };
    }
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

  /// Generate monthly patient statistics report
  Future<Map<String, dynamic>> generateMonthlyStats({
    required int year,
    required int month,
  }) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0); // Last day of month

    // Get all consultations for the month
    final consultations = await _db.getAllConsultations();
    final monthlyConsultations = consultations.where((c) {
      if (c.createdAt == null) return false;
      return c.createdAt!.isAfter(startDate) && c.createdAt!.isBefore(endDate);
    }).toList();

    // Get all patients
    final patients = await _db.getAllPatients();
    final newPatients = patients.where((p) {
      if (p.createdAt == null) return false;
      return p.createdAt!.isAfter(startDate) && p.createdAt!.isBefore(endDate);
    }).toList();

    // Calculate statistics
    final stats = {
      'total_consultations': monthlyConsultations.length,
      'new_patients': newPatients.length,
      'total_patients': patients.length,
      'icd10_distribution': _calculateIcd10Distribution(monthlyConsultations),
      'age_distribution': _calculateAgeDistribution(
        monthlyConsultations,
        patients,
      ),
      'gender_distribution': _calculateGenderDistribution(patients),
      'top_diagnoses': _getTopDiagnoses(monthlyConsultations, 10),
      'period': {
        'year': year,
        'month': month,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
      },
    };

    return stats;
  }

  /// Generate disease surveillance report (for DOH)
  Future<Map<String, dynamic>> generateDiseaseSurveillanceReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final consultations = await _db.getAllConsultations();
    final periodConsultations = consultations.where((c) {
      if (c.createdAt == null) return false;
      return c.createdAt!.isAfter(startDate) && c.createdAt!.isBefore(endDate);
    }).toList();

    // Group by ICD-10 codes (disease categories)
    final diseaseCounts = <String, int>{};
    for (final consultation in periodConsultations) {
      final code = consultation.icd10Code ?? 'Unknown';
      diseaseCounts[code] = (diseaseCounts[code] ?? 0) + 1;
    }

    // Sort by frequency
    final sortedDiseases = diseaseCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'report_type': 'Disease Surveillance',
      'period': {
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
      },
      'total_cases': periodConsultations.length,
      'disease_breakdown': Map.fromEntries(sortedDiseases),
      'notifiable_diseases': _extractNotifiableDiseases(periodConsultations),
    };
  }

  /// Generate maternal health report
  Future<Map<String, dynamic>> generateMaternalHealthReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final patients = await _db.getAllPatients();
    final consultations = await _db.getAllConsultations();

    // Filter pregnant patients
    final pregnantPatients = patients.where((p) {
      return p.category == PatientCategory.pregnant;
    }).toList();

    // Get prenatal consultations
    final prenatalConsultations = consultations.where((c) {
      if (c.createdAt == null) return false;
      return c.createdAt!.isAfter(startDate) &&
          c.createdAt!.isBefore(endDate) &&
          c.icd10Code?.toLowerCase().contains('prenatal') == true;
    }).toList();

    return {
      'report_type': 'Maternal Health',
      'period': {
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
      },
      'pregnant_patients': pregnantPatients.length,
      'prenatal_visits': prenatalConsultations.length,
      'average_visits_per_patient': pregnantPatients.isEmpty
          ? 0
          : prenatalConsultations.length / pregnantPatients.length,
    };
  }

  /// Generate child health report
  Future<Map<String, dynamic>> generateChildHealthReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final patients = await _db.getAllPatients();
    final consultations = await _db.getAllConsultations();

    // Filter pediatric patients
    final pediatricCategories = [
      PatientCategory.infant,
      PatientCategory.toddler,
      PatientCategory.preschool,
      PatientCategory.schoolAge,
      PatientCategory.adolescent,
      PatientCategory.pediatric,
    ];

    final pediatricPatients = patients.where((p) {
      return pediatricCategories.contains(p.category);
    }).toList();

    // Get pediatric consultations
    final pediatricConsultations = consultations
        .where((c) {
          if (c.createdAt == null) return false;
          return c.createdAt!.isAfter(startDate) &&
              c.createdAt!.isBefore(endDate);
        })
        .where((c) {
          final patient = patients.firstWhere(
            (p) => p.id == c.patientId,
            orElse: () => patients.first,
          );
          return pediatricCategories.contains(patient.category);
        })
        .toList();

    return {
      'report_type': 'Child Health',
      'period': {
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
      },
      'pediatric_patients': pediatricPatients.length,
      'pediatric_consultations': pediatricConsultations.length,
      'top_pediatric_diagnoses': _getTopDiagnoses(pediatricConsultations, 5),
    };
  }

  /// Generate immunization report
  Future<Map<String, dynamic>> generateImmunizationReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // This would integrate with immunization records
    // For now, return a placeholder structure
    return {
      'report_type': 'Immunization',
      'period': {
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
      },
      'vaccines_administered': 0,
      'coverage_rate': 0.0,
      'note': 'Immunization tracking to be implemented',
    };
  }

  /// Export report to JSON file
  Future<String> exportReportToJson(
    Map<String, dynamic> report, {
    String? filename,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final defaultFilename = 'report_$timestamp.json';
    final actualFilename = filename ?? defaultFilename;

    try {
      final jsonContent = const JsonEncoder.withIndent('  ').convert(report);
      final path = await _fileExporter.exportTextFile(
        filename: actualFilename,
        content: jsonContent,
      );

      debugPrint('Report exported to: $path');
      return path;
    } catch (e) {
      debugPrint('Error exporting report: $e');
      throw Exception('Failed to export report: $e');
    }
  }

  /// Export report to CSV format
  Future<String> exportConsultationsToCsv({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final consultations = await _db.getAllConsultations();
    final periodConsultations = consultations.where((c) {
      if (c.createdAt == null) return false;
      return c.createdAt!.isAfter(startDate) && c.createdAt!.isBefore(endDate);
    }).toList();

    // CSV header
    final csv = StringBuffer();
    csv.writeln(
      'ID,Patient ID,Date,ICD-10 Code,Subjective,Objective,Assessment,Plan,Created By',
    );

    // CSV rows
    for (final c in periodConsultations) {
      csv.writeln(
        '"${c.id}","${c.patientId}","${c.createdAt?.toIso8601String() ?? ''}","${c.icd10Code ?? ''}","${_escapeCsv(c.subjective)}","${_escapeCsv(c.objective)}","${_escapeCsv(c.assessment)}","${_escapeCsv(c.plan)}","${c.createdBy}"',
      );
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'consultations_$timestamp.csv';
      final path = await _fileExporter.exportTextFile(
        filename: filename,
        content: csv.toString(),
      );

      debugPrint('CSV exported to: $path');
      return path;
    } catch (e) {
      debugPrint('Error exporting CSV: $e');
      throw Exception('Failed to export CSV: $e');
    }
  }

  /// Share report via system share dialog
  Future<void> shareReport(String filePath) async {
    try {
      await _fileExporter.shareFile(
        filePath,
        subject: 'MedSentry Report',
        text: 'Please find the attached report from MedSentry.',
      );
    } catch (e) {
      debugPrint('Error sharing report: $e');
      throw Exception('Failed to share report: $e');
    }
  }

  /// Exports PDF report bytes to a user-selected location via native FilePicker / Save dialog.
  /// Returns the saved file path on Desktop/Mobile or filename on Web, or null if the user cancelled.
  Future<String?> exportReportToPdf({
    required Uint8List pdfBytes,
    required String filename,
    String? dialogTitle,
  }) async {
    try {
      final path = await _fileExporter.saveBinaryFile(
        filename: filename,
        bytes: pdfBytes,
        dialogTitle: dialogTitle ?? 'Save Report PDF',
        mimeType: 'application/pdf',
      );
      if (path != null) {
        debugPrint('Report PDF saved to: $path');
      }
      return path;
    } catch (e) {
      debugPrint('Error exporting PDF report: $e');
      throw Exception('Failed to export PDF report: $e');
    }
  }

  /// Opens an exported report file with the system viewer.
  Future<bool> openExportedReport(String filePath) async {
    return _fileExporter.openFile(filePath);
  }

  /// Get summary statistics for dashboard
  Future<Map<String, dynamic>> getDashboardStats() async {
    final patients = await _db.getAllPatients();
    final consultations = await _db.getAllConsultations();
    final queueItems = await _db.getQueueItems();

    // Today's stats
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayConsultations = consultations.where((c) {
      if (c.createdAt == null) return false;
      return c.createdAt!.isAfter(todayStart);
    }).length;

    // This month's stats
    final monthStart = DateTime(today.year, today.month, 1);
    final monthConsultations = consultations.where((c) {
      if (c.createdAt == null) return false;
      return c.createdAt!.isAfter(monthStart);
    }).length;

    // Active queue
    final activeQueue = queueItems
        .where(
          (q) =>
              q.status == QueueStatus.waiting ||
              q.status == QueueStatus.inProgress,
        )
        .length;

    return {
      'total_patients': patients.length,
      'total_consultations': consultations.length,
      'today_consultations': todayConsultations,
      'month_consultations': monthConsultations,
      'active_queue': activeQueue,
      'last_updated': DateTime.now().toIso8601String(),
    };
  }

  // Helper methods

  Map<String, int> _calculateIcd10Distribution(
    List<Consultation> consultations,
  ) {
    final distribution = <String, int>{};
    for (final consultation in consultations) {
      final code = consultation.icd10Code ?? 'Unknown';
      distribution[code] = (distribution[code] ?? 0) + 1;
    }
    return distribution;
  }

  Map<String, int> _calculateAgeDistribution(
    List<Consultation> consultations,
    List<Patient> patients,
  ) {
    final distribution = <String, int>{
      'infant': 0,
      'toddler': 0,
      'preschool': 0,
      'school_age': 0,
      'adolescent': 0,
      'adult': 0,
      'senior': 0,
      'unknown': 0,
    };

    for (final consultation in consultations) {
      final patient = patients.firstWhere(
        (p) => p.id == consultation.patientId,
        orElse: () => patients.first,
      );

      final category = patient.category;
      if (category == null) {
        distribution['unknown'] = (distribution['unknown'] ?? 0) + 1;
        continue;
      }

      switch (category) {
        case PatientCategory.infant:
          distribution['infant'] = (distribution['infant'] ?? 0) + 1;
        case PatientCategory.toddler:
          distribution['toddler'] = (distribution['toddler'] ?? 0) + 1;
        case PatientCategory.preschool:
          distribution['preschool'] = (distribution['preschool'] ?? 0) + 1;
        case PatientCategory.schoolAge:
          distribution['school_age'] = (distribution['school_age'] ?? 0) + 1;
        case PatientCategory.adolescent:
          distribution['adolescent'] = (distribution['adolescent'] ?? 0) + 1;
        case PatientCategory.adult:
          distribution['adult'] = (distribution['adult'] ?? 0) + 1;
        case PatientCategory.senior:
        case PatientCategory.seniorCitizen:
          distribution['senior'] = (distribution['senior'] ?? 0) + 1;
        default:
          distribution['unknown'] = (distribution['unknown'] ?? 0) + 1;
      }
    }

    return distribution;
  }

  Map<String, int> _calculateGenderDistribution(List<Patient> patients) {
    final distribution = <String, int>{};
    for (final patient in patients) {
      final gender = patient.gender ?? 'Unknown';
      distribution[gender] = (distribution[gender] ?? 0) + 1;
    }
    return distribution;
  }

  List<Map<String, dynamic>> _getTopDiagnoses(
    List<Consultation> consultations,
    int limit,
  ) {
    final counts = <String, int>{};
    for (final consultation in consultations) {
      final code = consultation.icd10Code ?? 'Unknown';
      counts[code] = (counts[code] ?? 0) + 1;
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted
        .take(limit)
        .map((e) => {'diagnosis': e.key, 'count': e.value})
        .toList();
  }

  List<Map<String, dynamic>> _extractNotifiableDiseases(
    List<Consultation> consultations,
  ) {
    // List of notifiable diseases (simplified)
    final notifiableCodes = [
      'A00', // Cholera
      'A01', // Typhoid
      'A80', // Polio
      'B05', // Measles
      'J10', // Influenza
      'U07', // COVID-19
    ];

    final notifiable = <Map<String, dynamic>>[];
    for (final consultation in consultations) {
      final code = consultation.icd10Code;
      if (code != null) {
        final prefix = code.substring(0, min(3, code.length));
        if (notifiableCodes.any((n) => prefix.startsWith(n))) {
          notifiable.add({
            'patient_id': consultation.patientId,
            'icd10_code': code,
            'date': consultation.createdAt?.toIso8601String(),
          });
        }
      }
    }

    return notifiable;
  }

  String _escapeCsv(String? value) {
    if (value == null) return '';
    // Escape quotes and wrap in quotes if contains special characters
    final escaped = value.replaceAll('"', '""');
    if (escaped.contains(',') ||
        escaped.contains('\n') ||
        escaped.contains('"')) {
      return '"$escaped"';
    }
    return escaped;
  }

  int min(int a, int b) => a < b ? a : b;
}
