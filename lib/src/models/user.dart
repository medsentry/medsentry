enum UserRole { superAdmin, admin, staff }

extension UserRoleX on UserRole {
  String get dbValue {
    switch (this) {
      case UserRole.superAdmin:
        return 'super_admin';
      case UserRole.admin:
        return 'admin';
      case UserRole.staff:
        return 'staff';
    }
  }

  static UserRole fromDbValue(String value) {
    switch (value.toLowerCase()) {
      case 'super_admin':
      case 'superadmin':
        return UserRole.superAdmin;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.staff;
    }
  }
}

class User {
  final String id;
  final String? clinicId;
  final String email;
  final String firstName;
  final String lastName;
  final UserRole role;
  final String? licenseNumber;
  final String? specialization;
  final String? contactNumber;
  final String? profileImageUrl;
  final bool isActive;
  final bool pinEnabled;
  final String? pinHash;
  final DateTime? lastLoginAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? syncStatus;

  User({
    required this.id,
    this.clinicId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.licenseNumber,
    this.specialization,
    this.contactNumber,
    this.profileImageUrl,
    required this.isActive,
    required this.pinEnabled,
    this.pinHash,
    this.lastLoginAt,
    this.createdAt,
    this.updatedAt,
    this.syncStatus,
  });

  String get name => '$firstName $lastName';
  String get fullName => '$firstName $lastName';
  String get displayName => name;
  String get displayRole => role.name.toUpperCase();
  String get roleDisplay => displayRole;

  String get initials {
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '${firstName[0]}${lastName[0]}'.toUpperCase();
    } else if (firstName.isNotEmpty) {
      return firstName[0].toUpperCase();
    } else if (email.isNotEmpty) {
      return email[0].toUpperCase();
    }
    return 'U';
  }

  bool get isSuperAdmin => role == UserRole.superAdmin;
  bool get isAdmin => role == UserRole.admin;
  bool get isStaff => role == UserRole.staff;

  bool get canRegisterPatients => isStaff;
  bool get canRecordVitals => isStaff;
  bool get canConsult => isStaff;
  bool get canManageDocuments => isAdmin || isStaff;
  bool get canManageSystemData => isSuperAdmin || isAdmin;
  bool get canViewAuditLogs => isSuperAdmin || isAdmin;
  bool get canManageArchive => isAdmin;
  bool get canManageStaffAccounts => isSuperAdmin || isAdmin;
  bool get canManageSecurity => isSuperAdmin || isAdmin;
  bool get canManageBackupSync => isAdmin;
  bool get canSyncRecords => isSuperAdmin || isAdmin || isStaff;
  bool get canGenerateCertificates => isStaff;
  bool get canAccessPatientRecords => isSuperAdmin || isAdmin || isStaff;
  bool get canGenerateReports => isSuperAdmin || isAdmin || isStaff;

  String get homePath => '/dashboard';

  User copyWith({
    String? id,
    String? clinicId,
    bool clearClinicId = false,
    String? email,
    String? firstName,
    String? lastName,
    UserRole? role,
    String? licenseNumber,
    String? specialization,
    String? contactNumber,
    String? profileImageUrl,
    bool? isActive,
    bool? pinEnabled,
    String? pinHash,
    DateTime? lastLoginAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? syncStatus,
  }) {
    return User(
      id: id ?? this.id,
      clinicId: clearClinicId ? null : (clinicId ?? this.clinicId),
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      role: role ?? this.role,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      specialization: specialization ?? this.specialization,
      contactNumber: contactNumber ?? this.contactNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      isActive: isActive ?? this.isActive,
      pinEnabled: pinEnabled ?? this.pinEnabled,
      pinHash: pinHash ?? this.pinHash,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (clinicId != null) 'clinic_id': clinicId,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'role': role.dbValue,
      'license_number': licenseNumber,
      'specialization': specialization,
      'contact_number': contactNumber,
      'profile_image_url': profileImageUrl,
      'is_active': isActive,
      'pin_enabled': pinEnabled,
      'pin_hash': pinHash,
      'last_login_at': lastLoginAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'sync_status': syncStatus,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      clinicId: json['clinic_id'] as String?,
      email: json['email'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      role: UserRoleX.fromDbValue(json['role'] as String? ?? 'staff'),
      licenseNumber: json['license_number'] as String?,
      specialization: json['specialization'] as String?,
      contactNumber: json['contact_number'] as String?,
      profileImageUrl: json['profile_image_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      pinEnabled: json['pin_enabled'] as bool? ?? false,
      pinHash: json['pin_hash'] as String?,
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.parse(json['last_login_at'] as String)
          : null,
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
      other is User && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class AuthSession {
  final String userId;
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  AuthSession({
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'expires_at': expiresAt.toIso8601String(),
    };
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      userId: json['user_id'] as String,
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }
}
