import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/models/user.dart';

void main() {
  User userWithRole(UserRole role) => User(
    id: role.name,
    email: '${role.name}@example.com',
    firstName: 'Test',
    lastName: 'User',
    role: role,
    isActive: true,
    pinEnabled: false,
  );

  test('all authenticated roles can sync within their permitted scope', () {
    expect(userWithRole(UserRole.superAdmin).canSyncRecords, isTrue);
    expect(userWithRole(UserRole.admin).canSyncRecords, isTrue);
    expect(userWithRole(UserRole.staff).canSyncRecords, isTrue);
  });
}
