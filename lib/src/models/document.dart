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
  final DocumentType type;
  final String title;
  final String? description;
  final String filePath;
  final String? fileUrl;
  final String? storagePath;
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
    required this.type,
    required this.title,
    this.description,
    required this.filePath,
    this.fileUrl,
    this.storagePath,
    required this.fileSize,
    this.mimeType,
    this.scannedBy,
    this.scanDate,
    this.verifiedBy,
    this.verifiedDate,
    this.status = DocumentStatus.verified,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.syncStatus,
  });

  String get typeDisplay {
    switch (type) {
      case DocumentType.labResult:
        return 'Laboratory Result';
      case DocumentType.xRay:
        return 'X-Ray / Imaging';
      case DocumentType.prescription:
        return 'Prescription';
      case DocumentType.medicalCertificate:
        return 'Medical Certificate';
      case DocumentType.referral:
        return 'Referral Letter';
      case DocumentType.other:
        return 'Other Document';
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
    DocumentType? type,
    String? title,
    String? description,
    String? filePath,
    String? fileUrl,
    String? storagePath,
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
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      filePath: filePath ?? this.filePath,
      fileUrl: fileUrl ?? this.fileUrl,
      storagePath: storagePath ?? this.storagePath,
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
      'type': type.name,
      'title': title,
      'description': description,
      'file_path': filePath,
      'file_url': fileUrl,
      'storage_path': storagePath,
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
    final rawType = json['type'] as String?;
    final rawStatus = json['status'] as String?;

    return MedicalDocument(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      type: DocumentType.values.firstWhere(
        (e) => e.name.toLowerCase() == (rawType ?? '').trim().toLowerCase(),
        orElse: () => DocumentType.other,
      ),
      title: json['title'] as String? ?? 'Untitled Document',
      description: json['description'] as String?,
      filePath: json['file_path'] as String? ?? '',
      fileUrl: json['file_url'] as String?,
      storagePath: json['storage_path'] as String?,
      fileSize: (json['file_size'] as num?)?.toInt() ?? 0,
      mimeType: json['mime_type'] as String?,
      scannedBy: json['scanned_by'] as String?,
      scanDate: json['scan_date'] != null
          ? DateTime.tryParse(json['scan_date'] as String)
          : null,
      verifiedBy: json['verified_by'] as String?,
      verifiedDate: json['verified_date'] != null
          ? DateTime.tryParse(json['verified_date'] as String)
          : null,
      status: DocumentStatus.values.firstWhere(
        (e) => e.name.toLowerCase() == (rawStatus ?? '').trim().toLowerCase(),
        orElse: () => DocumentStatus.pending,
      ),
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
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
