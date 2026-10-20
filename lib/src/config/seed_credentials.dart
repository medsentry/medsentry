import '../models/user.dart';

/// Development-only sample account definitions.
/// Passwords are never stored here — only hashed at seed/runtime.
class SeedCredentials {
  SeedCredentials._();

  static const String defaultPassword = String.fromEnvironment(
    'MEDSENTRY_SEED_PASSWORD',
    defaultValue: 'Password123!',
  );

  static const List<SeedAccount> accounts = [
    SeedAccount(
      id: '00000000-0000-4000-8000-000000000001',
      clinicId: null,
      email: 'superadmin@gmail.com',
      firstName: 'System',
      lastName: 'SuperAdmin',
      role: UserRole.superAdmin,
      contactNumber: '09170000001',
    ),
    SeedAccount(
      id: '00000000-0000-4000-8000-000000000002',
      clinicId: '11111111-1111-4111-8111-111111111111',
      email: 'admin@gmail.com',
      firstName: 'Dr. Elena',
      lastName: 'Ramos',
      role: UserRole.admin,
      licenseNumber: 'PRC-0129845',
      specialization: 'Municipal Health Officer (MHO)',
      contactNumber: '09170000002',
    ),
    SeedAccount(
      id: '00000000-0000-4000-8000-000000000003',
      clinicId: '11111111-1111-4111-8111-111111111111',
      email: 'staff@gmail.com',
      firstName: 'Joy',
      lastName: 'Fernandez, RN',
      role: UserRole.staff,
      licenseNumber: 'PRC-0294821',
      specialization: 'Public Health Nurse / Triage',
      contactNumber: '09170000003',
    ),
  ];
}

class SeedAccount {
  final String id;
  final String? clinicId;
  final String email;
  final String firstName;
  final String lastName;
  final UserRole role;
  final String? licenseNumber;
  final String? specialization;
  final String? contactNumber;

  const SeedAccount({
    required this.id,
    this.clinicId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.licenseNumber,
    this.specialization,
    this.contactNumber,
  });
}
