import 'dart:async';
import 'dart:convert';

import '../models/models.dart';
import '../models/generated_report.dart';
import 'storage/database_storage.dart';

class SimpleDatabase {
  static final SimpleDatabase _instance = SimpleDatabase._internal();
  factory SimpleDatabase() => _instance;
  SimpleDatabase._internal();

  final DatabaseStorage _storage = createDatabaseStorage();

  final Map<String, Patient> _patients = {};
  final Map<String, User> _users = {};
  final Map<String, Clinic> _clinics = {};
  final Map<String, Consultation> _consultations = {};
  final Map<String, Prescription> _prescriptions = {};
  final Map<String, LabOrder> _labOrders = {};
  final Map<String, MedicalDocument> _documents = {};
  final Map<String, AuditLog> _auditLogs = {};
  final Map<String, GeneratedReport> _generatedReports = {};
  final Map<String, String> _userPasswordHashes = {};
  final Map<String, DateTime> _syncDeletes = {};
  final Map<String, dynamic> _medicalSnippets = {};
  final Map<String, SystemNotification> _notifications = {};
  SystemSettings _systemSettings = const SystemSettings();
  String? _lastUserId;

  Future<void>? _loadFuture;
  bool _legacyRetiredClinicalDataPresent = false;
  final StreamController<int> _changes = StreamController<int>.broadcast();
  int _revision = 0;

  /// Emits after a durable local write. UI providers use this to refresh every
  /// authorized view from the same local source of truth.
  Stream<int> get changes => _changes.stream;
  int get revision => _revision;

  void notifyChanges() {
    _changes.add(++_revision);
  }

  Future<void> useStoreFileForTesting(dynamic file) async {
    _storage.setCustomStoreFile(file);
    _loadFuture = null;
    _patients.clear();
    _users.clear();
    _clinics.clear();
    _legacyRetiredClinicalDataPresent = false;
    _consultations.clear();
    _prescriptions.clear();
    _labOrders.clear();
    _documents.clear();
    _auditLogs.clear();
    _generatedReports.clear();
    _userPasswordHashes.clear();
    _syncDeletes.clear();
    _medicalSnippets.clear();
    _notifications.clear();
    _systemSettings = const SystemSettings();
    await _ensureLoaded();
  }

  Future<void> _ensureLoaded() {
    return _loadFuture ??= _loadFromDisk();
  }

  Future<void> _loadFromDisk() async {
    final raw = await _storage.readStore();
    if (raw == null || raw.trim().isEmpty) return;

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final hasRetiredRecords = [
      'queue_items',
      'consultation',
      'consultations',
      'prescriptions',
      'lab_orders',
    ].any((key) => decoded[key] is List && (decoded[key] as List).isNotEmpty);
    final documents = decoded['documents'];
    final hasLegacyDocumentLinks =
        documents is List &&
        documents.any(
          (document) => document is Map && document['consultation_id'] != null,
        );
    _legacyRetiredClinicalDataPresent =
        hasRetiredRecords || hasLegacyDocumentLinks;
    _restoreMap(decoded['patients'], _patients, Patient.fromJson);
    _restoreMap(decoded['users'], _users, User.fromJson);
    _deduplicateUsers();
    _restoreMap(decoded['clinics'], _clinics, Clinic.fromJson);
    _restoreMap(decoded['documents'], _documents, MedicalDocument.fromJson);
    _restoreMap(decoded['audit_logs'], _auditLogs, AuditLog.fromJson);
    _restoreMap(
      decoded['generated_reports'],
      _generatedReports,
      GeneratedReport.fromJson,
    );

    final hashes = decoded['user_password_hashes'];
    if (hashes is Map) {
      _userPasswordHashes
        ..clear()
        ..addAll(hashes.cast<String, String>());
    }

    // last logged in user id (for PIN login fallback)
    final lastId = decoded['last_user_id'];
    if (lastId is String) {
      _lastUserId = lastId;
    }

    final settings = decoded['system_settings'];
    if (settings is Map<String, dynamic>) {
      _systemSettings = SystemSettings.fromJson(settings);
    }

    _restoreMap(
      decoded['notifications'],
      _notifications,
      SystemNotification.fromJson,
    );
    _restoreSyncDeletes(decoded['sync_deletes']);
  }

  void _restoreSyncDeletes(dynamic raw) {
    _syncDeletes.clear();
    if (raw is! List) return;
    for (final item in raw.whereType<Map>()) {
      final table = item['table'];
      final id = item['record_id'];
      final deletedAt = item['deleted_at'];
      if (table is String && id is String && deletedAt is String) {
        _syncDeletes['$table|$id'] = DateTime.parse(deletedAt);
      }
    }
  }

  void _recordSyncDelete(String table, String id) {
    _syncDeletes['$table|$id'] = DateTime.now();
  }

  List<Map<String, String>> _syncDeleteJson() =>
      _syncDeletes.entries.map((entry) {
        final separator = entry.key.indexOf('|');
        return {
          'table': entry.key.substring(0, separator),
          'record_id': entry.key.substring(separator + 1),
          'deleted_at': entry.value.toIso8601String(),
        };
      }).toList();

