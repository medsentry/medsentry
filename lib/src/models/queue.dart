import 'package:flutter/material.dart';

import '../providers/theme_provider.dart';

enum QueueStatus { waiting, inProgress, completed, cancelled }

enum Priority { low, normal, high, emergency }

/// Red flag conditions for Smart Triage
enum RedFlag {
  severeChestPain, // Severe chest pain
  difficultyBreathing, // Difficulty breathing
  activeBleeding, // Active bleeding
  alteredMentalStatus, // Altered mental status
  severeAbdominalPain, // Severe abdominal pain
  seizure, // Seizure
  unconscious, // Unconscious
  highFever, // High fever (>40°C)
  severeDehydration, // Severe dehydration
  anaphylaxis, // Anaphylaxis/allergic reaction
}

/// Extension for RedFlag display names
extension RedFlagExtension on RedFlag {
  String get displayName {
    switch (this) {
      case RedFlag.severeChestPain:
        return 'Severe Chest Pain';
      case RedFlag.difficultyBreathing:
        return 'Difficulty Breathing';
      case RedFlag.activeBleeding:
        return 'Active Bleeding';
      case RedFlag.alteredMentalStatus:
        return 'Altered Mental Status';
      case RedFlag.severeAbdominalPain:
        return 'Severe Abdominal Pain';
      case RedFlag.seizure:
        return 'Seizure';
      case RedFlag.unconscious:
        return 'Unconscious';
      case RedFlag.highFever:
        return 'High Fever (>40°C)';
      case RedFlag.severeDehydration:
        return 'Severe Dehydration';
      case RedFlag.anaphylaxis:
        return 'Anaphylaxis';
    }
  }
}

class QueueItem {
  final String id;
  final String patientId;
  final String? patientName; // Added for display purposes

  // Patient category for triage (from Patient model)
  final bool isSenior;
  final bool isPregnant;
  final bool isPwd;
  final bool isInfant;

  // Queue timing
  final DateTime arrivalTime;
  final DateTime? startTime;
  final DateTime? endTime;
  final QueueStatus status;

  // Staff assignment
  final String? nurseId;
  final String? doctorId;

  // Chief complaint & notes
  final String? complaint;
  final String? notes;
  final String? purpose;

  // Vital Signs
  final double? temperature;
  final double? bloodPressureSystolic;
  final double? bloodPressureDiastolic;
  final double? heartRate;
  final double? respiratoryRate;
  final double? oxygenSaturation;
  final double? weight;
  final double? height;

  // Smart Triage Fields
  final List<RedFlag> redFlags; // Critical conditions
  final int? painScale; // 0-10 pain scale
  final bool isEssentiallyNormal; // Quick normal PE toggle

  // Priority & Room
  final Priority priority;
  final String? roomNumber;

  // Auto-calculated fields
  final double? bmi; // Auto-calculated from height/weight

  // System fields
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? syncStatus;

  QueueItem({
    required this.id,
    required this.patientId,
    this.patientName,
    this.isSenior = false,
    this.isPregnant = false,
    this.isPwd = false,
    this.isInfant = false,
    required this.arrivalTime,
    this.startTime,
    this.endTime,
    this.status = QueueStatus.waiting,
    this.nurseId,
    this.doctorId,
    this.complaint,
    this.notes,
    this.purpose,
    this.temperature,
    this.bloodPressureSystolic,
    this.bloodPressureDiastolic,
    this.heartRate,
    this.respiratoryRate,
    this.oxygenSaturation,
    this.weight,
    this.height,
    this.redFlags = const [],
    this.painScale,
    this.isEssentiallyNormal = false,
    this.priority = Priority.normal,
    this.roomNumber,
    this.bmi,
    this.createdAt,
    this.updatedAt,
    this.syncStatus,
  });

