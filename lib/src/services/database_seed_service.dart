import 'dart:convert';

import '../config/seed_credentials.dart';
import '../database/simple_database.dart';
import '../models/models.dart';
import '../utils/password_crypto.dart';
import 'seed/seed_exporter.dart';

/// Seeds the initial super administrator account for MedSentry.
/// Passwords are stored as PBKDF2 hashes only — never plaintext.
/// All clinical records (patients, queue, consultations, etc.) start empty.
class DatabaseSeedService {
  static const bool _allowSeed = bool.fromEnvironment(
    'MEDSENTRY_SEED_DATABASE',
    defaultValue: false,
  );

  final SimpleDatabase _db;

  DatabaseSeedService(this._db);

  bool get isSeedAllowed => _allowSeed;

  Future<bool> isDatabaseEmpty() async {
    final patients = await _db.getAllPatients(includeArchived: true);
    return patients.isEmpty;
  }

  /// Seeds initial user account when database is empty.
  Future<bool> seedIfEmpty({bool force = false}) async {
    if (!_allowSeed && !force) return false;
    if (!force && !await isDatabaseEmpty()) return false;

    final snapshot = buildSeedSnapshot();
    await _db.importSeedSnapshot(snapshot);
    return true;
  }

  /// Builds the seed snapshot (safe to serialize — no plaintext passwords).
  Map<String, dynamic> buildSeedSnapshot() {
    if (SeedCredentials.defaultPassword.length < 12) {
      throw StateError(
        'MEDSENTRY_SEED_PASSWORD must be set to a strong development-only password',
      );
    }

    final now = DateTime.now();
    final seedTime = DateTime(now.year, now.month, now.day, 8, 0);
    final passwordHashes = <String, String>{};

    final users = SeedCredentials.accounts.map((account) {
      passwordHashes[account.id] = PasswordCrypto.hashDeterministic(
        SeedCredentials.defaultPassword,
        'pwd:${account.id}',
      );
      return User(
        id: account.id,
        clinicId: account.clinicId,
        email: account.email,
        firstName: account.firstName,
        lastName: account.lastName,
        role: account.role,
        licenseNumber: account.licenseNumber,
        specialization: account.specialization,
        contactNumber: account.contactNumber,
        isActive: true,
        pinEnabled: false,
        pinHash: null,
        createdAt: seedTime,
        updatedAt: seedTime,
        syncStatus: 0,
      );
    }).toList();

    return {
      'version': 1,
      'patients': <Map<String, dynamic>>[],
      'users': users.map((e) => e.toJson()).toList(),
      'queue_items': <Map<String, dynamic>>[],
      'consultations': <Map<String, dynamic>>[],
      'prescriptions': <Map<String, dynamic>>[],
      'lab_orders': <Map<String, dynamic>>[],
      'documents': <Map<String, dynamic>>[],
      'audit_logs': <Map<String, dynamic>>[],
      'generated_reports': <Map<String, dynamic>>[],
      'user_password_hashes': passwordHashes,
      'last_user_id': SeedCredentials.accounts.first.id,
      'system_settings': const SystemSettings(
        clinicName: 'MedSentry Platform',
        clinicAddress: 'Central Office',
        clinicContact: '',
        patientIdPrefix: 'RHU',
        patientIdSequence: 1,
        passwordMinLength: 8,
        requireStrongPassword: true,
        sessionTimeoutMinutes: 480,
        autoSyncEnabled: true,
        dataRetentionDays: 365,
      ).toJson(),
      'notifications': <Map<String, dynamic>>[],
    };
  }

  Future<dynamic> exportSeedToFile(String outputPath) async {
    final snapshot = buildSeedSnapshot();
    const encoder = JsonEncoder.withIndent('  ');
    final content = encoder.convert(snapshot);
    final exporter = createSeedExporter();
    return await exporter.exportToFile(outputPath, content);
  }
}