  void _restoreMap<T>(
    dynamic raw,
    Map<String, T> target,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (raw is! List) return;
    target
      ..clear()
      ..addEntries(
        raw.whereType<Map>().map((item) {
          final entity = fromJson(item.cast<String, dynamic>());
          final id = item['id'] as String;
          return MapEntry(id, entity);
        }),
      );
  }

  void _deduplicateUsers() {
    final seenEmails = <String, User>{};
    final toRemove = <String>[];
    for (final user in _users.values) {
      final emailLower = user.email.toLowerCase();
      if (seenEmails.containsKey(emailLower)) {
        final existing = seenEmails[emailLower]!;
        final userDate =
            user.updatedAt ??
            user.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final existingDate =
            existing.updatedAt ??
            existing.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        if ((user.syncStatus == 0 && existing.syncStatus != 0) ||
            userDate.isAfter(existingDate)) {
          toRemove.add(existing.id);
          seenEmails[emailLower] = user;
        } else {
          toRemove.add(user.id);
        }
      } else {
        seenEmails[emailLower] = user;
      }
    }
    for (final id in toRemove) {
      _users.remove(id);
      _userPasswordHashes.remove(id);
    }
  }

  Future<void> _saveToDisk() async {
    await _ensureLoaded();
    final data = {
      'version': 1,
      'patients': _patients.values.map((e) => e.toJson()).toList(),
      'users': _users.values.map((e) => e.toJson()).toList(),
      'clinics': _clinics.values.map((e) => e.toJson()).toList(),
      'documents': _documents.values.map((e) => e.toJson()).toList(),
      'audit_logs': _auditLogs.values.map((e) => e.toJson()).toList(),
      'generated_reports': _generatedReports.values
          .map((e) => e.toJson())
          .toList(),
      'user_password_hashes': _userPasswordHashes,
      'last_user_id': _lastUserId,
      'system_settings': _systemSettings.toJson(),
      'notifications': _notifications.values.map((e) => e.toJson()).toList(),
      'sync_deletes': _syncDeleteJson(),
    };

    notifyChanges();
    await _storage.writeStore(jsonEncode(data));
  }

  Future<String> createBackup() async {
    await _ensureLoaded();
    final data = {
      'version': 1,
      'patients': _patients.values.map((e) => e.toJson()).toList(),
      'users': _users.values.map((e) => e.toJson()).toList(),
      'clinics': _clinics.values.map((e) => e.toJson()).toList(),
      'documents': _documents.values.map((e) => e.toJson()).toList(),
      'audit_logs': _auditLogs.values.map((e) => e.toJson()).toList(),
      'generated_reports': _generatedReports.values
          .map((e) => e.toJson())
          .toList(),
      'user_password_hashes': _userPasswordHashes,
      'last_user_id': _lastUserId,
      'system_settings': _systemSettings.toJson(),
      'notifications': _notifications.values.map((e) => e.toJson()).toList(),
      'sync_deletes': _syncDeleteJson(),
    };

    return await _storage.createBackup(jsonEncode(data));
  }

  Future<void> importSeedSnapshot(Map<String, dynamic> decoded) async {
    await _ensureLoaded();
    if (decoded['patients'] is! List || decoded['users'] is! List) {
      throw ArgumentError('Invalid MedSentry seed snapshot');
    }

    _patients.clear();
    _users.clear();
    _clinics.clear();
    _consultations.clear();
    _prescriptions.clear();
    _labOrders.clear();
    _documents.clear();
    _auditLogs.clear();
    _generatedReports.clear();
    _userPasswordHashes.clear();
    _syncDeletes.clear();
    _medicalSnippets.clear();
    _notifications.clear();

    _restoreMap(decoded['patients'], _patients, Patient.fromJson);
    _restoreMap(decoded['users'], _users, User.fromJson);
    _restoreMap(decoded['clinics'], _clinics, Clinic.fromJson);
    _restoreMap(decoded['documents'], _documents, MedicalDocument.fromJson);
    _restoreMap(decoded['audit_logs'], _auditLogs, AuditLog.fromJson);
    _restoreMap(
      decoded['generated_reports'],
      _generatedReports,
      GeneratedReport.fromJson,
    );

    final hashes = decoded['user_password_hashes'];
    if (hashes is Map) {
      _userPasswordHashes.addAll(hashes.cast<String, String>());
    }

    final lastId = decoded['last_user_id'];
    if (lastId is String) {
      _lastUserId = lastId;
    }

    final settings = decoded['system_settings'];
    if (settings is Map<String, dynamic>) {
      _systemSettings = SystemSettings.fromJson(settings);
    } else {
      _systemSettings = const SystemSettings();
    }

    _restoreMap(
      decoded['notifications'],
      _notifications,
      SystemNotification.fromJson,
    );
    _restoreSyncDeletes(decoded['sync_deletes']);

    await _saveToDisk();
  }

