import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';

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
  final Map<String, QueueItem> _queueItems = {};
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
  final StreamController<int> _changes = StreamController<int>.broadcast();
  int _revision = 0;

  /// Emits after a durable local write. UI providers use this to refresh every
  /// authorized view from the same local source of truth.
  Stream<int> get changes => _changes.stream;

  Future<void> useStoreFileForTesting(dynamic file) async {
    _storage.setCustomStoreFile(file);
    _loadFuture = null;
    _patients.clear();
    _users.clear();
    _clinics.clear();
    _queueItems.clear();
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
    _restoreMap(decoded['patients'], _patients, Patient.fromJson);
    _restoreMap(decoded['users'], _users, User.fromJson);
    _deduplicateUsers();
    _restoreMap(decoded['clinics'], _clinics, Clinic.fromJson);
    _restoreMap(decoded['queue_items'], _queueItems, QueueItem.fromJson);
    _restoreMap(
      decoded['consultations'],
      _consultations,
      Consultation.fromJson,
    );
    _restoreMap(
      decoded['prescriptions'],
      _prescriptions,
      Prescription.fromJson,
    );
    _restoreMap(decoded['lab_orders'], _labOrders, LabOrder.fromJson);
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
      'queue_items': _queueItems.values.map((e) => e.toJson()).toList(),
      'consultations': _consultations.values.map((e) => e.toJson()).toList(),
      'prescriptions': _prescriptions.values.map((e) => e.toJson()).toList(),
      'lab_orders': _labOrders.values.map((e) => e.toJson()).toList(),
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

    await _storage.writeStore(jsonEncode(data));
    _changes.add(++_revision);
  }

  Future<String> createBackup() async {
    await _ensureLoaded();
    final data = {
      'version': 1,
      'patients': _patients.values.map((e) => e.toJson()).toList(),
      'users': _users.values.map((e) => e.toJson()).toList(),
      'clinics': _clinics.values.map((e) => e.toJson()).toList(),
      'queue_items': _queueItems.values.map((e) => e.toJson()).toList(),
      'consultations': _consultations.values.map((e) => e.toJson()).toList(),
      'prescriptions': _prescriptions.values.map((e) => e.toJson()).toList(),
      'lab_orders': _labOrders.values.map((e) => e.toJson()).toList(),
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
    _queueItems.clear();
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
    _restoreMap(decoded['queue_items'], _queueItems, QueueItem.fromJson);
    _restoreMap(
      decoded['consultations'],
      _consultations,
      Consultation.fromJson,
    );
    _restoreMap(
      decoded['prescriptions'],
      _prescriptions,
      Prescription.fromJson,
    );
    _restoreMap(decoded['lab_orders'], _labOrders, LabOrder.fromJson);
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
    _queueItems.clear();
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

  Future<void> insertQueueItem(QueueItem item) async {
    await _ensureLoaded();
    _queueItems[item.id] = item;
    await _saveToDisk();
  }

  Future<QueueItem?> getQueueItemById(String id) async {
    await _ensureLoaded();
    return _queueItems[id];
  }

  Future<List<QueueItem>> getQueueItems() async {
    await _ensureLoaded();
    return _queueItems.values.toList();
  }

  Future<List<QueueItem>> getActiveQueueItems() async {
    await _ensureLoaded();
    return _queueItems.values
        .where(
          (q) =>
              q.status == QueueStatus.waiting ||
              q.status == QueueStatus.inProgress,
        )
        .toList();
  }

  Future<List<QueueItem>> getQueueItemsForDate(DateTime date) async {
    await _ensureLoaded();
    return _queueItems.values.where((q) {
      return q.arrivalTime.year == date.year &&
          q.arrivalTime.month == date.month &&
          q.arrivalTime.day == date.day;
    }).toList();
  }

  Future<void> updateQueueItem(QueueItem item) async {
    await _ensureLoaded();
    _queueItems[item.id] = item;
    await _saveToDisk();
  }

  Future<void> deleteQueueItem(String id) async {
    await _ensureLoaded();
    if (_queueItems.containsKey(id)) _recordSyncDelete('queue_items', id);
    _queueItems.remove(id);
    await _saveToDisk();
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

  Future<Consultation?> getConsultationByQueueId(String queueId) async {
    await _ensureLoaded();
    try {
      return _consultations.values.firstWhere((c) => c.queueId == queueId);
    } catch (_) {
      return null;
    }
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
    _queueItems.clear();
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

  Future<void> removeFromQueue(String queueItemId) async {
    await deleteQueueItem(queueItemId);
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
    await _ensureLoaded();
    final now = DateTime.now();
    final queueItem = QueueItem(
      id: const Uuid().v4(),
      patientId: patientId,
      patientName: patientName,
      purpose: purpose,
      complaint: complaint,
      priority: priority,
      isSenior: isSenior,
      isPregnant: isPregnant,
      isPwd: isPwd,
      isInfant: isInfant,
      arrivalTime: now,
      status: QueueStatus.waiting,
      createdAt: now,
      updatedAt: now,
      syncStatus: 1,
    );
    _queueItems[queueItem.id] = queueItem;
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

  Future<int> getActiveQueueCount() async {
    await _ensureLoaded();
    return _queueItems.values
        .where(
          (q) =>
              q.status == QueueStatus.waiting ||
              q.status == QueueStatus.inProgress,
        )
        .length;
  }

  Future<int> getLongWaitQueueCount(int thresholdMinutes) async {
    await _ensureLoaded();
    final now = DateTime.now();
    return _queueItems.values.where((q) {
      return q.status == QueueStatus.waiting &&
          now.difference(q.arrivalTime).inMinutes > thresholdMinutes;
    }).length;
  }

  Future<List<QueueItem>> getLongWaitQueueItems(int thresholdMinutes) async {
    await _ensureLoaded();
    final now = DateTime.now();
    return _queueItems.values.where((q) {
      return q.status == QueueStatus.waiting &&
          now.difference(q.arrivalTime).inMinutes > thresholdMinutes;
    }).toList();
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
    final pendingConsultations = _consultations.values
        .where((c) => (c.syncStatus ?? 0) != 0)
        .length;
    final pendingDocuments = _documents.values
        .where((d) => (d.syncStatus ?? 0) != 0)
        .length;
    final pendingQueueItems = _queueItems.values
        .where((q) => (q.syncStatus ?? 0) != 0)
        .length;
    final pendingPrescriptions = _prescriptions.values
        .where((item) => (item.syncStatus ?? 0) != 0)
        .length;
    final pendingLabOrders = _labOrders.values
        .where((item) => (item.syncStatus ?? 0) != 0)
        .length;
    return pendingPatients +
        pendingConsultations +
        pendingDocuments +
        pendingQueueItems +
        pendingPrescriptions +
        pendingLabOrders +
        _syncDeletes.length;
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
      case 'queue_items':
        _queueItems.remove(id);
      case 'consultations':
        _consultations.remove(id);
        _prescriptions.removeWhere((_, item) => item.consultationId == id);
        _labOrders.removeWhere((_, item) => item.consultationId == id);
      case 'prescriptions':
        _prescriptions.remove(id);
      case 'lab_orders':
        _labOrders.remove(id);
      case 'documents':
        documentPath = _documents.remove(id)?.filePath;
      case 'generated_reports':
        _generatedReports.remove(id);
      default:
        throw ArgumentError('Unsupported remote deletion type: $table');
    }
    await markSyncDeleteComplete(table, id);
    await _saveToDisk();
    return documentPath;
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