  String get statusDisplay {
    switch (status) {
      case QueueStatus.waiting:
        return 'Waiting';
      case QueueStatus.inProgress:
        return 'In Progress';
      case QueueStatus.completed:
        return 'Completed';
      case QueueStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get priorityDisplay {
    switch (priority) {
      case Priority.low:
        return 'Low';
      case Priority.normal:
        return 'Normal';
      case Priority.high:
        return 'High';
      case Priority.emergency:
        return 'Emergency';
    }
  }

  Color get statusColor {
    switch (status) {
      case QueueStatus.waiting:
        return Colors.orange;
      case QueueStatus.inProgress:
        return Colors.blue;
      case QueueStatus.completed:
        return Colors.green;
      case QueueStatus.cancelled:
        return Colors.red;
    }
  }

  Color get priorityColor {
    switch (priority) {
      case Priority.low:
        return Colors.grey;
      case Priority.normal:
        return Colors.blue;
      case Priority.high:
        return Colors.orange;
      case Priority.emergency:
        return Colors.red;
    }
  }

  int get waitTimeMinutes {
    final end = endTime ?? DateTime.now();
    return end.difference(arrivalTime).inMinutes;
  }

  String get waitTimeDisplay {
    final minutes = waitTimeMinutes;
    if (minutes < 60) {
      return '${minutes}m';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '${hours}h ${remainingMinutes}m';
    }
  }

  bool get vitalsTaken {
    return temperature != null ||
        bloodPressureSystolic != null ||
        bloodPressureDiastolic != null ||
        heartRate != null ||
        respiratoryRate != null ||
        oxygenSaturation != null ||
        weight != null ||
        height != null;
  }

  QueueItem copyWith({
    String? id,
    String? patientId,
    String? patientName,
    bool? isSenior,
    bool? isPregnant,
    bool? isPwd,
    bool? isInfant,
    DateTime? arrivalTime,
    DateTime? startTime,
    DateTime? endTime,
    QueueStatus? status,
    String? nurseId,
    String? doctorId,
    String? complaint,
    String? notes,
    String? purpose,
    double? temperature,
    double? bloodPressureSystolic,
    double? bloodPressureDiastolic,
    double? heartRate,
    double? respiratoryRate,
    double? oxygenSaturation,
    double? weight,
    double? height,
    List<RedFlag>? redFlags,
    int? painScale,
    bool? isEssentiallyNormal,
    Priority? priority,
    String? roomNumber,
    double? bmi,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? syncStatus,
  }) {
    return QueueItem(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      isSenior: isSenior ?? this.isSenior,
      isPregnant: isPregnant ?? this.isPregnant,
      isPwd: isPwd ?? this.isPwd,
      isInfant: isInfant ?? this.isInfant,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      nurseId: nurseId ?? this.nurseId,
      doctorId: doctorId ?? this.doctorId,
      complaint: complaint ?? this.complaint,
      notes: notes ?? this.notes,
      purpose: purpose ?? this.purpose,
      temperature: temperature ?? this.temperature,
      bloodPressureSystolic:
          bloodPressureSystolic ?? this.bloodPressureSystolic,
      bloodPressureDiastolic:
          bloodPressureDiastolic ?? this.bloodPressureDiastolic,
      heartRate: heartRate ?? this.heartRate,
      respiratoryRate: respiratoryRate ?? this.respiratoryRate,
      oxygenSaturation: oxygenSaturation ?? this.oxygenSaturation,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      redFlags: redFlags ?? this.redFlags,
      painScale: painScale ?? this.painScale,
      isEssentiallyNormal: isEssentiallyNormal ?? this.isEssentiallyNormal,
      priority: priority ?? this.priority,
      roomNumber: roomNumber ?? this.roomNumber,
      bmi: bmi ?? this.bmi,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'patient_name': patientName,
      'is_senior': isSenior,
      'is_pregnant': isPregnant,
      'is_pwd': isPwd,
      'is_infant': isInfant,
      'arrival_time': arrivalTime.toIso8601String(),
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'status': status.name,
      'nurse_id': nurseId,
      'doctor_id': doctorId,
      'complaint': complaint,
      'notes': notes,
      'purpose': purpose,
      'temperature': temperature,
      'blood_pressure_systolic': bloodPressureSystolic,
      'blood_pressure_diastolic': bloodPressureDiastolic,
      'heart_rate': heartRate,
      'respiratory_rate': respiratoryRate,
      'oxygen_saturation': oxygenSaturation,
      'weight': weight,
      'height': height,
      'red_flags': redFlags.map((f) => f.name).toList(),
      'pain_scale': painScale,
      'is_essentially_normal': isEssentiallyNormal,
      'priority': priority.name,
      'room_number': roomNumber,
      'bmi': bmi,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'sync_status': syncStatus,
    };
  }

  factory QueueItem.fromJson(Map<String, dynamic> json) {
    return QueueItem(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      patientName: json['patient_name'] as String?,
      isSenior: json['is_senior'] as bool? ?? false,
      isPregnant: json['is_pregnant'] as bool? ?? false,
      isPwd: json['is_pwd'] as bool? ?? false,
      isInfant: json['is_infant'] as bool? ?? false,
      arrivalTime: DateTime.parse(json['arrival_time'] as String),
      startTime: json['start_time'] != null
          ? DateTime.parse(json['start_time'] as String)
          : null,
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : null,
      status: QueueStatus.values.byName(json['status'] as String),
      nurseId: json['nurse_id'] as String?,
      doctorId: json['doctor_id'] as String?,
      complaint: json['complaint'] as String?,
      notes: json['notes'] as String?,
      purpose: json['purpose'] as String?,
      temperature: json['temperature'] != null
          ? (json['temperature'] as num).toDouble()
          : null,
      bloodPressureSystolic: json['blood_pressure_systolic'] != null
          ? (json['blood_pressure_systolic'] as num).toDouble()
          : null,
      bloodPressureDiastolic: json['blood_pressure_diastolic'] != null
          ? (json['blood_pressure_diastolic'] as num).toDouble()
          : null,
      heartRate: json['heart_rate'] != null
          ? (json['heart_rate'] as num).toDouble()
          : null,
      respiratoryRate: json['respiratory_rate'] != null
          ? (json['respiratory_rate'] as num).toDouble()
          : null,
      oxygenSaturation: json['oxygen_saturation'] != null
          ? (json['oxygen_saturation'] as num).toDouble()
          : null,
      weight: json['weight'] != null
          ? (json['weight'] as num).toDouble()
          : null,
      height: json['height'] != null
          ? (json['height'] as num).toDouble()
          : null,
      redFlags: json['red_flags'] != null
          ? (json['red_flags'] as List<dynamic>)
                .map((f) => RedFlag.values.byName(f as String))
                .toList()
          : [],
      painScale: json['pain_scale'] as int?,
      isEssentiallyNormal: json['is_essentially_normal'] as bool? ?? false,
      priority: Priority.values.byName(json['priority'] as String),
      roomNumber: json['room_number'] as String?,
      bmi: json['bmi'] != null ? (json['bmi'] as num).toDouble() : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      syncStatus: json['sync_status'] as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueueItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

extension QueueItemThemeExtensions on QueueItem {
  Color prioritySemanticColor(BuildContext context) {
    // We cannot import context_extensions directly here because it might cause circular issues.
    // Wait, let's just use Theme.of(context).extension<SemanticColors>()
    final ext = Theme.of(context).extension<SemanticColors>();
    // Fallback if null (shouldn't be)
    if (ext == null) return Colors.grey;

    switch (priority) {
      case Priority.low:
        return ext.neutral;
      case Priority.normal:
        return ext.info;
      case Priority.high:
        return ext.warning;
      case Priority.emergency:
        return ext.critical;
    }
  }

  Color statusSemanticColor(BuildContext context) {
    final ext = Theme.of(context).extension<SemanticColors>();
    if (ext == null) return Colors.grey;

    switch (status) {
      case QueueStatus.waiting:
        return ext.warning;
      case QueueStatus.inProgress:
        return ext.info;
      case QueueStatus.completed:
        return ext.normal;
      case QueueStatus.cancelled:
        return ext.critical;
    }
  }
}
