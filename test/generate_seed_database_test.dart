import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/config/seed_credentials.dart';
import 'package:medsentry/src/services/database_seed_service.dart';
import 'package:medsentry/src/database/simple_database.dart';

void main() {
  test('seed snapshot requires an explicit development password', () {
    if (SeedCredentials.defaultPassword.isNotEmpty) return;

    final service = DatabaseSeedService(SimpleDatabase());
    expect(service.buildSeedSnapshot, throwsStateError);
  });
}
