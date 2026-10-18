import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/database/simple_database.dart';
import 'package:medsentry/src/models/user.dart';

void main() {
  late Directory tempDirectory;
  late SimpleDatabase database;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('medsentry-users-');
    database = SimpleDatabase();
    await database.useStoreFileForTesting(
      File('${tempDirectory.path}${Platform.pathSeparator}store.json'),
    );
  });

  tearDown(() async {
    await tempDirectory.delete(recursive: true);
  });

  test('permanently removes the user and local credentials', () async {
    final user = User(
      id: 'user-to-delete',
      email: 'delete@example.com',
      firstName: 'Delete',
      lastName: 'Me',
      role: UserRole.staff,
      clinicId: 'clinic-1',
      isActive: false,
      pinEnabled: false,
    );

    await database.insertUser(user, passwordHash: 'password-hash');
    await database.setLastUserId(user.id);

    await database.deleteUser(user.id);

    expect(await database.getUserById(user.id), isNull);
    expect(await database.getUserPasswordHash(user.id), isNull);
    expect(await database.getLastUserId(), isNull);
  });
}
