/// Clinic / RHU system configuration managed by Admin.
class SystemSettings {
  final String clinicName;
  final String clinicType;
  final String clinicCode;
  final String clinicAddress;
  final String clinicContact;
  final String municipality;
  final String province;
  final String operatingHours;
  final String patientIdPrefix;
  final int patientIdSequence;
  final int passwordMinLength;
  final bool requireStrongPassword;
  final int sessionTimeoutMinutes;
  final bool autoSyncEnabled;
  final int autoSyncIntervalMinutes;
  final int dataRetentionDays;
  final List<String> serviceTypes;
  final List<String> patientCategories;
  final bool queueModuleEnabled;
  final bool certificatesModuleEnabled;
  final bool syncModuleEnabled;
  final DateTime? updatedAt;

  const SystemSettings({
    this.clinicName = 'Rural Health Unit',
    this.clinicType = 'Community Health Clinic',
    this.clinicCode = 'RHU',
    this.clinicAddress = '',
    this.clinicContact = '',
    this.municipality = '',
    this.province = '',
    this.operatingHours = 'Monday–Friday, 8:00 AM–5:00 PM',
    this.patientIdPrefix = 'RHU',
    this.patientIdSequence = 1,
    this.passwordMinLength = 8,
    this.requireStrongPassword = true,
    this.sessionTimeoutMinutes = 480,
    this.autoSyncEnabled = true,
    this.autoSyncIntervalMinutes = 30,
    this.dataRetentionDays = 365,
    this.serviceTypes = const [
      'General Consultation',
      'Prenatal',
      'Immunization',
      'Family Planning',
      'Dental',
      'Laboratory',
    ],
    this.patientCategories = const [
      'Infant',
      'Pediatric',
      'Adult',
      'Senior',
      'PWD',
      'Pregnant',
    ],
    this.queueModuleEnabled = true,
    this.certificatesModuleEnabled = true,
    this.syncModuleEnabled = true,
    this.updatedAt,
  });

  SystemSettings copyWith({
    String? clinicName,
    String? clinicType,
    String? clinicCode,
    String? clinicAddress,
    String? clinicContact,
    String? municipality,
    String? province,
    String? operatingHours,
    String? patientIdPrefix,
    int? patientIdSequence,
    int? passwordMinLength,
    bool? requireStrongPassword,
    int? sessionTimeoutMinutes,
    bool? autoSyncEnabled,
    int? autoSyncIntervalMinutes,
    int? dataRetentionDays,
    List<String>? serviceTypes,
    List<String>? patientCategories,
    bool? queueModuleEnabled,
    bool? certificatesModuleEnabled,
    bool? syncModuleEnabled,
    DateTime? updatedAt,
  }) {
    return SystemSettings(
      clinicName: clinicName ?? this.clinicName,
      clinicType: clinicType ?? this.clinicType,
      clinicCode: clinicCode ?? this.clinicCode,
      clinicAddress: clinicAddress ?? this.clinicAddress,
      clinicContact: clinicContact ?? this.clinicContact,
      municipality: municipality ?? this.municipality,
      province: province ?? this.province,
      operatingHours: operatingHours ?? this.operatingHours,
      patientIdPrefix: patientIdPrefix ?? this.patientIdPrefix,
      patientIdSequence: patientIdSequence ?? this.patientIdSequence,
      passwordMinLength: passwordMinLength ?? this.passwordMinLength,
      requireStrongPassword:
          requireStrongPassword ?? this.requireStrongPassword,
      sessionTimeoutMinutes:
          sessionTimeoutMinutes ?? this.sessionTimeoutMinutes,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      autoSyncIntervalMinutes:
          autoSyncIntervalMinutes ?? this.autoSyncIntervalMinutes,
      dataRetentionDays: dataRetentionDays ?? this.dataRetentionDays,
      serviceTypes: serviceTypes ?? this.serviceTypes,
      patientCategories: patientCategories ?? this.patientCategories,
      queueModuleEnabled: queueModuleEnabled ?? this.queueModuleEnabled,
      certificatesModuleEnabled:
          certificatesModuleEnabled ?? this.certificatesModuleEnabled,
      syncModuleEnabled: syncModuleEnabled ?? this.syncModuleEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String generateNextPatientId() {
    final year = DateTime.now().year;
    return '$patientIdPrefix-$year-${patientIdSequence.toString().padLeft(5, '0')}';
  }

  Map<String, dynamic> toJson() => {
    'clinic_name': clinicName,
    'clinic_type': clinicType,
    'clinic_code': clinicCode,
    'clinic_address': clinicAddress,
    'clinic_contact': clinicContact,
    'municipality': municipality,
    'province': province,
    'operating_hours': operatingHours,
    'patient_id_prefix': patientIdPrefix,
    'patient_id_sequence': patientIdSequence,
    'password_min_length': passwordMinLength,
    'require_strong_password': requireStrongPassword,
    'session_timeout_minutes': sessionTimeoutMinutes,
    'auto_sync_enabled': autoSyncEnabled,
    'auto_sync_interval_minutes': autoSyncIntervalMinutes,
    'data_retention_days': dataRetentionDays,
    'service_types': serviceTypes,
    'patient_categories': patientCategories,
    'queue_module_enabled': queueModuleEnabled,
    'certificates_module_enabled': certificatesModuleEnabled,
    'sync_module_enabled': syncModuleEnabled,
    'updated_at': updatedAt?.toIso8601String(),
  };

  factory SystemSettings.fromJson(Map<String, dynamic> json) {
    return SystemSettings(
      clinicName: json['clinic_name'] as String? ?? 'Rural Health Unit',
      clinicType: json['clinic_type'] as String? ?? 'Community Health Clinic',
      clinicCode: json['clinic_code'] as String? ?? 'RHU',
      clinicAddress: json['clinic_address'] as String? ?? '',
      clinicContact: json['clinic_contact'] as String? ?? '',
      municipality: json['municipality'] as String? ?? '',
      province: json['province'] as String? ?? '',
      operatingHours:
          json['operating_hours'] as String? ??
          'Monday–Friday, 8:00 AM–5:00 PM',
      patientIdPrefix: json['patient_id_prefix'] as String? ?? 'RHU',
      patientIdSequence: json['patient_id_sequence'] as int? ?? 1,
      passwordMinLength: json['password_min_length'] as int? ?? 8,
      requireStrongPassword: json['require_strong_password'] as bool? ?? true,
      sessionTimeoutMinutes: json['session_timeout_minutes'] as int? ?? 480,
      autoSyncEnabled: json['auto_sync_enabled'] as bool? ?? true,
      autoSyncIntervalMinutes: json['auto_sync_interval_minutes'] as int? ?? 30,
      dataRetentionDays: json['data_retention_days'] as int? ?? 365,
      serviceTypes:
          (json['service_types'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [
            'General Consultation',
            'Prenatal',
            'Immunization',
            'Family Planning',
            'Dental',
            'Laboratory',
          ],
      patientCategories:
          (json['patient_categories'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const ['Infant', 'Pediatric', 'Adult', 'Senior', 'PWD', 'Pregnant'],
      queueModuleEnabled: json['queue_module_enabled'] as bool? ?? true,
      certificatesModuleEnabled:
          json['certificates_module_enabled'] as bool? ?? true,
      syncModuleEnabled: json['sync_module_enabled'] as bool? ?? true,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
}
