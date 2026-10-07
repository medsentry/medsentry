import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

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
import '../models/queue.dart';
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
final databaseChangesProvider = StreamProvider<int>((ref) {
  return ref.watch(databaseProvider).changes;
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

@Riverpod(keepAlive: true)
QueueRepository queueRepository(Ref ref) {
  final db = ref.watch(databaseProvider);
  return QueueRepository(db);
}

final clinicRepositoryProvider = Provider<ClinicRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final audit = ref.watch(auditServiceProvider);
  return ClinicRepository(db, audit);
});

final clinicsProvider = FutureProvider<List<Clinic>>((ref) async {
  ref.watch(databaseChangesProvider);
  final currentUser = ref.watch(currentUserProvider);
  final client = Supabase.instance.client;

  // Local writes refresh this provider through databaseChangesProvider. This
  // channel refreshes the RHU list when another signed-in device changes it.
  if (currentUser != null && client.auth.currentSession != null) {
    final channel = client
        .channel('medsentry-clinics-${currentUser.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'clinics',
          callback: (change) {
            if (change.eventType == PostgresChangeEvent.delete) {
              final id = change.oldRecord['id'];
              if (id is String) {
                unawaited(ref.read(databaseProvider).deleteClinic(id));
              }
            }
            ref.invalidateSelf();
          },
        )
        .subscribe();
    ref.onDispose(() => client.removeChannel(channel));
  }

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
Future<List<QueueItem>> queue(Ref ref) {
  ref.watch(databaseChangesProvider);
  return ref.watch(databaseProvider).getQueueItems();
}

@Riverpod(keepAlive: true)
Future<QueueItem?> queueItem(Ref ref, String queueItemId) {
  ref.watch(databaseChangesProvider);
  return ref.watch(databaseProvider).getQueueItemById(queueItemId);
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
Future<List<QueueItem>> patientQueueHistory(Ref ref, String patientId) async {
  ref.watch(databaseChangesProvider);
  final items = await ref.watch(databaseProvider).getQueueItems();
  return items.where((item) => item.patientId == patientId).toList();
}

@Riverpod(keepAlive: true)
Future<List<AuditLog>> patientAuditLogs(Ref ref, String patientId) {
  ref.watch(databaseChangesProvider);
  return ref.watch(databaseProvider).getAuditLogsForPatient(patientId);
}

// Dummy queue repository class until fully migrated
class QueueRepository {
  final SimpleDatabase _db;
  QueueRepository(this._db);

  Future<void> removeFromQueue(String queueItemId) async {
    await _db.removeFromQueue(queueItemId);
  }

  Future<void> addToQueue(
    String patientId,
    String patientName,
    String purpose, {
    String? complaint,
    Priority priority = Priority.normal,
    bool isSenior = false,
    bool isPregnant = false,
    bool isPwd = false,
    bool isInfant = false,
  }) async {
    await _db.addToQueue(
      patientId,
      patientName,
      purpose,
      complaint: complaint,
      priority: priority,
      isSenior: isSenior,
      isPregnant: isPregnant,
      isPwd: isPwd,
      isInfant: isInfant,
    );
  }

  Future<void> updateQueueItem(QueueItem item) async {
    await _db.updateQueueItem(item);
  }
}

final pwaInstallerProvider = Provider<PwaInstaller>((ref) {
  return createPwaInstaller();
});
