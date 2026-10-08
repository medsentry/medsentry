class Consultation {
  final String id;
  final String patientId;
  final String? doctorId;
  final DateTime? consultationDate;
  final String? subjective;
  final String? objective;
  final String? assessment;
  final String? plan;
  final String? icd10Code;
  final String? icd10Description;
  final bool isFollowUp;
  final String? followUpInstructions;
  final String? notes;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? syncStatus;

  Consultation({
    required this.id,
    required this.patientId,
    this.doctorId,
    this.consultationDate,
    this.subjective,
    this.objective,
    this.assessment,
    this.plan,
    this.icd10Code,
    this.icd10Description,
    this.isFollowUp = false,
    this.followUpInstructions,
    this.notes,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.syncStatus,
  });

  Consultation copyWith({
    String? id,
    String? patientId,
    String? doctorId,
    DateTime? consultationDate,
    String? subjective,
    String? objective,
    String? assessment,
    String? plan,
    String? icd10Code,
    String? icd10Description,
    bool? isFollowUp,
    String? followUpInstructions,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? syncStatus,
  }) {
    return Consultation(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      consultationDate: consultationDate ?? this.consultationDate,
      subjective: subjective ?? this.subjective,
      objective: objective ?? this.objective,
      assessment: assessment ?? this.assessment,
      plan: plan ?? this.plan,
      icd10Code: icd10Code ?? this.icd10Code,
      icd10Description: icd10Description ?? this.icd10Description,
      isFollowUp: isFollowUp ?? this.isFollowUp,
      followUpInstructions: followUpInstructions ?? this.followUpInstructions,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'doctor_id': doctorId,
      'consultation_date': consultationDate?.toIso8601String(),
      'subjective': subjective,
      'objective': objective,
      'assessment': assessment,
      'plan': plan,
      'icd10_code': icd10Code,
      'icd10_description': icd10Description,
      'is_follow_up': isFollowUp,
      'follow_up_instructions': followUpInstructions,
      'notes': notes,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'sync_status': syncStatus,
    };
  }

  factory Consultation.fromJson(Map<String, dynamic> json) {
    return Consultation(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      doctorId: json['doctor_id'] as String?,
      consultationDate: json['consultation_date'] != null
          ? DateTime.parse(json['consultation_date'] as String)
          : null,
      subjective: json['subjective'] as String?,
      objective: json['objective'] as String?,
      assessment: json['assessment'] as String?,
      plan: json['plan'] as String?,
      icd10Code: json['icd10_code'] as String?,
      icd10Description: json['icd10_description'] as String?,
      isFollowUp: json['is_follow_up'] as bool? ?? false,
      followUpInstructions: json['follow_up_instructions'] as String?,
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
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
      other is Consultation &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class Prescription {
  final String id;
  final String consultationId;
  final String medicationName;
  final String? genericName;
  final String dosage;
  final String frequency;
  final String duration;
  final String? instructions;
  final int quantity;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? syncStatus;

  Prescription({
    required this.id,
    required this.consultationId,
    required this.medicationName,
    this.genericName,
    required this.dosage,
    required this.frequency,
    required this.duration,
    this.instructions,
    required this.quantity,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.syncStatus,
  });

  Prescription copyWith({
    String? id,
    String? consultationId,
    String? medicationName,
    String? genericName,
    String? dosage,
    String? frequency,
    String? duration,
    String? instructions,
    int? quantity,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? syncStatus,
  }) {
    return Prescription(
      id: id ?? this.id,
      consultationId: consultationId ?? this.consultationId,
      medicationName: medicationName ?? this.medicationName,
      genericName: genericName ?? this.genericName,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      duration: duration ?? this.duration,
      instructions: instructions ?? this.instructions,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'consultation_id': consultationId,
      'medication_name': medicationName,
      'generic_name': genericName,
      'dosage': dosage,
      'frequency': frequency,
      'duration': duration,
      'instructions': instructions,
      'quantity': quantity,
      'notes': notes,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'sync_status': syncStatus,
    };
  }

  factory Prescription.fromJson(Map<String, dynamic> json) {
    return Prescription(
      id: json['id'] as String,
      consultationId: json['consultation_id'] as String,
      medicationName: json['medication_name'] as String,
      genericName: json['generic_name'] as String?,
      dosage: json['dosage'] as String,
      frequency: json['frequency'] as String,
      duration: json['duration'] as String,
      instructions: json['instructions'] as String?,
      quantity: json['quantity'] as int,
      notes: json['notes'] as String?,
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
      other is Prescription &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class LabOrder {
  final String id;
  final String consultationId;
  final String testName;
  final String? testCode;
  final String? instructions;
  final String status;
  final DateTime? requestedDate;
  final DateTime? completedDate;
  final String? results;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? syncStatus;

  LabOrder({
    required this.id,
    required this.consultationId,
    required this.testName,
    this.testCode,
    this.instructions,
    this.status = 'pending',
    this.requestedDate,
    this.completedDate,
    this.results,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.syncStatus,
  });

  LabOrder copyWith({
    String? id,
    String? consultationId,
    String? testName,
    String? testCode,
    String? instructions,
    String? status,
    DateTime? requestedDate,
    DateTime? completedDate,
    String? results,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? syncStatus,
  }) {
    return LabOrder(
      id: id ?? this.id,
      consultationId: consultationId ?? this.consultationId,
      testName: testName ?? this.testName,
      testCode: testCode ?? this.testCode,
      instructions: instructions ?? this.instructions,
      status: status ?? this.status,
      requestedDate: requestedDate ?? this.requestedDate,
      completedDate: completedDate ?? this.completedDate,
      results: results ?? this.results,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'consultation_id': consultationId,
      'test_name': testName,
      'test_code': testCode,
      'instructions': instructions,
      'status': status,
      'requested_date': requestedDate?.toIso8601String(),
      'completed_date': completedDate?.toIso8601String(),
      'results': results,
      'notes': notes,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'sync_status': syncStatus,
    };
  }

  factory LabOrder.fromJson(Map<String, dynamic> json) {
    return LabOrder(
      id: json['id'] as String,
      consultationId: json['consultation_id'] as String,
      testName: json['test_name'] as String,
      testCode: json['test_code'] as String?,
      instructions: json['instructions'] as String?,
      status: json['status'] as String? ?? 'pending',
      requestedDate: json['requested_date'] != null
          ? DateTime.parse(json['requested_date'] as String)
          : null,
      completedDate: json['completed_date'] != null
          ? DateTime.parse(json['completed_date'] as String)
          : null,
      results: json['results'] as String?,
      notes: json['notes'] as String?,
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
      other is LabOrder && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
