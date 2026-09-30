enum DocumentType {
  labResult,
  xRay,
  prescription,
  medicalCertificate,
  referral,
  other,
}

enum DocumentStatus { pending, verified, archived }

class MedicalDocument {
  final String id;
  final String patientId;
  final String? consultationId;
  final DocumentType type;
  final String title;
  final String? description;
  final String filePath;
  final String? fileUrl;
  final int fileSize;
  final String? mimeType;
  final String? scannedBy;
  final DateTime? scanDate;
  final String? verifiedBy;
  final DateTime? verifiedDate;
  final DocumentStatus status;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? syncStatus;

  MedicalDocument({
    required this.id,
    required this.patientId,
    this.consultationId,
    required this.type,
    required this.title,
    this.description,
    required this.filePath,
    this.fileUrl,
    required this.fileSize,
    this.mimeType,
    this.scannedBy,
    this.scanDate,
    this.verifiedBy,
    this.verifiedDate,
    this.status = DocumentStatus.pending,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.syncStatus,
  });

  String get typeDisplay {
    switch (type) {
      case DocumentType.labResult:
        return 'Lab Result';
      case DocumentType.xRay:
        return 'X-Ray';
      case DocumentType.prescription:
        return 'Prescription';
      case DocumentType.medicalCertificate:
        return 'Medical Certificate';
      case DocumentType.referral:
        return 'Referral';
      case DocumentType.other:
        return 'Other';
    }
  }

  String get statusDisplay {
    switch (status) {
      case DocumentStatus.pending:
        return 'Pending';
      case DocumentStatus.verified:
        return 'Verified';
      case DocumentStatus.archived:
        return 'Archived';
    }
  }

  // Aliases for compatibility with UI code
  DocumentType get documentType => type;
  String? get fileType => mimeType;

  MedicalDocument copyWith({
    String? id,
    String? patientId,
    String? consultationId,
    DocumentType? type,
    String? title,
    String? description,
    String? filePath,
    String? fileUrl,
    int? fileSize,
    String? mimeType,
    String? scannedBy,
    DateTime? scanDate,
    String? verifiedBy,
    DateTime? verifiedDate,
    DocumentStatus? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? syncStatus,
  }) {
    return MedicalDocument(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      consultationId: consultationId ?? this.consultationId,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      filePath: filePath ?? this.filePath,
      fileUrl: fileUrl ?? this.fileUrl,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      scannedBy: scannedBy ?? this.scannedBy,
      scanDate: scanDate ?? this.scanDate,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      verifiedDate: verifiedDate ?? this.verifiedDate,
      status: status ?? this.status,
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
      'consultation_id': consultationId,
      'type': type.name,
      'title': title,
      'description': description,
      'file_path': filePath,
      'file_url': fileUrl,
      'file_size': fileSize,
      'mime_type': mimeType,
      'scanned_by': scannedBy,
      'scan_date': scanDate?.toIso8601String(),
      'verified_by': verifiedBy,
      'verified_date': verifiedDate?.toIso8601String(),
      'status': status.name,
      'notes': notes,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'sync_status': syncStatus,
    };
  }

  factory MedicalDocument.fromJson(Map<String, dynamic> json) {
    return MedicalDocument(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      consultationId: json['consultation_id'] as String?,
      type: DocumentType.values.byName(json['type'] as String),
      title: json['title'] as String,
      description: json['description'] as String?,
      filePath: json['file_path'] as String? ?? '',
      fileUrl: json['file_url'] as String?,
      fileSize: (json['file_size'] as num?)?.toInt() ?? 0,
      mimeType: json['mime_type'] as String?,
      scannedBy: json['scanned_by'] as String?,
      scanDate: json['scan_date'] != null
          ? DateTime.parse(json['scan_date'] as String)
          : null,
      verifiedBy: json['verified_by'] as String?,
      verifiedDate: json['verified_date'] != null
          ? DateTime.parse(json['verified_date'] as String)
          : null,
      status: DocumentStatus.values.byName(json['status'] as String),
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
      other is MedicalDocument &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