  Future<void> restoreFromBackup(dynamic backupFile) async {
    await _ensureLoaded();
    final String raw;
    if (backupFile is String) {
      raw = backupFile;
    } else {
      raw = await (backupFile as dynamic).readAsString();
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> ||
        decoded['patients'] is! List ||
        decoded['users'] is! List) {
      throw ArgumentError('Invalid MedSentry backup file');
    }

    await _storage.writeStore(raw);

    _loadFuture = null;
    _patients.clear();
    _users.clear();
    _clinics.clear();
    _legacyRetiredClinicalDataPresent = false;
    _documents.clear();
    _auditLogs.clear();
    _generatedReports.clear();
    _userPasswordHashes.clear();
    _syncDeletes.clear();
    _medicalSnippets.clear();
    _notifications.clear();
    _systemSettings = const SystemSettings();
    await _ensureLoaded();
  }

  // Persist the last logged in user id (used for PIN quick-login fallback)
  Future<void> setLastUserId(String? id) async {
    await _ensureLoaded();
    _lastUserId = id;
    await _saveToDisk();
  }

  Future<String?> getLastUserId() async {
    await _ensureLoaded();
    return _lastUserId;
  }

  Future<void> insertPatient(Patient patient) async {
    await _ensureLoaded();
    _patients[patient.id] = patient;
    await _saveToDisk();
  }

  Future<Patient?> getPatientById(String id) async {
    await _ensureLoaded();
    return _patients[id];
  }

  Future<List<Patient>> getAllPatients({bool includeArchived = false}) async {
    await _ensureLoaded();
    return _patients.values
        .where((p) => includeArchived || !p.isArchived)
        .toList();
  }

  Future<List<Patient>> getPatientsPaginated(int limit, int offset) async {
    await _ensureLoaded();
    final allPatients = _patients.values.where((p) => !p.isArchived).toList();
    allPatients.sort((a, b) {
      final bDate = b.updatedAt ?? b.createdAt;
      final aDate = a.updatedAt ?? a.createdAt;
      if (bDate == null && aDate == null) return 0;
      if (bDate == null) return -1;
      if (aDate == null) return 1;
      return bDate.compareTo(aDate);
    });

    final start = offset;
    final end = (offset + limit).clamp(0, allPatients.length);
    if (start >= allPatients.length) return [];
    return allPatients.sublist(start, end);
  }

  Future<void> updatePatient(Patient patient) async {
    await _ensureLoaded();
    _patients[patient.id] = patient;
    await _saveToDisk();
  }

  Future<void> deletePatient(String id) async {
    await _ensureLoaded();
    if (_patients.containsKey(id)) _recordSyncDelete('patients', id);
    _patients.remove(id);
    await _saveToDisk();
  }

  Future<int> getPatientCount({bool includeArchived = false}) async {
    await _ensureLoaded();
    if (includeArchived) return _patients.length;
    return _patients.values.where((p) => !p.isArchived).length;
  }

  Future<List<Patient>> searchPatients(String query) async {
    await _ensureLoaded();
    final lowerQuery = query.trim().toLowerCase();
    if (lowerQuery.isEmpty) return getAllPatients();
    final normalizedQuery = lowerQuery.replaceAll(RegExp(r'[^a-z0-9]'), '');

    bool containsSearchTerm(String? value) {
      if (value == null || value.isEmpty) return false;
      final lowerValue = value.toLowerCase();
      return lowerValue.contains(lowerQuery) ||
          (normalizedQuery.isNotEmpty &&
              lowerValue
                  .replaceAll(RegExp(r'[^a-z0-9]'), '')
                  .contains(normalizedQuery));
    }

    return _patients.values.where((p) {
      if (p.isArchived) return false;
      return containsSearchTerm(p.fullName) ||
          containsSearchTerm(p.id) ||
          containsSearchTerm(p.localLguIdNumber) ||
          containsSearchTerm(p.contactNumber) ||
          containsSearchTerm(p.philHealthNumber);
    }).toList();
  }

  Future<List<Patient>> getPatientsByBarangay(String barangay) async {
    await _ensureLoaded();
    return _patients.values
        .where((p) => p.barangay?.toLowerCase() == barangay.toLowerCase())
        .toList();
  }

  Future<List<Patient>> getRecentPatients(int limit) async {
    await _ensureLoaded();
    final allPatients = _patients.values.where((p) => !p.isArchived).toList();
    allPatients.sort((a, b) {
      if (b.createdAt == null && a.createdAt == null) return 0;
      if (b.createdAt == null) return -1;
      if (a.createdAt == null) return 1;
      return b.createdAt!.compareTo(a.createdAt!);
    });
    return allPatients.take(limit).toList();
  }

  Future<void> insertUser(User user, {String? passwordHash}) async {
    await _ensureLoaded();
    final duplicates = _users.values
        .where(
          (u) =>
              u.email.toLowerCase() == user.email.toLowerCase() &&
              u.id != user.id,
        )
        .toList();
    for (final old in duplicates) {
      _users.remove(old.id);
      final oldHash = _userPasswordHashes.remove(old.id);
      if (passwordHash == null && oldHash != null) {
        passwordHash = oldHash;
      }
    }
    _users[user.id] = user;
    if (passwordHash != null) {
      _userPasswordHashes[user.id] = passwordHash;
    }
    await _saveToDisk();
  }

  Future<User?> getUserById(String id) async {
    await _ensureLoaded();
    return _users[id];
  }

