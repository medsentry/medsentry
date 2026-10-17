class IssuedCertificate {
  final String id;
  final String patientId;
  final String patientName;
  final String? clinicId;
  final String certificateType;
  final String? purpose;
  final String? diagnosis;
  final String? clinicalFindings;
  final String? recommendations;
  final int? restDays;
  final String issuedBy;
  final String? issuerLicense;
  final String? issuerTitle;
  final DateTime issuedAt;
  final String status;

  const IssuedCertificate({
    required this.id,
    required this.patientId,
    required this.patientName,
    this.clinicId,
    required this.certificateType,
    this.purpose,
    this.diagnosis,
    String? clinicalFindings,
    String? findings,
    this.recommendations,
    this.restDays,
    required this.issuedBy,
    String? issuerLicense,
    String? licenseNumber,
    this.issuerTitle,
    required this.issuedAt,
    this.status = 'Active',
  }) : clinicalFindings = clinicalFindings ?? findings,
       issuerLicense = issuerLicense ?? licenseNumber;

  String? get findings => clinicalFindings ?? diagnosis;
  String? get licenseNumber => issuerLicense;

  IssuedCertificate copyWith({
    String? id,
    String? patientId,
    String? patientName,
    String? clinicId,
    String? certificateType,
    String? purpose,
    String? diagnosis,
    String? clinicalFindings,
    String? recommendations,
    int? restDays,
    String? issuedBy,
    String? issuerLicense,
    String? issuerTitle,
    DateTime? issuedAt,
    String? status,
  }) {
    return IssuedCertificate(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      clinicId: clinicId ?? this.clinicId,
      certificateType: certificateType ?? this.certificateType,
      purpose: purpose ?? this.purpose,
      diagnosis: diagnosis ?? this.diagnosis,
      clinicalFindings: clinicalFindings ?? this.clinicalFindings,
      recommendations: recommendations ?? this.recommendations,
      restDays: restDays ?? this.restDays,
      issuedBy: issuedBy ?? this.issuedBy,
      issuerLicense: issuerLicense ?? this.issuerLicense,
      issuerTitle: issuerTitle ?? this.issuerTitle,
      issuedAt: issuedAt ?? this.issuedAt,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'patient_name': patientName,
      if (clinicId != null) 'clinic_id': clinicId,
      'certificate_type': certificateType,
      'purpose': purpose,
      'diagnosis': diagnosis,
      'clinical_findings': clinicalFindings,
      'recommendations': recommendations,
      'rest_days': restDays,
      'issued_by': issuedBy,
      'issuer_license': issuerLicense,
      'issuer_title': issuerTitle,
      'issued_at': issuedAt.toIso8601String(),
      'status': status,
    };
  }

  factory IssuedCertificate.fromJson(Map<String, dynamic> json) {
    return IssuedCertificate(
      id: json['id'] as String,
      patientId: json['patient_id'] as String? ?? '',
      patientName: json['patient_name'] as String? ?? 'Unknown Patient',
      clinicId: json['clinic_id'] as String?,
      certificateType:
          json['certificate_type'] as String? ?? 'Medical Certificate',
      purpose: json['purpose'] as String?,
      diagnosis: json['diagnosis'] as String?,
      clinicalFindings: json['clinical_findings'] as String?,
      recommendations: json['recommendations'] as String?,
      restDays: (json['rest_days'] as num?)?.toInt(),
      issuedBy: json['issued_by'] as String? ?? 'Medical Officer',
      issuerLicense: json['issuer_license'] as String?,
      issuerTitle: json['issuer_title'] as String?,
      issuedAt: DateTime.tryParse(json['issued_at']?.toString() ?? '') ??
          DateTime.now(),
      status: json['status'] as String? ?? 'Active',
    );
  }
}
