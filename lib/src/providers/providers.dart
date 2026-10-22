import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/simple_database.dart';
import '../services/audit_service.dart';
import '../services/database_seed_service.dart';
import '../repositories/auth_repository.dart';
import '../repositories/patient_repository.dart';
import '../repositories/clinic_repository.dart';
import '../models/user.dart';
import '../models/patient.dart';
import '../models/document.dart';
import '../models/audit_log.dart';
import '../models/clinic.dart';

// Export other providers
export 'theme_provider.dart';
export 'sync_provider.dart';
export 'dashboard_provider.dart';
export 'reports_provider.dart';
export 'settings_provider.dart';
export 'feature_providers.dart';
export 'activity_feed_provider.dart';
export '../utils/pwa/pwa_installer.dart';

import '../utils/pwa/pwa_installer.dart';

part 'providers.g.dart';

// Database instance
@Riverpod(keepAlive: true)
SimpleDatabase database(Ref ref) {
  return SimpleDatabase();
}

/// A durable-write revision for refreshing cached role views. This guarantees
/// frontend screens immediately refresh whenever the database is updated.
class DatabaseChangesNotifier extends StateNotifier<int> {
  final SimpleDatabase _db;
  StreamSubscription<int>? _subscription;

  DatabaseChangesNotifier(this._db) : super(_db.revision) {
    _subscription = _db.changes.listen((newRevision) {
      if (mounted) state = newRevision;
    });
  }

  void refresh() {
    state = _db.revision;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final databaseChangesProvider =
    StateNotifierProvider<DatabaseChangesNotifier, int>((ref) {
  final db = ref.watch(databaseProvider);
  return DatabaseChangesNotifier(db);
});

@Riverpod(keepAlive: true)
AuditService auditService(Ref ref) {
  final db = ref.watch(databaseProvider);
  return AuditService(db);
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  final db = ref.watch(databaseProvider);
  final audit = ref.watch(auditServiceProvider);
  return AuthRepository(db, audit);
}

final databaseSeedServiceProvider = Provider<DatabaseSeedService>((ref) {
  return DatabaseSeedService(ref.watch(databaseProvider));
});

@Riverpod(keepAlive: true)
PatientRepository patientRepository(Ref ref) {
  final db = ref.watch(databaseProvider);
  final audit = ref.watch(auditServiceProvider);
  return PatientRepository(db, audit);
}

final clinicRepositoryProvider = Provider<ClinicRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final audit = ref.watch(auditServiceProvider);
  return ClinicRepository(db, audit);
});

final clinicsProvider = FutureProvider<List<Clinic>>((ref) async {
  ref.watch(databaseChangesProvider);
  return ref.watch(clinicRepositoryProvider).getClinics();
});

// Auth State
final currentUserProvider = StateProvider<User?>((ref) => null);

/// Active clinic ID for scoping RHU Admin and Staff queries (null for Super Admin).
final activeClinicIdProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.isSuperAdmin) return null;
  return user.clinicId;
});

@Riverpod(keepAlive: true)
Future<List<User>> users(Ref ref) async {
  ref.watch(databaseChangesProvider);
  final repository = ref.watch(authRepositoryProvider);
  final u = await repository.getAllUsers();
  u.sort(
    (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
  );
  return u;
}

// ==========================================
// SHARED LOCAL DATA PROVIDERS
// ==========================================

@Riverpod(keepAlive: true)
Future<List<Patient>> patients(Ref ref) {
  ref.watch(databaseChangesProvider);
  final clinicId = ref.watch(activeClinicIdProvider);
  return ref.watch(databaseProvider).getAllPatients(clinicId: clinicId);
}

final patientSearchProvider = FutureProvider.family<List<Patient>, String>((
  ref,
  query,
) async {
  ref.watch(databaseChangesProvider);
  final clinicId = ref.watch(activeClinicIdProvider);
  return ref.watch(patientRepositoryProvider).searchPatients(
    query,
    clinicId: clinicId,
  );
});

@Riverpod(keepAlive: true)
Future<Patient?> patient(Ref ref, String patientId) {
  ref.watch(databaseChangesProvider);
  return ref.watch(databaseProvider).getPatientById(patientId);
}

@Riverpod(keepAlive: true)
Future<List<MedicalDocument>> documents(Ref ref) {
  ref.watch(databaseChangesProvider);
  final clinicId = ref.watch(activeClinicIdProvider);
  return ref.watch(databaseProvider).getDocuments(clinicId: clinicId);
}

@Riverpod(keepAlive: true)
Future<List<MedicalDocument>> patientDocuments(Ref ref, String patientId) {
  ref.watch(databaseChangesProvider);
  return ref.watch(databaseProvider).getDocumentsForPatient(patientId);
}

@Riverpod(keepAlive: true)
Future<List<AuditLog>> patientAuditLogs(Ref ref, String patientId) {
  ref.watch(databaseChangesProvider);
  return ref.watch(databaseProvider).getAuditLogsForPatient(patientId);
}

final pwaInstallerProvider = Provider<PwaInstaller>((ref) {
  return createPwaInstaller();
});
