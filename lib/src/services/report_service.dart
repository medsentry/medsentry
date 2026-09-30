import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../database/simple_database.dart';
import '../models/models.dart';
import '../utils/file_exporter/file_exporter.dart';

/// Service for generating DOH reports and analytics
class ReportService {
  final SimpleDatabase _db;
  final FileExporter _fileExporter = createFileExporter();

  ReportService(this._db);

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
