import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/config/supabase_config.dart';
import 'package:medsentry/src/config/seed_credentials.dart';
import 'package:medsentry/src/database/simple_database.dart';
import 'package:medsentry/src/repositories/auth_repository.dart';
import 'package:medsentry/src/services/audit_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  });

  test('no sample accounts are provisioned by default', () async {
    expect(SeedCredentials.defaultPassword, isEmpty);

    final db = SimpleDatabase();
    await db.clearAll();
    final audit = AuditService(db);
    final repo = AuthRepository(db, audit);

    await repo.ensureDefaultAccounts();

    expect(await db.getAllUsers(), isEmpty);
  });
}
