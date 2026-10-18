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

  String get displayName {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'Admin';
      case UserRole.staff:
        return 'Staff';
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
  final bool isReactivated;
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
    this.isReactivated = false,
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
  String get roleDisplayName => role.displayName;

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

  bool get canRegisterPatients => isSuperAdmin || isAdmin || isStaff;
  bool get canEditPatients => canRegisterPatients;
  bool get canDeletePatientRecords => isSuperAdmin || isAdmin;
  bool get canManageDocuments => isSuperAdmin || isAdmin || isStaff;
  bool get canManageSystemData => isSuperAdmin || isAdmin;
  bool get canViewAuditLogs => isSuperAdmin || isAdmin;
  bool get canManageArchive => isSuperAdmin || isAdmin;
  bool get canManageStaffAccounts => isSuperAdmin || isAdmin;
  bool get canManageSecurity => isSuperAdmin || isAdmin;
  bool get canBackupSync => isSuperAdmin || isAdmin;
  bool get canManageBackupSync => isSuperAdmin || isAdmin;
  bool get canSyncRecords => isSuperAdmin || isAdmin || isStaff;
  bool get canGenerateCertificates => isSuperAdmin || isAdmin || isStaff;
  bool get canAccessPatientRecords => isSuperAdmin || isAdmin || isStaff;
  bool get canGenerateReports => isSuperAdmin || isAdmin || isStaff;
  bool get canViewReports => canGenerateReports;
  bool get canAccessSettings => isSuperAdmin || isAdmin;

  // Explicit RBAC capabilities for Admin & Super Admin
  bool get canEditUserProfiles => isSuperAdmin || isAdmin;
  bool get canResetUserPasswords => isSuperAdmin || isAdmin;
  bool get canManageUserRoles => isSuperAdmin || isAdmin;

  /// Staff and RHU Admin must confirm an emailed one-time code at every
  /// password login. Super Admin is exempt.
  bool get requiresEmailOtp => isAdmin || isStaff;

  RolePermissions get permissions => RolePermissions(this);

  String get accountStatusDisplay {
    if (!isActive) return 'Inactive';
    if (isReactivated) return 'Reactivated';
    return 'Active';
  }

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
    bool? isReactivated,
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
      isReactivated: isReactivated ?? this.isReactivated,
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
      'is_reactivated': isReactivated,
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
      isReactivated: json['is_reactivated'] as bool? ?? false,
      pinEnabled: json['pin_enabled'] as bool? ?? false,
      pinHash: json['pin_hash'] as String?,
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.tryParse(json['last_login_at'] as String)
          : null,
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
      other is User && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class RolePermissions {
  final User _user;

  const RolePermissions(this._user);

  bool get canRegisterPatients => _user.canRegisterPatients;
  bool get canEditPatients => _user.canEditPatients;
  bool get canDeletePatientRecords => _user.canDeletePatientRecords;
  bool get canManageDocuments => _user.canManageDocuments;
  bool get canManageSystemData => _user.canManageSystemData;
  bool get canViewAuditLogs => _user.canViewAuditLogs;
  bool get canManageArchive => _user.canManageArchive;
  bool get canManageStaffAccounts => _user.canManageStaffAccounts;
  bool get canManageSecurity => _user.canManageSecurity;
  bool get canBackupSync => _user.canBackupSync;
  bool get canManageBackupSync => _user.canManageBackupSync;
  bool get canSyncRecords => _user.canSyncRecords;
  bool get canGenerateCertificates => _user.canGenerateCertificates;
  bool get canAccessPatientRecords => _user.canAccessPatientRecords;
  bool get canGenerateReports => _user.canGenerateReports;
  bool get canViewReports => _user.canViewReports;
  bool get canAccessSettings => _user.canAccessSettings;
  bool get requiresEmailOtp => _user.requiresEmailOtp;
}
