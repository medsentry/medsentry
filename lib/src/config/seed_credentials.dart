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
