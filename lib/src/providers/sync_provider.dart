import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../models/audit_log.dart';
import '../models/document.dart';
import '../models/generated_report.dart';
import '../models/patient.dart';
import '../models/system_notification.dart';
import '../models/system_settings.dart';
import '../models/user.dart';
import '../models/clinic.dart';
import '../services/app_notification.dart';
import '../services/document_service.dart';
import 'providers.dart';

/// UI-facing sync state shown in the header, dashboard, and sync screen.
enum SyncStatus { synced, syncing, pending, error, offline }

class SyncStats {
  final int totalPatients;
  final int totalDocuments;
  final int pendingSync;

  const SyncStats({
    required this.totalPatients,
    required this.totalDocuments,
    required this.pendingSync,
  });
}

class SyncResult {
  final String message;
  final bool success;

  const SyncResult({required this.message, required this.success});
}

class SyncServiceState {
  final SyncStatus status;
  final DateTime? lastSyncTime;

  const SyncServiceState({this.status = SyncStatus.synced, this.lastSyncTime});

  SyncServiceState copyWith({SyncStatus? status, DateTime? lastSyncTime}) {
    return SyncServiceState(
      status: status ?? this.status,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}

class SyncService extends StateNotifier<SyncServiceState> {
  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<AuthState>? _authStateSubscription;
  StreamSubscription<int>? _databaseChangesSubscription;
  RealtimeChannel? _realtimeChannel;
  Timer? _realtimeRefreshTimer;
  Timer? _pendingSyncTimer;
  Timer? _retrySyncTimer;
  Timer? _periodicSyncTimer;
  Timer? _syncSettingsRefreshTimer;
  int _realtimeSetupGeneration = 0;
  int _retryAttempt = 0;
  int? _configuredSyncIntervalMinutes;
  bool _autoSyncEnabled = true;
  bool _wasOffline = false;

  SyncService(this._ref) : super(const SyncServiceState()) {
    _initConnectivityListener();
    unawaited(_initializeSync());
    _databaseChangesSubscription = _ref.read(databaseProvider).changes.listen((
      _,
    ) {
      _schedulePendingSync();
      _scheduleSyncSettingsRefresh();
    });
    _authStateSubscription = _supabase.auth.onAuthStateChange.listen((event) {
      // Only reconfigure and sync on actual login, not on token refreshes.
      if (event.event == AuthChangeEvent.signedIn ||
          event.event == AuthChangeEvent.tokenRefreshed) {
        unawaited(_configureRealtimeSubscription());
      }
      if (event.event == AuthChangeEvent.signedIn) {
        unawaited(_refreshAutoSyncSettings());
        _schedulePendingSync();
      }
    });
    unawaited(_configureRealtimeSubscription());
  }

  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) async {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline) {
        await _refreshAutoSyncSettings();
        final wasOffline = _wasOffline || state.status == SyncStatus.offline;
        _wasOffline = false;
        if (_supabase.auth.currentSession == null) {
          await _ref.read(authRepositoryProvider).ensureOnlineSession();
        }
        if (_autoSyncEnabled &&
            (wasOffline ||
                state.status == SyncStatus.pending ||
                state.status == SyncStatus.error)) {
          if (wasOffline) {
            AppNotification.info(
              title: 'Back Online',
              message: 'Connection restored. Syncing changes to cloud...',
            );
          }
          final result = await startSync();
          if (wasOffline && result.success) {
            AppNotification.success(
              title: 'Cloud Synchronized',
              message: 'All local changes synchronized successfully.',
            );
          }
        } else {
          await _refreshDerivedStatus();
        }
        unawaited(_configureRealtimeSubscription());
      } else {
        if (!_wasOffline) {
          _wasOffline = true;
          state = state.copyWith(status: SyncStatus.offline);
          AppNotification.warning(
            title: 'Offline Mode',
            message:
                'Working offline. All changes are saved locally and will sync when reconnected.',
          );
        }
      }
    });
  }

  Future<void> _initializeSync() async {
    await _ref.read(databaseProvider).purgeRetiredClinicalData();
    await _refreshAutoSyncSettings();
    final online = await _hasNetworkConnection();
    _wasOffline = !online;
    await _refreshDerivedStatus();
    if (online && _autoSyncEnabled) {
      if (_supabase.auth.currentSession == null) {
        await _ref.read(authRepositoryProvider).ensureOnlineSession();
      }
      if (_supabase.auth.currentSession != null) {
        await startSync();
      }
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _authStateSubscription?.cancel();
    _databaseChangesSubscription?.cancel();
    _realtimeRefreshTimer?.cancel();
    _pendingSyncTimer?.cancel();
    _retrySyncTimer?.cancel();
    _periodicSyncTimer?.cancel();
    _syncSettingsRefreshTimer?.cancel();
    _realtimeSetupGeneration++;
    final channel = _realtimeChannel;
    if (channel != null) unawaited(_supabase.removeChannel(channel));
    super.dispose();
  }

  Future<void> _configureRealtimeSubscription() async {
    final generation = ++_realtimeSetupGeneration;

    if (_supabase.auth.currentSession == null) {
      await _ref.read(authRepositoryProvider).ensureOnlineSession();
    }

    final previous = _realtimeChannel;
    _realtimeChannel = null;
    if (previous != null) {
      try {
        await _supabase.removeChannel(previous);
      } catch (_) {}
    }

    if (generation != _realtimeSetupGeneration) return;

    final channelName = 'medsentry-realtime-channel';
    var channel = _supabase.channel(channelName);
    const tables = [
      'patients',
      'documents',
      'users',
      'clinics',
      'audit_logs',
      'notifications',
      'generated_reports',
      'system_settings',
      'medical_snippets',
      'sync_tombstones',
    ];

    for (final table in tables) {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (change) async {
          debugPrint('REALTIME EVENT: ${change.eventType} on table $table');
          try {
            final db = _ref.read(databaseProvider);
            if (change.eventType == PostgresChangeEvent.delete) {
              final id =
                  change.oldRecord['id'] ?? change.oldRecord['record_id'];
              if (id is String) {
                await db.applyRemoteDelete(table, id);
              }
            } else if (change.newRecord.isNotEmpty) {
              await db.applyRemoteUpsert(table, change.newRecord);
            }
          } catch (e) {
            debugPrint('Error handling realtime change for $table: $e');
          }
          _scheduleRealtimeRefresh();
        },
      );
    }

    _realtimeChannel = channel.subscribe((status, error) {
      debugPrint('Realtime channel status: $status, error: $error');
    });
  }

  void _scheduleRealtimeRefresh() {
    _realtimeRefreshTimer?.cancel();
    // 400ms debounce: allows multi-table transactions to settle before secondary consistency sync
    _realtimeRefreshTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(_refreshAfterRealtimeChange());
    });
  }

  Future<void> _refreshAfterRealtimeChange() async {
    if (state.status == SyncStatus.syncing) {
      _scheduleRealtimeRefresh();
      return;
    }
    await _refreshAutoSyncSettings();
    if (!_autoSyncEnabled) return;
    if (_supabase.auth.currentSession == null) {
      await _ref.read(authRepositoryProvider).ensureOnlineSession();
    }
    if (_supabase.auth.currentSession != null) {
      await startSync();
    }
  }

  void _schedulePendingSync({
    Duration delay = const Duration(milliseconds: 300),
  }) {
    if (!_autoSyncEnabled) return;
    _pendingSyncTimer?.cancel();
    _pendingSyncTimer = Timer(delay, () async {
      await _refreshAutoSyncSettings();
      if (!_autoSyncEnabled) return;
      if (_supabase.auth.currentSession == null) {
        await _ref.read(authRepositoryProvider).ensureOnlineSession();
      }
      if (state.status == SyncStatus.syncing) {
        _schedulePendingSync(delay: const Duration(seconds: 1));
        return;
      }
      if (state.status == SyncStatus.offline) return;
      final pending = await _ref.read(databaseProvider).getPendingSyncCount();
      if (pending > 0 && _supabase.auth.currentSession != null) {
        await startSync();
      }
    });
  }

  void _scheduleSyncSettingsRefresh() {
    _syncSettingsRefreshTimer?.cancel();
    _syncSettingsRefreshTimer = Timer(
      const Duration(milliseconds: 400),
      () => unawaited(_refreshAutoSyncSettings()),
    );
  }

  Future<void> _refreshAutoSyncSettings() async {
    final settings = await _ref.read(databaseProvider).getSystemSettings();
    final enabled = settings.autoSyncEnabled;
    final interval = settings.autoSyncIntervalMinutes.clamp(1, 1440);
    final wasEnabled = _autoSyncEnabled;
    if (_autoSyncEnabled == enabled &&
        _configuredSyncIntervalMinutes == interval &&
        (_periodicSyncTimer?.isActive ?? false) == enabled) {
      return;
    }

    _autoSyncEnabled = enabled;
    _configuredSyncIntervalMinutes = interval;
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
    if (!enabled) {
      _pendingSyncTimer?.cancel();
      _retrySyncTimer?.cancel();
      return;
    }

    _periodicSyncTimer = Timer.periodic(
      Duration(minutes: interval),
      (_) => unawaited(_runAutomaticSync()),
    );
    if (!wasEnabled) _schedulePendingSync();
  }

  Future<void> _runAutomaticSync() async {
    if (!_autoSyncEnabled || state.status == SyncStatus.syncing) return;
    if (_supabase.auth.currentSession == null) {
      await _ref.read(authRepositoryProvider).ensureOnlineSession();
    }
    if (_supabase.auth.currentSession != null) {
      await startSync();
    }
  }

  static const int _synced = 0;

  Future<void> _refreshDerivedStatus() async {
    final pending = await _ref.read(databaseProvider).getPendingSyncCount();
    final online = await _hasNetworkConnection();

    SyncStatus status;
    if (!online) {
      status = SyncStatus.offline;
    } else if (pending > 0) {
      status = SyncStatus.pending;
    } else {
      status = SyncStatus.synced;
    }

    state = state.copyWith(status: status);
  }

  Future<bool> _hasNetworkConnection() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (error) {
      debugPrint('Unable to determine network connectivity: $error');
      return false;
    }
  }

  Future<bool> _canSyncToCloud() async {
    if (_supabase.auth.currentSession == null) {
      await _ref.read(authRepositoryProvider).ensureOnlineSession();
    }
    if (_supabase.auth.currentSession == null) return false;
    try {
      await _supabase.from('patients').select('id').limit(1);
      return true;
    } catch (error) {
      debugPrint('Cloud sync health check failed: $error');
      return false;
    }
  }

  Future<SyncStats> getSyncStats() async {
    final db = _ref.read(databaseProvider);
    final patients = await db.getAllPatients();
    final documents = await db.getDocuments();
    final pending = await db.getPendingSyncCount();

    return SyncStats(
      totalPatients: patients.length,
      totalDocuments: documents.length,
      pendingSync: pending,
    );
  }

  Future<SyncResult> startSync() async {
    if (state.status == SyncStatus.syncing) {
      return const SyncResult(
        message: 'Sync already in progress',
        success: false,
      );
    }

    await _ref.read(databaseProvider).purgeRetiredClinicalData();
    _retrySyncTimer?.cancel();
    state = state.copyWith(status: SyncStatus.syncing);

    final online = await _hasNetworkConnection();
    if (!online) {
      _wasOffline = true;
      state = state.copyWith(status: SyncStatus.offline);
      return const SyncResult(
        message: 'No internet connection',
        success: false,
      );
    }

    final cloudReady = await _canSyncToCloud();
    final hasSession = _supabase.auth.currentSession != null;
    final result = cloudReady
        ? await _performCloudSync()
        : hasSession
        ? const SyncResult(
            message:
                'Cloud is unavailable. Changes remain saved locally and will retry automatically.',
            success: false,
          )
        : await _performLocalSync();

    if (result.success) {
      _retryAttempt = 0;
      _retrySyncTimer?.cancel();
      await _refreshDerivedStatus();
    } else if (hasSession) {
      state = state.copyWith(status: SyncStatus.error);
      _scheduleSyncRetry();
    } else {
      await _refreshDerivedStatus();
    }

    return result;
  }

  void _scheduleSyncRetry() {
    if (_supabase.auth.currentSession == null) return;
    _retrySyncTimer?.cancel();
    const retryDelays = [2, 5, 15, 30, 60];
    final delay = Duration(
      seconds: retryDelays[_retryAttempt.clamp(0, retryDelays.length - 1)],
    );
    _retryAttempt++;
    _retrySyncTimer = Timer(delay, () {
      if (_supabase.auth.currentSession != null) unawaited(startSync());
    });
  }

  Future<SyncResult> _performLocalSync() async {
    // A local save is already durable at the time of each mutation. It is not
    // a cloud sync, so never clear pending flags or claim cross-device success.
    final pending = await _ref.read(databaseProvider).getPendingSyncCount();
    state = state.copyWith(status: SyncStatus.pending);
    return SyncResult(
      message: pending == 0
          ? 'No cloud changes are pending.'
          : '$pending change${pending == 1 ? '' : 's'} saved locally and awaiting cloud authentication.',
      success: false,
    );
  }

  Future<SyncResult> _performCloudSync() async {
    try {
      final db = _ref.read(databaseProvider);
      int synced = 0;
      int failed = 0;

      final profile = await _currentCloudProfile();
      if (profile == null) {
        throw StateError(
          'The signed-in account has no active MedSentry profile.',
        );
      }
      await _syncSystemSettings(db, profile);
      await _syncGeneratedReports(db, profile);

      // Include archived patients so an archive action is synchronized rather
      // than leaving the remote copy active.
      for (final patient in await db.getAllPatients(includeArchived: true)) {
        if (patient.syncStatus == _synced) continue;
        try {
          final now = DateTime.now().toIso8601String();
          final payload = patient.toJson()
            ..remove('sync_status')
            ..remove('sync_error')
            ..['created_at'] ??= now
            ..['updated_at'] = now;
          payload['clinic_id'] = await _clinicIdForUpload(
            'patients',
            patient.id,
            profile,
          );
          await _supabase.from('patients').upsert(payload);
          await db.updatePatient(patient.copyWith(syncStatus: _synced));
          synced++;
        } catch (error, stackTrace) {
          debugPrint(
            'Patient sync failed (${patient.id}): $error\n$stackTrace',
          );
          failed++;
        }
      }

      for (final document in await db.getDocuments()) {
        if (document.syncStatus == _synced) continue;
        try {
          final now = DateTime.now().toIso8601String();
          final payload = document.toJson()
            ..remove('sync_status')
            ..remove('file_path')
            ..remove('file_url')
            ..['created_at'] ??= now
            ..['updated_at'] = now;
          payload['clinic_id'] = await _clinicIdForUpload(
            'documents',
            document.id,
            profile,
          );
          await _supabase.from('documents').upsert(payload);
          await db.updateDocument(document.copyWith(syncStatus: _synced));
          synced++;
        } catch (error, stackTrace) {
          debugPrint(
            'Document sync failed (${document.id}): $error\n$stackTrace',
          );
          failed++;
        }
      }

      for (final deletion in await db.getPendingSyncDeletes()) {
        try {
          await _supabase.rpc(
            'medsentry_apply_sync_delete',
            params: {
              'entity': deletion['table'],
              'target_record_id': deletion['record_id'],
            },
          );
          await db.markSyncDeleteComplete(
            deletion['table']!,
            deletion['record_id']!,
          );
          synced++;
        } catch (error, stackTrace) {
          debugPrint(
            'Sync deletion failed (${deletion['table']}/${deletion['record_id']}): '
            '$error\n$stackTrace',
          );
          failed++;
        }
      }

      await _pullRemoteDeletions(db);
      await _pullRemotePatients(db);
      await _pullRemoteDocuments(db);
      await _pullRemoteUsers(db);
      await _pullRemoteClinics(db);
      await _pullRemoteAuditLogs(db);
      await _pullRemoteNotifications(db);

      final now = DateTime.now();
      final message = failed > 0
          ? 'Cloud sync completed with $failed error${failed == 1 ? '' : 's'}'
          : synced > 0
          ? 'Cloud sync completed ($synced records)'
          : 'Cloud sync completed — already up to date';

      state = state.copyWith(
        status: failed > 0 ? SyncStatus.error : SyncStatus.synced,
        lastSyncTime: failed == 0 ? now : null,
      );

      return SyncResult(message: message, success: failed == 0);
    } catch (e) {
      state = state.copyWith(status: SyncStatus.error);
      return SyncResult(message: 'Cloud sync failed: $e', success: false);
    }
  }

  Future<void> _pullRemoteDeletions(dynamic db) async {
    final rows = await _selectAllRows(
      'sync_tombstones',
      columns: 'entity_type,record_id',
    );
    for (final raw in rows) {
      final deletion = Map<String, dynamic>.from(raw);
      final table = deletion['entity_type'] as String;
      final id = deletion['record_id'] as String;
      if (table == 'documents') {
        final document = await db.getDocumentById(id);
        if (document != null && document.filePath.trim().isNotEmpty) {
          await DocumentService.deleteDocument(document.filePath);
        }
      }
      await db.applyRemoteDelete(table, id);
    }
  }

  bool _isRemoteVersionNewer(
    DateTime? remoteUpdatedAt,
    DateTime? localUpdatedAt,
  ) =>
      remoteUpdatedAt != null &&
      (localUpdatedAt == null || remoteUpdatedAt.isAfter(localUpdatedAt));

  Future<void> _pullRemoteDocuments(dynamic db) async {
    final localItems = {
      for (final item in await db.getDocuments()) item.id: item,
    };
    final rows = await _selectAllRows('documents');
    for (final raw in rows) {
      final remote = MedicalDocument.fromJson(Map<String, dynamic>.from(raw));
      final local = localItems[remote.id];
      if (local == null ||
          (local.syncStatus == _synced &&
              _isRemoteVersionNewer(remote.updatedAt, local.updatedAt))) {
        await db.updateDocument(
          remote.copyWith(filePath: local?.filePath ?? '', syncStatus: _synced),
        );
      }
    }
  }

  Future<void> _pullRemoteUsers(dynamic db) async {
    final localUsers = {
      for (final user in await db.getAllUsers()) user.id: user,
    };
    final rows = await _selectAllRows('users');
    for (final raw in rows) {
      final remote = User.fromJson(Map<String, dynamic>.from(raw));
      final local = localUsers[remote.id];
      if (local == null ||
          (local.syncStatus == _synced &&
              _isRemoteVersionNewer(remote.updatedAt, local.updatedAt))) {
        final updated = remote.copyWith(
          pinHash: local?.pinHash,
          syncStatus: _synced,
        );
        if (local == null) {
          await db.insertUser(updated);
        } else {
          await db.updateUser(updated);
        }
        final currentUser = _ref.read(currentUserProvider);
        if (currentUser?.id == remote.id) {
          _ref.read(currentUserProvider.notifier).state = updated;
        }
      }
    }
  }

  Future<void> _pullRemoteClinics(dynamic db) async {
    final rows = await _selectAllRows('clinics');
    for (final raw in rows) {
      final remote = Clinic.fromJson(Map<String, dynamic>.from(raw));
      await db.insertClinic(remote);
    }
  }

  Future<void> _pullRemoteAuditLogs(dynamic db) async {
    final localIds = {for (final log in await db.getAllAuditLogs()) log.id};
    final rows = await _selectAllRows('audit_logs');
    final users = {for (final user in await db.getAllUsers()) user.id: user};

    for (final raw in rows) {
      final row = Map<String, dynamic>.from(raw);
      final id = row['id'] as String;
      if (localIds.contains(id)) continue;
      final userId = row['user_id'] as String? ?? 'system';
      final user = users[userId];
      final timestamp = row['occurred_at'] ?? row['timestamp'];
      if (timestamp is! String) continue;
      await db.insertAuditLog(
        AuditLog(
          id: id,
          userId: userId,
          userName: user?.fullName,
          userRole: user?.roleDisplay,
          action: _auditActionFromRemote(row['action']?.toString() ?? ''),
          entityType: row['entity_type'] as String? ?? 'system',
          entityId: row['entity_id'] as String?,
          patientId: row['patient_id'] as String?,
          oldValues: _auditJsonValue(row['old_values']),
          newValues: _auditJsonValue(row['new_values']),
          timestamp: DateTime.parse(timestamp),
          isSynced: true,
          syncStatus: _synced,
        ),
      );
    }
  }

  AuditAction _auditActionFromRemote(String value) {
    final action = value.toLowerCase().replaceAll('_', '');
    if (action.contains('create') || action == 'insert') {
      return AuditAction.create;
    }
    if (action.contains('update')) return AuditAction.update;
    if (action.contains('delete')) return AuditAction.delete;
    if (action.contains('login')) return AuditAction.login;
    if (action.contains('logout')) return AuditAction.logout;
    if (action.contains('export')) return AuditAction.export;
    if (action.contains('print')) return AuditAction.print;
    if (action.contains('sync')) return AuditAction.sync;
    if (action.contains('backup')) return AuditAction.backup;
    if (action.contains('restore')) return AuditAction.restore;
    if (action.contains('password')) return AuditAction.passwordChange;
    if (action.contains('pin')) return AuditAction.pinChange;
    if (action.contains('role')) return AuditAction.roleChange;
    if (action.contains('setting')) return AuditAction.settingsChange;
    return AuditAction.other;
  }

  String? _auditJsonValue(dynamic value) {
    if (value == null) return null;
    return value is String ? value : jsonEncode(value);
  }

  Future<List<Map<String, dynamic>>> _selectAllRows(
    String table, {
    String columns = '*',
  }) async {
    const pageSize = 500;
    final rows = <Map<String, dynamic>>[];
    var offset = 0;

    while (true) {
      final page = await _supabase
          .from(table)
          .select(columns)
          .range(offset, offset + pageSize - 1);
      rows.addAll(List<Map<String, dynamic>>.from(page));
      if (page.length < pageSize) return rows;
      offset += pageSize;
    }
  }

  Future<void> _pullRemoteNotifications(dynamic db) async {
    final local = {
      for (final notification in await db.getNotifications())
        notification.id: notification,
    };
    final rows = await _selectAllRows('notifications');
    for (final raw in rows) {
      final row = Map<String, dynamic>.from(raw);
      final target = row['target'] == 'super_admin' ? 'admin' : row['target'];
      final remote = SystemNotification.fromJson({...row, 'target': target});
      final existing = local[remote.id];
      if (existing == null) {
        // New notification — insert
        await db.insertNotification(remote);
      } else if (existing.isRead != remote.isRead ||
          existing.title != remote.title ||
          existing.message != remote.message ||
          existing.priority != remote.priority) {
        // Changed notification — overwrite with authoritative server copy
        await db.insertNotification(remote);
      }
    }
  }

  Future<Map<String, dynamic>?> _currentCloudProfile() async {
    final authId = _supabase.auth.currentUser?.id;
    if (authId == null) return null;
    final row = await _supabase
        .from('users')
        .select('id,role,clinic_id')
        .eq('auth_user_id', authId)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<String> _clinicIdForUpload(
    String table,
    String recordId,
    Map<String, dynamic> profile,
  ) async {
    final clinicId = profile['clinic_id'];
    if (clinicId is String && clinicId.isNotEmpty) return clinicId;

    if (profile['role'] == 'super_admin') {
      final existing = await _supabase
          .from(table)
          .select('clinic_id')
          .eq('id', recordId)
          .maybeSingle();
      final existingClinicId = existing?['clinic_id'];
      if (existingClinicId is String && existingClinicId.isNotEmpty) {
        return existingClinicId;
      }
    }

    throw StateError(
      'Cannot sync $table/$recordId because its clinic is not known.',
    );
  }

  Future<void> _syncSystemSettings(
    dynamic db,
    Map<String, dynamic> profile,
  ) async {
    if (profile['role'] != 'admin' && profile['role'] != 'super_admin') return;
    final clinicId = profile['role'] == 'super_admin'
        ? null
        : profile['clinic_id'] as String?;
    if (profile['role'] == 'admin' && clinicId == null) {
      throw StateError('The clinic administrator profile has no clinic.');
    }

    final local = await db.getSystemSettings() as SystemSettings;
    var settingsQuery = _supabase
        .from('system_settings')
        .select('value,updated_at')
        .eq('key', 'clinic');
    settingsQuery = clinicId == null
        ? settingsQuery.isFilter('clinic_id', null)
        : settingsQuery.eq('clinic_id', clinicId);
    final remote = await settingsQuery.maybeSingle();
    final remoteUpdatedAt = remote?['updated_at'] != null
        ? DateTime.parse(remote!['updated_at'] as String)
        : null;

    // Push local settings to server when: no remote exists, OR local is newer.
    final localIsNewer =
        local.updatedAt != null &&
        (remoteUpdatedAt == null || local.updatedAt!.isAfter(remoteUpdatedAt));
    if (remote == null || localIsNewer) {
      final updatedAt = local.updatedAt ?? DateTime.now();
      final value = local.toJson()
        ..['updated_at'] = updatedAt.toIso8601String();
      await _supabase.from('system_settings').upsert({
        'clinic_id': clinicId,
        'key': 'clinic',
        'value': value,
        'updated_by': profile['id'],
        'updated_at': updatedAt.toIso8601String(),
      });
      return;
    }

    final value = Map<String, dynamic>.from(remote['value'] as Map)
      ..['updated_at'] = remoteUpdatedAt?.toIso8601String();
    await db.replaceSyncedSystemSettings(SystemSettings.fromJson(value));
  }

  Future<void> _syncGeneratedReports(
    dynamic db,
    Map<String, dynamic> profile,
  ) async {
    final localReports =
        await db.getGeneratedReports() as List<GeneratedReport>;
    final clinicId = profile['clinic_id'];
    final remoteIds = await _selectAllRows('generated_reports', columns: 'id');
    final remoteReportIds = remoteIds.map((row) => row['id'] as String).toSet();
    for (final report in localReports) {
      if (remoteReportIds.contains(report.id)) continue;
      if (clinicId is! String || clinicId.isEmpty) {
        debugPrint(
          'Generated report sync skipped (${report.id}): '
          'the signed-in profile has no clinic.',
        );
        continue;
      }
      await _supabase.from('generated_reports').insert({
        'id': report.id,
        'clinic_id': clinicId,
        'title': report.title,
        'type': report.type,
        'generated_at': report.generatedAt.toIso8601String(),
        'start_date': report.startDate?.toIso8601String(),
        'end_date': report.endDate?.toIso8601String(),
        'created_by': profile['id'],
      });
    }

    final remoteReports = await _selectAllRows('generated_reports');
    final localReportIds = localReports.map((report) => report.id).toSet();
    for (final raw in remoteReports) {
      final data = Map<String, dynamic>.from(raw)..['file_path'] = null;
      if (!localReportIds.contains(data['id'])) {
        await db.insertGeneratedReport(GeneratedReport.fromJson(data));
      }
    }
  }

  Future<void> _pullRemotePatients(dynamic db) async {
    final remotePatients = await _selectAllRows('patients');
    for (final raw in remotePatients) {
      final data = Map<String, dynamic>.from(raw);
      final remote = Patient.fromJson(data);
      final existing = await db.getPatientById(remote.id);
      // Never overwrite an unsynced local edit. For clean local records,
      // accept only a newer authoritative server version.
      final remoteUpdatedAt = remote.updatedAt;
      final localUpdatedAt = existing?.updatedAt;
      if (existing == null ||
          (existing.syncStatus == _synced &&
              remoteUpdatedAt != null &&
              (localUpdatedAt == null ||
                  remoteUpdatedAt.isAfter(localUpdatedAt)))) {
        await db.updatePatient(remote.copyWith(syncStatus: _synced));
      }
    }
  }
}

final syncServiceStateProvider =
    StateNotifierProvider<SyncService, SyncServiceState>((ref) {
      return SyncService(ref);
    });

final syncServiceProvider = Provider<SyncService>((ref) {
  return ref.read(syncServiceStateProvider.notifier);
});

final syncStatusProvider = Provider<SyncStatus>((ref) {
  return ref.watch(syncServiceStateProvider).status;
});

final lastSyncTimeProvider = Provider<DateTime?>((ref) {
  return ref.watch(syncServiceStateProvider).lastSyncTime;
});
