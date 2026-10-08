import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/drift_database.dart';
import '../database/simple_database.dart';
import '../services/audit_service.dart';
import '../services/database_seed_service.dart';
import '../repositories/auth_repository.dart';
import '../repositories/consultation_repository.dart';
import '../repositories/patient_repository.dart';
import '../repositories/clinic_repository.dart';
import '../models/user.dart';
import '../models/patient.dart';
import '../models/document.dart';
import '../models/consultation.dart';
import '../models/audit_log.dart';
import '../models/clinic.dart';

// Export other providers
export 'theme_provider.dart';
export 'sync_provider.dart';
export 'dashboard_provider.dart';
export 'reports_provider.dart';
export 'settings_provider.dart';
export 'feature_providers.dart';
export '../utils/pwa/pwa_installer.dart';

import '../utils/pwa/pwa_installer.dart';

part 'providers.g.dart';

// Database instances
@Riverpod(keepAlive: true)
MedSentryDatabase driftDatabase(Ref ref) {
  return MedSentryDatabase();
}

@Riverpod(keepAlive: true)
SimpleDatabase database(Ref ref) {
  return SimpleDatabase();
}

/// A durable-write revision for refreshing cached role views. This prevents
/// staff/admin screens from continuing to show a stale FutureProvider result.
final databaseChangesProvider = StreamProvider<int>((ref) async* {
  final db = ref.watch(databaseProvider);
  yield db.revision;
  yield* db.changes;
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

  // NOTE: Repository initialized with simple local state for writes,
  // but reads are provided via Drift below to eliminate flickering!
  return PatientRepository(db, audit);
}

@Riverpod(keepAlive: true)
ConsultationRepository consultationRepository(Ref ref) {
  final db = ref.watch(databaseProvider);
  final audit = ref.watch(auditServiceProvider);
  return ConsultationRepository(db, audit);
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

// App State
final isLoadingProvider = StateProvider<bool>((ref) => false);
final errorMessageProvider = StateProvider<String?>((ref) => null);

// ==========================================
// SHARED LOCAL DATA PROVIDERS
// ==========================================

@Riverpod(keepAlive: true)
Future<List<Patient>> patients(Ref ref) {
  ref.watch(databaseChangesProvider);
  return ref.watch(databaseProvider).getAllPatients();
}

final patientSearchProvider = FutureProvider.family<List<Patient>, String>((
  ref,
  query,
) async {
  ref.watch(databaseChangesProvider);
  return ref.watch(patientRepositoryProvider).searchPatients(query);
});

@Riverpod(keepAlive: true)
Future<Patient?> patient(Ref ref, String patientId) {
  ref.watch(databaseChangesProvider);
  return ref.watch(databaseProvider).getPatientById(patientId);
}

@Riverpod(keepAlive: true)
Future<List<MedicalDocument>> documents(Ref ref) {
  ref.watch(databaseChangesProvider);
  return ref.watch(databaseProvider).getDocuments();
}

@Riverpod(keepAlive: true)
Future<List<Consultation>> patientConsultations(Ref ref, String patientId) {
  ref.watch(databaseChangesProvider);
  return ref.watch(databaseProvider).getConsultationsForPatient(patientId);
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
