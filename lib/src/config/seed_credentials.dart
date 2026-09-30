import '../models/user.dart';

/// Development-only sample account definitions.
/// Passwords are never stored here — only hashed at seed/runtime.
class SeedCredentials {
  SeedCredentials._();

  static const String defaultPassword = String.fromEnvironment(
    'MEDSENTRY_SEED_PASSWORD',
    defaultValue: '',
  );

  static const List<SeedAccount> accounts = [
    SeedAccount(
      id: 'a0000001-0001-4001-8001-000000000001',
      email: 'admin@gmail.com',
      firstName: 'Maria',
      lastName: 'Santos',
      role: UserRole.admin,
      contactNumber: '09171234501',
    ),
    SeedAccount(
      id: 'a0000002-0002-4002-8002-000000000002',
      email: 'staff@gmail.com',
      firstName: 'Juan',
      lastName: 'Dela Cruz',
      role: UserRole.staff,
      contactNumber: '09171234502',
      specialization: 'Clinic Staff',
    ),
    SeedAccount(
      id: 'a0000003-0003-4003-8003-000000000003',
      email: 'doctor@gmail.com',
      firstName: 'Ana',
      lastName: 'Reyes',
      role: UserRole.staff,
      licenseNumber: 'MD-2024-001',
      specialization: 'General Medicine',
      contactNumber: '09171234503',
    ),
    SeedAccount(
      id: 'a0000004-0004-4004-8004-000000000004',
      email: 'nurse@gmail.com',
      firstName: 'Rosa',
      lastName: 'Garcia',
      role: UserRole.staff,
      licenseNumber: 'RN-2024-001',
      specialization: 'Registered Nurse',
      contactNumber: '09171234504',
    ),
  ];
}

class SeedAccount {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final UserRole role;
  final String? licenseNumber;
  final String? specialization;
  final String? contactNumber;

  const SeedAccount({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.licenseNumber,
    this.specialization,
    this.contactNumber,
  });
}