  Future<User?> getUserByEmail(String email) async {
    await _ensureLoaded();
    try {
      return _users.values.firstWhere(
        (u) => u.email.toLowerCase() == email.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<User>> getAllUsers() async {
    await _ensureLoaded();
    _deduplicateUsers();
    return _users.values.toList();
  }

  Future<void> insertClinic(Clinic clinic) async {
    await _ensureLoaded();
    final existing = _clinics[clinic.id];
    if (existing != null && _sameClinic(existing, clinic)) return;
    _clinics[clinic.id] = clinic;
    await _saveToDisk();
  }

  Future<Clinic?> getClinicById(String id) async {
    await _ensureLoaded();
    return _clinics[id];
  }

  Future<List<Clinic>> getAllClinics() async {
    await _ensureLoaded();
    return _clinics.values.toList();
  }

  Future<void> updateClinic(Clinic clinic) => insertClinic(clinic);

  Future<void> deleteClinic(String id) async {
    await _ensureLoaded();
    var usersChanged = false;
    for (final entry in _users.entries) {
      if (entry.value.clinicId == id) {
        _users[entry.key] = entry.value.copyWith(clearClinicId: true);
        usersChanged = true;
      }
    }
    final clinicRemoved = _clinics.remove(id) != null;
    if (clinicRemoved || usersChanged) {
      await _saveToDisk();
    }
  }

  bool _sameClinic(Clinic left, Clinic right) =>
      jsonEncode(left.toJson()) == jsonEncode(right.toJson());

  Future<void> updateUser(
    User user, {
    String? newPasswordHash,
    Object? newPinHash = _absent,
  }) async {
    await _ensureLoaded();
    final duplicates = _users.values
        .where(
          (u) =>
              u.email.toLowerCase() == user.email.toLowerCase() &&
              u.id != user.id,
        )
        .toList();
    for (final old in duplicates) {
      _users.remove(old.id);
      final oldHash = _userPasswordHashes.remove(old.id);
      if (newPasswordHash == null && oldHash != null) {
        newPasswordHash = oldHash;
      }
    }
    var updated = user;
    if (newPasswordHash != null) {
      _userPasswordHashes[user.id] = newPasswordHash;
    }
    if (!identical(newPinHash, _absent)) {
      updated = updated.copyWith(pinHash: newPinHash as String?);
    }
    _users[user.id] = updated;
    await _saveToDisk();
  }

  Future<void> deactivateUser(String id) async {
    await _ensureLoaded();
    final user = _users[id];
    if (user != null) {
      _users[id] = user.copyWith(isActive: false);
      await _saveToDisk();
    }
  }

  Future<String?> getUserPasswordHash(String userId) async {
    await _ensureLoaded();
    return _userPasswordHashes[userId];
  }

  Future<void> clearUserPasswordHash(String userId) async {
    await _ensureLoaded();
    if (_userPasswordHashes.remove(userId) != null) {
      await _saveToDisk();
    }
  }

  Future<void> updateUserLastLogin(String userId) async {
    await _ensureLoaded();
    final user = _users[userId];
    if (user != null) {
      _users[userId] = user.copyWith(lastLoginAt: DateTime.now());
      await _saveToDisk();
    }
  }

  Future<void> updateUserPassword(String userId, String newPasswordHash) async {
    await _ensureLoaded();
    _userPasswordHashes[userId] = newPasswordHash;
    await _saveToDisk();
  }

  Future<void> updateUserPin(
    String userId,
    String? pinHash,
    bool enabled,
  ) async {
    await _ensureLoaded();
    final user = _users[userId];
    if (user != null) {
      _users[userId] = user.copyWith(pinHash: pinHash, pinEnabled: enabled);
      await _saveToDisk();
    }
  }

  Future<void> purgeRetiredClinicalData() async {
    await _ensureLoaded();
    var changed = _legacyRetiredClinicalDataPresent;
    _legacyRetiredClinicalDataPresent = false;

    for (final retiredTable in [
      'queue_items',
      'consultation',
      'consultations',
      'prescriptions',
      'lab_orders',
    ]) {
      if (_syncDeletes.keys.any((key) => key.startsWith('$retiredTable|'))) {
        _syncDeletes.removeWhere((key, _) => key.startsWith('$retiredTable|'));
        changed = true;
      }
    }
    for (final entry in _auditLogs.entries.toList()) {
      if (const {
        'queue_items',
        'consultation',
        'consultations',
        'prescriptions',
        'lab_orders',
      }.contains(entry.value.entityType)) {
        _auditLogs.remove(entry.key);
        changed = true;
      }
    }
    for (final notification
        in _notifications.values
            .where((item) => item.type == NotificationType.queueAlert)
            .toList()) {
      _notifications.remove(notification.id);
      changed = true;
    }

    if (_consultations.isNotEmpty ||
        _prescriptions.isNotEmpty ||
        _labOrders.isNotEmpty) {
      changed = true;
    }
    _consultations.clear();
    _prescriptions.clear();
    _labOrders.clear();

    if (changed) await _saveToDisk();
  }

  Future<void> insertConsultation(Consultation consultation) async {
    await _ensureLoaded();
    _consultations[consultation.id] = consultation;
    await _saveToDisk();
  }

  Future<Consultation?> getConsultationById(String id) async {
    await _ensureLoaded();
    return _consultations[id];
  }

  Future<List<Consultation>> getConsultationsForPatient(
    String patientId,
  ) async {
    await _ensureLoaded();
    return _consultations.values
        .where((c) => c.patientId == patientId)
        .toList();
  }

  Future<List<Consultation>> getAllConsultations() async {
    await _ensureLoaded();
    return _consultations.values.toList();
  }

  Future<void> updateConsultation(Consultation consultation) async {
    await _ensureLoaded();
    _consultations[consultation.id] = consultation;
    await _saveToDisk();
  }

  Future<void> deleteConsultation(String id) async {
    await _ensureLoaded();
    if (_consultations.containsKey(id)) _recordSyncDelete('consultations', id);
    _consultations.remove(id);
    for (final prescription
        in _prescriptions.values
            .where((item) => item.consultationId == id)
            .toList()) {
      _recordSyncDelete('prescriptions', prescription.id);
      _prescriptions.remove(prescription.id);
    }
    for (final labOrder
        in _labOrders.values
            .where((item) => item.consultationId == id)
            .toList()) {
      _recordSyncDelete('lab_orders', labOrder.id);
      _labOrders.remove(labOrder.id);
    }
    await _saveToDisk();
  }

  Future<void> insertPrescription(Prescription prescription) async {
    await _ensureLoaded();
    _prescriptions[prescription.id] = prescription;
    await _saveToDisk();
  }

  Future<List<Prescription>> getPrescriptionsForConsultation(
    String consultationId,
  ) async {
    await _ensureLoaded();
    return _prescriptions.values
        .where((p) => p.consultationId == consultationId)
        .toList();
  }

  Future<List<Prescription>> getAllPrescriptions() async {
    await _ensureLoaded();
    return _prescriptions.values.toList();
  }

  Future<void> insertLabOrder(LabOrder labOrder) async {
    await _ensureLoaded();
    _labOrders[labOrder.id] = labOrder;
    await _saveToDisk();
  }

  Future<List<LabOrder>> getLabOrdersForConsultation(
    String consultationId,
  ) async {
    await _ensureLoaded();
    return _labOrders.values
        .where((l) => l.consultationId == consultationId)
        .toList();
  }

  Future<void> insertDocument(MedicalDocument document) async {
    await _ensureLoaded();
    _documents[document.id] = document;
    await _saveToDisk();
  }

  Future<MedicalDocument?> getDocumentById(String id) async {
    await _ensureLoaded();
    return _documents[id];
  }

  Future<List<MedicalDocument>> getDocuments() async {
    await _ensureLoaded();
    return _documents.values.toList();
  }

  Future<List<MedicalDocument>> getDocumentsForPatient(String patientId) async {
    await _ensureLoaded();
    return _documents.values.where((d) => d.patientId == patientId).toList();
  }

  Future<void> updateDocument(MedicalDocument document) async {
    await _ensureLoaded();
    _documents[document.id] = document;
    await _saveToDisk();
  }

  Future<void> deleteDocument(String id) async {
    await _ensureLoaded();
    if (_documents.containsKey(id)) _recordSyncDelete('documents', id);
    _documents.remove(id);
    await _saveToDisk();
  }

  Future<List<GeneratedReport>> getGeneratedReports() async {
    await _ensureLoaded();
    final reports = _generatedReports.values.toList()
      ..sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
    return reports;
  }

  Future<void> insertGeneratedReport(GeneratedReport report) async {
    await _ensureLoaded();
    _generatedReports[report.id] = report;
    await _saveToDisk();
  }

  Future<void> deleteGeneratedReport(String id) async {
    await _ensureLoaded();
    if (_generatedReports.containsKey(id)) {
      _recordSyncDelete('generated_reports', id);
    }
    _generatedReports.remove(id);
    await _saveToDisk();
  }

  Future<void> insertAuditLog(AuditLog log) async {
    await _ensureLoaded();
    _auditLogs[log.id] = log;
    await _saveToDisk();
  }

  Future<List<AuditLog>> getRecentAuditLogs(int limit) async {
    await _ensureLoaded();
    final allLogs = _auditLogs.values.toList();
    allLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return allLogs.take(limit).toList();
  }

  Future<List<AuditLog>> getAuditLogsForPatient(String patientId) async {
    await _ensureLoaded();
    return _auditLogs.values.where((l) => l.patientId == patientId).toList();
  }

  Future<void> markAuditLogAsSynced(String logId) async {
    await _ensureLoaded();
    final log = _auditLogs[logId];
    if (log != null) {
      _auditLogs[logId] = log.copyWith(
        isSynced: true,
        syncedAt: DateTime.now(),
      );
      await _saveToDisk();
    }
  }

  Future<void> insertMedicalSnippet(dynamic snippet) async {
    await _ensureLoaded();
    _medicalSnippets[snippet.id] = snippet;
  }

  Future<dynamic> getMedicalSnippetById(String id) async {
    await _ensureLoaded();
    return _medicalSnippets[id];
  }

  Future<List<dynamic>> getMedicalSnippets() async {
    await _ensureLoaded();
    return _medicalSnippets.values.toList();
  }

  Future<void> updateMedicalSnippet(dynamic snippet) async {
    await _ensureLoaded();
    _medicalSnippets[snippet.id] = snippet;
  }

  Future<void> deleteMedicalSnippet(String id) async {
    await _ensureLoaded();
    _medicalSnippets.remove(id);
  }

  Future<void> clearAll() async {
    await _ensureLoaded();
    _patients.clear();
    _users.clear();
    _clinics.clear();
    _consultations.clear();
    _prescriptions.clear();
    _labOrders.clear();
    _documents.clear();
    _auditLogs.clear();
    _generatedReports.clear();
    _userPasswordHashes.clear();
    _syncDeletes.clear();
    _medicalSnippets.clear();
    await _saveToDisk();
  }

  Future<int> getTodayPatientCount() async {
    await _ensureLoaded();
    final now = DateTime.now();
    return _patients.values.where((p) {
      final createdAt = p.createdAt;
      if (createdAt == null) return false;
      return createdAt.year == now.year &&
          createdAt.month == now.month &&
          createdAt.day == now.day;
    }).length;
  }

  Future<int> getTodayConsultationCount() async {
    await _ensureLoaded();
    final now = DateTime.now();
    return _consultations.values.where((c) {
      final createdAt = c.createdAt;
      if (createdAt == null) return false;
      return createdAt.year == now.year &&
          createdAt.month == now.month &&
          createdAt.day == now.day;
    }).length;
  }

  Future<int> getDocumentCount() async {
    await _ensureLoaded();
    return _documents.length;
  }

  Future<int> getTodayDocumentCount() async {
    await _ensureLoaded();
    final now = DateTime.now();
    return _documents.values.where((d) {
      final createdAt = d.createdAt;
      if (createdAt == null) return false;
      return createdAt.year == now.year &&
          createdAt.month == now.month &&
          createdAt.day == now.day;
    }).length;
  }

  Future<List<Patient>> getArchivedPatients() async {
    await _ensureLoaded();
    return _patients.values.where((p) => p.isArchived).toList();
  }

  Future<void> archivePatient(String id) async {
    await _ensureLoaded();
    final patient = _patients[id];
    if (patient != null) {
      _patients[id] = patient.copyWith(
        isArchived: true,
        archivedAt: DateTime.now(),
        updatedAt: DateTime.now(),
        syncStatus: patient.syncStatus == 0 ? 2 : patient.syncStatus,
      );
      await _saveToDisk();
    }
  }

  Future<void> restoreArchivedPatient(String id) async {
    await _ensureLoaded();
    final patient = _patients[id];
    if (patient != null) {
      _patients[id] = patient.copyWith(
        isArchived: false,
        archivedAt: null,
        updatedAt: DateTime.now(),
        syncStatus: patient.syncStatus == 0 ? 2 : patient.syncStatus,
      );
      await _saveToDisk();
    }
  }

  Future<int> getArchivedPatientCount() async {
    await _ensureLoaded();
    return _patients.values.where((p) => p.isArchived).length;
  }

  Future<int> getActiveStaffCount() async {
    await _ensureLoaded();
    return _users.values
        .where((u) => u.isActive && u.role != UserRole.admin)
        .length;
  }

  Future<List<AuditLog>> getAllAuditLogs() async {
    await _ensureLoaded();
    final logs = _auditLogs.values.toList();
    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return logs;
  }

  Future<List<AuditLog>> filterAuditLogs({
    AuditAction? action,
    String? userId,
    DateTime? from,
    DateTime? to,
  }) async {
    await _ensureLoaded();
    return _auditLogs.values.where((log) {
      if (action != null && log.action != action) return false;
      if (userId != null && log.userId != userId) return false;
      if (from != null && log.timestamp.isBefore(from)) return false;
      if (to != null && log.timestamp.isAfter(to)) return false;
      return true;
    }).toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<int> getFailedLoginCount({Duration? within}) async {
    await _ensureLoaded();
    final cutoff = within != null
        ? DateTime.now().subtract(within)
        : DateTime.now().subtract(const Duration(days: 7));
    return _auditLogs.values.where((log) {
      return log.action == AuditAction.login &&
          log.description?.toLowerCase().contains('failed') == true &&
          log.timestamp.isAfter(cutoff);
    }).length;
  }

  Future<List<MedicalDocument>> getPendingDocuments() async {
    await _ensureLoaded();
    return _documents.values
        .where((d) => d.status == DocumentStatus.pending)
        .toList();
  }

  Future<int> getPendingDocumentCount() async {
    await _ensureLoaded();
    return _documents.values
        .where((d) => d.status == DocumentStatus.pending)
        .length;
  }

  Future<List<Patient>> getRecentlyUpdatedPatients(int limit) async {
    await _ensureLoaded();
    final active = _patients.values.where((p) => !p.isArchived).toList();
    active.sort((a, b) {
      final bDate = b.updatedAt ?? b.createdAt;
      final aDate = a.updatedAt ?? a.createdAt;
      if (bDate == null && aDate == null) return 0;
      if (bDate == null) return -1;
      if (aDate == null) return 1;
      return bDate.compareTo(aDate);
    });
    return active.take(limit).toList();
  }

  Future<int> getPendingSyncCount() async {
    await _ensureLoaded();
    final pendingPatients = _patients.values
        .where((p) => (p.syncStatus ?? 0) != 0)
        .length;
    final pendingDocuments = _documents.values
        .where((d) => (d.syncStatus ?? 0) != 0)
        .length;
    return pendingPatients + pendingDocuments + _syncDeletes.length;
  }

  Future<List<Map<String, String>>> getPendingSyncDeletes() async {
    await _ensureLoaded();
    return _syncDeleteJson();
  }

  Future<void> markSyncDeleteComplete(String table, String id) async {
    await _ensureLoaded();
    if (_syncDeletes.remove('$table|$id') != null) await _saveToDisk();
  }

  Future<String?> applyRemoteDelete(String table, String id) async {
    await _ensureLoaded();
    String? documentPath;
    switch (table) {
      case 'patients':
        final patient = _patients[id];
        if (patient != null) {
          _patients[id] = patient.copyWith(
            isArchived: true,
            archivedAt: patient.archivedAt ?? DateTime.now(),
            syncStatus: 0,
          );
        }
      case 'documents':
        documentPath = _documents.remove(id)?.filePath;
      case 'clinics':
        _clinics.remove(id);
        for (final entry in _users.entries.toList()) {
          if (entry.value.clinicId == id) {
            _users[entry.key] = entry.value.copyWith(clearClinicId: true);
          }
        }
      case 'users':
        _users.remove(id);
        _userPasswordHashes.remove(id);
      case 'audit_logs':
        _auditLogs.remove(id);
      case 'notifications':
        _notifications.remove(id);
      case 'generated_reports':
        _generatedReports.remove(id);
      case 'medical_snippets':
        _medicalSnippets.remove(id);
      default:
        return null;
    }
    await markSyncDeleteComplete(table, id);
    await _saveToDisk();
    return documentPath;
  }

  Future<void> applyRemoteUpsert(String table, Map<String, dynamic> raw) async {
    await _ensureLoaded();
    switch (table) {
      case 'patients':
        final patient = Patient.fromJson(raw);
        final existing = _patients[patient.id];
        if (existing != null &&
            _shouldKeepLocalVersion(
              existing.syncStatus,
              existing.updatedAt,
              patient.updatedAt,
            )) {
          return;
        }
        _patients[patient.id] = patient.copyWith(syncStatus: 0);
      case 'documents':
        final document = MedicalDocument.fromJson(raw);
        final existing = _documents[document.id];
        if (existing != null &&
            _shouldKeepLocalVersion(
              existing.syncStatus,
              existing.updatedAt,
              document.updatedAt,
            )) {
          return;
        }
        _documents[document.id] = document.copyWith(
          filePath: existing?.filePath ?? document.filePath,
          syncStatus: 0,
        );
      case 'users':
        final user = User.fromJson(raw);
        final existing = _users[user.id];
        if (existing != null &&
            _shouldKeepLocalVersion(
              existing.syncStatus,
              existing.updatedAt,
              user.updatedAt,
            )) {
          return;
        }
        _users[user.id] = user.copyWith(
          pinHash: existing?.pinHash,
          syncStatus: 0,
        );
      case 'clinics':
        final clinic = Clinic.fromJson(raw);
        final existing = _clinics[clinic.id];
        if (existing != null && _sameClinic(existing, clinic)) return;
        _clinics[clinic.id] = clinic;
      case 'audit_logs':
        final log = _auditLogFromRemote(raw);
        if (_auditLogs.containsKey(log.id)) return;
        _auditLogs[log.id] = log;
      case 'notifications':
        final target = raw['target'] == 'super_admin' ? 'admin' : raw['target'];
        final notification = SystemNotification.fromJson({
          ...raw,
          'target': target,
        });
        _notifications[notification.id] = notification;
      case 'generated_reports':
        final reportId = raw['id'] as String;
        if (raw['deleted_at'] != null) {
          _generatedReports.remove(reportId);
          break;
        }
        final report = GeneratedReport.fromJson({
          ...raw,
          'file_path': _generatedReports[reportId]?.filePath,
        });
        _generatedReports[report.id] = report;
      case 'system_settings':
        final value = raw['value'];
        if (value is! Map) {
          throw FormatException(
            'Realtime system_settings row has no JSON value object.',
          );
        }
        _systemSettings = SystemSettings.fromJson({
          ...Map<String, dynamic>.from(value),
          'updated_at': raw['updated_at'] ?? value['updated_at'],
        });
      case 'sync_tombstones':
        final entityType = raw['entity_type'] as String?;
        final recordId = raw['record_id'] as String?;
        if (entityType != null && recordId != null) {
          await applyRemoteDelete(entityType, recordId);
          return;
        }
        throw FormatException('Realtime tombstone is missing its entity ID.');
      default:
        throw ArgumentError.value(table, 'table', 'Unsupported realtime table');
    }
    await _saveToDisk();
  }

  bool _shouldKeepLocalVersion(
    int? localSyncStatus,
    DateTime? localUpdatedAt,
    DateTime? remoteUpdatedAt,
  ) {
    if (localSyncStatus != null && localSyncStatus != 0) return true;
    if (localUpdatedAt == null) return false;
    return remoteUpdatedAt == null || !remoteUpdatedAt.isAfter(localUpdatedAt);
  }

  AuditLog _auditLogFromRemote(Map<String, dynamic> raw) {
    final userId = raw['user_id'] as String? ?? 'system';
    final occurredAt = raw['occurred_at'] ?? raw['timestamp'];
    if (occurredAt is! String || DateTime.tryParse(occurredAt) == null) {
      throw FormatException('Realtime audit log has an invalid timestamp.');
    }

    final actionValue = (raw['action']?.toString() ?? '')
        .toLowerCase()
        .replaceAll('_', '');
    final AuditAction action;
    if (actionValue == 'insert' || actionValue.contains('create')) {
      action = AuditAction.create;
    } else if (actionValue.contains('update')) {
      action = AuditAction.update;
    } else if (actionValue.contains('delete')) {
      action = AuditAction.delete;
    } else if (actionValue.contains('login')) {
      action = AuditAction.login;
    } else if (actionValue.contains('logout')) {
      action = AuditAction.logout;
    } else if (actionValue.contains('export')) {
      action = AuditAction.export;
    } else if (actionValue.contains('print')) {
      action = AuditAction.print;
    } else if (actionValue.contains('sync')) {
      action = AuditAction.sync;
    } else if (actionValue.contains('backup')) {
      action = AuditAction.backup;
    } else if (actionValue.contains('restore')) {
      action = AuditAction.restore;
    } else if (actionValue.contains('password')) {
      action = AuditAction.passwordChange;
    } else if (actionValue.contains('pin')) {
      action = AuditAction.pinChange;
    } else if (actionValue.contains('role')) {
      action = AuditAction.roleChange;
    } else if (actionValue.contains('setting')) {
      action = AuditAction.settingsChange;
    } else {
      action = AuditAction.other;
    }
    final user = _users[userId];

    return AuditLog(
      id: raw['id'] as String,
      userId: userId,
      userName: user?.fullName,
      userRole: user?.roleDisplay,
      action: action,
      entityType: raw['entity_type'] as String? ?? 'system',
      entityId: raw['entity_id'] as String?,
      patientId: raw['patient_id'] as String?,
      oldValues: _remoteJsonString(raw['old_values']),
      newValues: _remoteJsonString(raw['new_values']),
      timestamp: DateTime.parse(occurredAt),
      isSynced: true,
      syncStatus: 0,
    );
  }

  String? _remoteJsonString(dynamic value) {
    if (value == null) return null;
    return value is String ? value : jsonEncode(value);
  }

  Future<SystemSettings> getSystemSettings() async {
    await _ensureLoaded();
    return _systemSettings;
  }

  Future<void> updateSystemSettings(SystemSettings settings) async {
    await _ensureLoaded();
    _systemSettings = settings.copyWith(updatedAt: DateTime.now());
    await _saveToDisk();
  }

  Future<void> replaceSyncedSystemSettings(SystemSettings settings) async {
    await _ensureLoaded();
    _systemSettings = settings;
    await _saveToDisk();
  }

  Future<String> generateNextPatientId() async {
    await _ensureLoaded();
    final id = _systemSettings.generateNextPatientId();
    _systemSettings = _systemSettings.copyWith(
      patientIdSequence: _systemSettings.patientIdSequence + 1,
      updatedAt: DateTime.now(),
    );
    await _saveToDisk();
    return id;
  }

  Future<void> insertNotification(SystemNotification notification) async {
    await _ensureLoaded();
    _notifications[notification.id] = notification;
    await _saveToDisk();
  }

  Future<List<SystemNotification>> getNotifications({
    NotificationTarget? target,
    bool unreadOnly = false,
  }) async {
    await _ensureLoaded();
    return _notifications.values.where((n) {
      if (unreadOnly && n.isRead) return false;
      if (target == null) return true;
      return n.target == target || n.target == NotificationTarget.all;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<int> getUnreadNotificationCount(NotificationTarget target) async {
    final notifications = await getNotifications(
      target: target,
      unreadOnly: true,
    );
    return notifications.length;
  }

  Future<void> markNotificationRead(String id) async {
    await _ensureLoaded();
    final notification = _notifications[id];
    if (notification != null) {
      _notifications[id] = notification.copyWith(isRead: true);
      await _saveToDisk();
    }
  }

  Future<void> markAllNotificationsRead(NotificationTarget target) async {
    await _ensureLoaded();
    for (final entry in _notifications.entries) {
      if (entry.value.target == target ||
          entry.value.target == NotificationTarget.all) {
        _notifications[entry.key] = entry.value.copyWith(isRead: true);
      }
    }
    await _saveToDisk();
  }

  Future<void> deleteNotification(String id) async {
    await _ensureLoaded();
    _notifications.remove(id);
    await _saveToDisk();
  }

  Future<List<AuditLog>> getStaffActivityLogs(int limit) async {
    await _ensureLoaded();
    final logs = _auditLogs.values
        .where(
          (l) =>
              l.action != AuditAction.login && l.action != AuditAction.logout,
        )
        .toList();
    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return logs.take(limit).toList();
  }

  Future<void> close() async {
    await _saveToDisk();
  }
}

const Object _absent = Object();
