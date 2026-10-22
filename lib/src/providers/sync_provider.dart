import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:uuid/uuid.dart';

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
import '../utils/push_notification/push_notification_service.dart';
import '../utils/single_flight.dart';
import 'providers.dart';

/// UI-facing sync state shown in the header, dashboard, and sync screen.
enum SyncStatus { synced, syncing, pending, error, offline }

class SyncStats {
  final int totalPatients;
  final int totalDocuments;
  final int totalCertificates;
  final int pendingSync;

  const SyncStats({
    required this.totalPatients,
    required this.totalDocuments,
    this.totalCertificates = 0,
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
  static const String _documentBucket = 'medsentry-medical-documents';

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
      if (_isSyncing) return;
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
    unawaited(createPushNotificationService().requestPermission());
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
            if (table == 'sync_tombstones') {
              final entityType = change.newRecord['entity_type'];
              final recordId = change.newRecord['record_id'];
              if (change.eventType != PostgresChangeEvent.delete &&
                  entityType is String &&
                  recordId is String) {
                await _deleteLocalFiles(
                  await db.applyRemoteDelete(entityType, recordId),
                );
              }
            } else if (change.eventType == PostgresChangeEvent.delete) {
              final id =
                  change.oldRecord['id'] ?? change.oldRecord['record_id'];
              if (id is String) {
                await _deleteLocalFiles(await db.applyRemoteDelete(table, id));
              }
            } else if (change.newRecord.isNotEmpty) {
              await db.applyRemoteUpsert(table, change.newRecord);
              if (table == 'users') {
                final updatedUser = await db.getUserById(
                  change.newRecord['id'] as String,
                );
                if (_ref.read(currentUserProvider)?.id == updatedUser?.id &&
                    updatedUser != null) {
                  if (!updatedUser.isActive) {
                    await _ref.read(authRepositoryProvider).logout();
                    _ref.read(currentUserProvider.notifier).state = null;
                  } else {
                    _ref.read(currentUserProvider.notifier).state = updatedUser;
                  }
                }
              } else if (table == 'notifications' &&
                  change.eventType == PostgresChangeEvent.insert) {
                final title =
                    change.newRecord['title'] as String? ??
                    'System Notification';
                final message = change.newRecord['message'] as String? ?? '';
                final type = change.newRecord['type'] as String? ?? '';
                final target = change.newRecord['target'] as String? ?? 'all';
                final currentUser = _ref.read(currentUserProvider);

                final isAdmin = currentUser?.canManageSystemData == true;
                final isStaff = !isAdmin;
                final matchesRole =
                    target == 'all' ||
                    (target == 'admin' && isAdmin) ||
                    (target == 'super_admin' &&
                        currentUser?.isSuperAdmin == true) ||
                    (target == 'staff' && isStaff);

                if (matchesRole) {
                  if (type.contains('error') ||
                      type.contains('failed') ||
                      type.contains('critical') ||
                      type.contains('suspicious')) {
                    AppNotification.error(title: title, message: message);
                  } else if (type.contains('warning') ||
                      type.contains('alert') ||
                      type.contains('incomplete')) {
                    AppNotification.warning(title: title, message: message);
                  } else {
                    AppNotification.info(title: title, message: message);
                  }

                  try {
                    final pushService = createPushNotificationService();
                    await pushService.showNotification(
                      title: title,
                      body: message,
                      tag: change.newRecord['id'] as String?,
                    );
                  } catch (_) {}
                }
              }
            }
          } catch (e) {
            debugPrint('Error handling realtime change for $table: $e');
          }
          // The event is already applied locally. Only document metadata
          // needs a follow-up pull, to download the file itself. A full sync
          // per event made every device re-download the database whenever
          // anyone saved anything, including the audit rows its own sync wrote.
          if (table == 'documents' &&
              change.eventType != PostgresChangeEvent.delete) {
            _scheduleRealtimeRefresh();
          } else if (table != 'audit_logs') {
            _schedulePendingSync();
          }
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
    Duration delay = const Duration(milliseconds: 500),
  }) {
    if (!_autoSyncEnabled) return;
    _pendingSyncTimer?.cancel();
    _pendingSyncTimer = Timer(delay, () async {
      await _refreshAutoSyncSettings();
      if (!_autoSyncEnabled) return;
      if (_isSyncing || state.status == SyncStatus.syncing) {
        return;
      }
      if (state.status == SyncStatus.offline) return;
      if (_supabase.auth.currentSession == null) {
        await _ref.read(authRepositoryProvider).ensureOnlineSession();
      }
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
  static const Uuid _uuid = Uuid();
  bool _isSyncing = false;
  Future<SyncResult>? _activeSyncOperation;
  final SingleFlight<SyncResult> _cloudSyncPass = SingleFlight<SyncResult>();

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool _isValidUuid(String? str) {
    if (str == null || str.isEmpty) return false;
    return _uuidRegex.hasMatch(str.trim());
  }

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
      await _supabase
          .from('patients')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 8));
      return true;
    } catch (error) {
      debugPrint('Cloud sync health check failed: $error');
      return false;
    }
  }

  Future<SyncStats> getSyncStats() async {
    final db = _ref.read(databaseProvider);
    final user = _ref.read(currentUserProvider);
    final clinicId = user?.isSuperAdmin == true ? null : user?.clinicId;
    final patients = await db.getAllPatients(clinicId: clinicId);
    final documents = await db.getDocuments(clinicId: clinicId);
    final certificates = await db.getIssuedCertificates(clinicId: clinicId);
    final pending = await db.getPendingSyncCount();

    return SyncStats(
      totalPatients: patients.length,
      totalDocuments: documents.length,
      totalCertificates: certificates.length,
      pendingSync: pending,
    );
  }

  Future<SyncResult> startSync() async {
    // If a sync operation is already in flight, reuse its Future instead of
    // erroring. This unifies concurrent triggers (e.g. background timer + manual button click).
    if (_activeSyncOperation != null) {
      return await _activeSyncOperation!;
    }

    final future = _executeSync();
    _activeSyncOperation = future;
    try {
      return await future;
    } finally {
      _activeSyncOperation = null;
    }
  }

  Future<SyncResult> _executeSync() async {
    _isSyncing = true;
    try {
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
          ? await _cloudSyncPass.run(
              _performCloudSync,
              timeout: const Duration(seconds: 45),
              onTimeout: () => const SyncResult(
                message:
                    'Cloud sync is still running on a slow connection. '
                    'Local changes remain saved.',
                success: false,
              ),
            )
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
    } catch (error, stackTrace) {
      debugPrint(
        'Sync execution encountered unhandled error: $error\n$stackTrace',
      );
      state = state.copyWith(status: SyncStatus.error);
      _scheduleSyncRetry();
      return SyncResult(message: 'Sync error: $error', success: false);
    } finally {
      _isSyncing = false;
    }
  }

  void _scheduleSyncRetry() {
    if (_supabase.auth.currentSession == null) return;
    _retrySyncTimer?.cancel();
    if (_retryAttempt >= 5) {
      debugPrint(
        'Automatic sync retry limit reached ($_retryAttempt). Pausing retries until manual trigger or next interval.',
      );
      return;
    }
    const retryDelays = [5, 15, 30, 60, 120];
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
      var synced = 0;
      var failed = 0;

      final profile = await _currentCloudProfile();
      if (profile == null) {
        return const SyncResult(
          message: 'The signed-in account has no active MedSentry profile.',
          success: false,
        );
      }

      // Apply server deletions before pushing, so a stale local copy of a
      // record deleted on another device is dropped instead of re-uploaded.
      await _pullRemoteDeletions(db, profile);

      // Each phase below is isolated. Previously an exception here (for
      // example re-inserting a report deleted elsewhere) aborted the whole
      // sync before deletions were pulled, so every later sync failed too.
      try {
        await _syncSystemSettings(db, profile);
      } catch (error, stackTrace) {
        debugPrint('System settings sync failed: $error\n$stackTrace');
        failed++;
      }
      try {
        final reports = await _syncGeneratedReports(db, profile);
        synced += reports.synced;
        failed += reports.failed;
      } catch (error, stackTrace) {
        debugPrint('Generated report sync failed: $error\n$stackTrace');
        failed++;
      }

      // Include archived patients so an archive action is synchronized rather
      // than leaving the remote copy active.
      for (final patient in await db.getAllPatients(includeArchived: true)) {
        if (patient.syncStatus == _synced) continue;
        try {
          final clinicId = await _clinicIdForUpload(
            'patients',
            patient.id,
            profile,
            recordClinicId: patient.clinicId,
          );
          // updated_at is assigned by the server and stored locally, so every
          // device compares versions on the server's clock. Comparing against
          // device clocks hid remote edits from devices whose clock ran ahead.
          final payload = patient.toJson()
            ..remove('sync_status')
            ..remove('sync_error')
            ..remove('server_updated_at')
            ..remove('updated_at')
            ..['created_at'] ??= DateTime.now().toUtc().toIso8601String();
          payload['clinic_id'] = clinicId;

          final Map<String, dynamic> saved;
          final base = patient.serverUpdatedAt;
          if (base != null) {
            // Apply the edit only to the version this device last saw, so a
            // newer edit from another device is never silently overwritten.
            final rows = await _supabase
                .from('patients')
                .update(payload)
                .eq('id', patient.id)
                // Postgres keeps microseconds but web DateTime keeps only
                // milliseconds, so match the millisecond the base falls in.
                .gte('updated_at', _floorToMillisecond(base).toIso8601String())
                .lt(
                  'updated_at',
                  _floorToMillisecond(
                    base,
                  ).add(const Duration(milliseconds: 1)).toIso8601String(),
                )
                .select('updated_at');
            if (rows.isEmpty) {
              if (await _resolvePatientConflict(db, patient)) {
                synced++;
                continue;
              }
              // The row is gone without a tombstone yet; upload it again.
              saved = await _supabase
                  .from('patients')
                  .upsert(payload)
                  .select('updated_at')
                  .single();
            } else {
              saved = rows.first;
            }
          } else {
            saved = await _supabase
                .from('patients')
                .upsert(payload)
                .select('updated_at')
                .single();
          }

          final serverUpdatedAt = _serverTimestamp(saved) ?? DateTime.now();
          final currentLocal = await db.getPatientById(patient.id);
          if (currentLocal != null &&
              currentLocal.updatedAt == patient.updatedAt) {
            await db.updatePatient(
              currentLocal.copyWith(
                clinicId: clinicId,
                updatedAt: serverUpdatedAt,
                serverUpdatedAt: serverUpdatedAt,
                syncStatus: _synced,
              ),
            );
          }
          synced++;
        } catch (error, stackTrace) {
          if (_isDeletedOnServer(error)) {
            await _deleteLocalFiles(
              await db.applyRemoteDelete('patients', patient.id),
            );
            continue;
          }
          if (_isDuplicatePatientIdentifier(error)) {
            await _notifyDuplicatePatient(db, patient);
          }
          debugPrint(
            'Patient sync failed (${patient.id}): $error\n$stackTrace',
          );
          failed++;
        }
      }

      for (final document in await db.getDocuments()) {
        final hasStoragePath = document.storagePath?.isNotEmpty == true;
        if (document.syncStatus == _synced &&
            (hasStoragePath || document.filePath.trim().isEmpty)) {
          continue;
        }
        try {
          if (document.filePath.trim().isEmpty) {
            if (hasStoragePath || document.syncStatus == _synced) continue;
            throw StateError('The local document file is missing.');
          }
          final clinicId = await _clinicIdForUpload(
            'documents',
            document.id,
            profile,
            recordClinicId: document.clinicId,
          );
          final storagePath = '$clinicId/${document.id}';
          final fileBytes = await DocumentService.readDocumentBytes(
            document.filePath,
          );
          if (fileBytes == null) {
            throw StateError('The local document file could not be read.');
          }

          // Upsert document metadata in database BEFORE uploading binary
          // so storage RLS policies verify document record existence.
          final payload = document.copyWith(storagePath: storagePath).toJson()
            ..remove('sync_status')
            ..remove('file_path')
            ..remove('file_url')
            ..remove('updated_at')
            ..['created_at'] ??= DateTime.now().toUtc().toIso8601String();
          payload['clinic_id'] = clinicId;
          final saved = await _upsertDocumentMetadata(payload);

          await _supabase.storage
              .from(_documentBucket)
              .uploadBinary(
                storagePath,
                fileBytes,
                fileOptions: FileOptions(
                  cacheControl: '0',
                  upsert: true,
                  contentType: _documentContentType(document),
                ),
              );

          final currentDoc = await db.getDocumentById(document.id);
          if (currentDoc != null &&
              currentDoc.updatedAt == document.updatedAt) {
            await db.updateDocument(
              currentDoc.copyWith(
                clinicId: clinicId,
                storagePath: storagePath,
                updatedAt: _serverTimestamp(saved) ?? DateTime.now(),
                syncStatus: _synced,
              ),
            );
          }
          synced++;
        } catch (error, stackTrace) {
          if (_isDeletedOnServer(error)) {
            await _deleteLocalFiles(
              await db.applyRemoteDelete('documents', document.id),
            );
            continue;
          }
          debugPrint(
            'Document sync failed (${document.id}): $error\n$stackTrace',
          );
          failed++;
        }
      }

      for (final user in await db.getAllUsers()) {
        if (user.syncStatus == _synced) continue;
        if (!_isValidUuid(user.id)) {
          final current = await db.getUserById(user.id);
          if (current != null) {
            await db.updateUser(current.copyWith(syncStatus: _synced));
          }
          continue;
        }
        try {
          await _supabase.rpc(
            'medsentry_update_user_account',
            params: {
              'target_user_id': user.id,
              'requested_role': user.role.dbValue,
              'requested_active': user.isActive,
              'requested_first_name': user.firstName,
              'requested_last_name': user.lastName,
              'requested_license_number': user.licenseNumber,
              'requested_specialization': user.specialization,
              'requested_contact_number': user.contactNumber,
              // Photos saved before they were shrunk can exceed the server
              // limit; skip those rather than fail the whole account update.
              'requested_profile_image_url':
                  (user.profileImageUrl?.length ?? 0) <= 1000000
                  ? user.profileImageUrl
                  : null,
            },
          );
          if (user.clinicId != null && _isValidUuid(user.clinicId)) {
            await _supabase
                .from('users')
                .update({'clinic_id': user.clinicId})
                .eq('id', user.id);
          }
          final current = await db.getUserById(user.id);
          if (current != null && current.updatedAt == user.updatedAt) {
            await db.updateUser(current.copyWith(syncStatus: _synced));
          }
          synced++;
        } catch (error, stackTrace) {
          debugPrint('User sync failed (${user.id}): $error\n$stackTrace');
          if (_isPermanentRejection(error)) {
            // The server refused the change (for example, the account no
            // longer exists or this role may not edit it); retrying cannot
            // succeed. Network failures stay pending and are retried.
            final current = await db.getUserById(user.id);
            if (current != null) {
              await db.updateUser(current.copyWith(syncStatus: _synced));
            }
          } else {
            failed++;
          }
        }
      }

      final auditResult = await _pushAuditLogs(db, profile);
      synced += auditResult.synced;
      failed += auditResult.failed;

      // Documents first: a storage file can only be removed while its
      // document row exists, and deleting a patient deletes those rows.
      final deletions = await db.getPendingSyncDeletes();
      deletions.sort(
        (a, b) => _deleteOrder(a['table']).compareTo(_deleteOrder(b['table'])),
      );
      for (final deletion in deletions) {
        final table = deletion['table']!;
        final recordId = deletion['record_id']!;
        try {
          switch (table) {
            case 'clinics':
              await _deleteRemoteClinic(recordId);
            case 'documents':
              await _removeRemoteDocumentFiles(documentId: recordId);
              await _applyRemoteSyncDelete(table, recordId);
            case 'patients':
              await _removeRemoteDocumentFiles(patientId: recordId);
              await _applyRemoteSyncDelete(table, recordId);
            default:
              await _applyRemoteSyncDelete(table, recordId);
          }
          await db.markSyncDeleteComplete(table, recordId);
          synced++;
        } catch (error, stackTrace) {
          debugPrint(
            'Sync deletion failed ($table/$recordId): $error\n$stackTrace',
          );
          failed++;
        }
      }

      await _pullRemotePatients(db);
      await _pullRemoteDocuments(db);
      await _pullRemoteUsers(db);
      await _pullRemoteClinics(db);
      await _pullRemoteAuditLogs(db, profile);
      // Settings > "Keep audit logs on this device for": drop this device's
      // older copies; the cloud keeps the full history.
      await db.pruneSyncedAuditLogs(
        (await db.getSystemSettings()).dataRetentionDays,
      );
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

  /// SQLSTATE raised by the server when a client re-uploads a record that was
  /// permanently deleted elsewhere.
  static bool _isDeletedOnServer(Object error) =>
      error is PostgrestException && error.code == 'MS410';

  /// Server rejections that retrying cannot fix (validation, constraint or
  /// permission failures), as opposed to network or availability errors.
  static bool _isPermanentRejection(Object error) {
    if (error is! PostgrestException) return false;
    final code = error.code ?? '';
    return code.startsWith('22') ||
        code.startsWith('23') ||
        code == '42501' ||
        code == '42703' ||
        code == 'P0002' ||
        code == 'MS410' ||
        code == 'PGRST204';
  }

  static DateTime _floorToMillisecond(DateTime value) =>
      DateTime.fromMillisecondsSinceEpoch(
        value.millisecondsSinceEpoch,
        isUtc: true,
      );

  /// The server enforces one PhilHealth number and one LGU ID per clinic.
  static bool _isDuplicatePatientIdentifier(Object error) =>
      error is PostgrestException &&
      error.code == '23505' &&
      '${error.message} ${error.details}'.contains(
        RegExp('patients_clinic_(philhealth|lgu_id)_uidx'),
      );

  /// Tells staff which patient cannot upload and why, once per patient,
  /// instead of the sync failing silently on every attempt.
  Future<void> _notifyDuplicatePatient(dynamic db, Patient patient) async {
    final id = 'sync-duplicate-${patient.id}';
    final existing = await db.getNotifications() as List<SystemNotification>;
    if (existing.any((notification) => notification.id == id)) return;
    await db.insertNotification(
      SystemNotification(
        id: id,
        clinicId: patient.clinicId,
        type: NotificationType.syncFailed,
        target: NotificationTarget.all,
        priority: NotificationPriority.high,
        title: 'Patient record could not sync',
        message:
            '${patient.fullName} has a PhilHealth number or LGU ID that is '
            'already registered to another patient in this RHU. Open the '
            'record and correct the number, or keep the existing patient '
            'and delete this duplicate.',
        actionRoute: '/patients/${patient.id}',
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Handles an edit made to a version that another device has since
  /// changed. The server copy is kept, the edit made on this device is
  /// preserved in the audit log, and staff are told. Returns false when the
  /// patient no longer exists on the server.
  Future<bool> _resolvePatientConflict(dynamic db, Patient local) async {
    final row = await _supabase
        .from('patients')
        .select()
        .eq('id', local.id)
        .maybeSingle();
    if (row == null) return false;

    final remote = Patient.fromJson(Map<String, dynamic>.from(row));
    final currentUser = _ref.read(currentUserProvider);
    await _ref
        .read(auditServiceProvider)
        .logAction(
          userId: currentUser?.id,
          clinicId: remote.clinicId,
          action: AuditAction.update,
          entityType: 'patient',
          entityId: local.id,
          patientId: local.id,
          patientName: local.fullName,
          description:
              'Sync conflict: edits made on this device were not applied '
              'because another user saved this patient first. The unsaved '
              'version is kept in this entry.',
          oldValues: jsonEncode(local.toJson()),
          newValues: jsonEncode(remote.toJson()),
        );
    await db.updatePatient(
      remote.copyWith(syncStatus: _synced, serverUpdatedAt: remote.updatedAt),
    );
    await db.insertNotification(
      SystemNotification(
        id: 'sync-conflict-${local.id}-${remote.updatedAt?.millisecondsSinceEpoch}',
        clinicId: remote.clinicId,
        type: NotificationType.syncFailed,
        target: NotificationTarget.all,
        priority: NotificationPriority.high,
        title: 'Edit not applied: patient changed elsewhere',
        message:
            'Another user updated ${remote.fullName} before this device '
            'synced. Their version was kept. Your changes are saved in the '
            'Audit Logs; review the record and re-enter anything missing.',
        actionRoute: '/patients/${local.id}',
        createdAt: DateTime.now(),
      ),
    );
    return true;
  }

  static DateTime? _serverTimestamp(Map<String, dynamic> row) {
    final value = row['updated_at'];
    return value is String ? DateTime.tryParse(value) : null;
  }

  static int _deleteOrder(String? table) => switch (table) {
    'documents' => 0,
    'patients' => 1,
    'clinics' => 3,
    _ => 2,
  };

  Future<void> _deleteLocalFiles(List<String> paths) async {
    for (final path in paths) {
      try {
        await DocumentService.deleteDocument(path);
      } catch (error) {
        debugPrint('Local document file cleanup skipped ($path): $error');
      }
    }
  }

  Future<void> _applyRemoteSyncDelete(String table, String recordId) {
    return _supabase.rpc(
      'medsentry_apply_sync_delete',
      params: {'entity': table, 'target_record_id': recordId},
    );
  }

  /// Clinics referenced by patients or staff cannot be hard-deleted (foreign
  /// keys are RESTRICT). Retrying the delete forever kept every sync in an
  /// error state, so a referenced clinic is deactivated instead.
  Future<void> _deleteRemoteClinic(String clinicId) async {
    try {
      await _supabase.from('clinics').delete().eq('id', clinicId);
    } on PostgrestException catch (error) {
      if (error.code != '23503') rethrow;
      await _supabase
          .from('clinics')
          .update({'status': 'inactive'})
          .eq('id', clinicId);
    }
  }

  /// Documents sent with a scanner who has no server account (for example a
  /// legacy local-only user) would fail the scanned_by foreign key forever.
  Future<Map<String, dynamic>> _upsertDocumentMetadata(
    Map<String, dynamic> payload,
  ) async {
    if (!_isValidUuid(payload['scanned_by'] as String?)) {
      payload['scanned_by'] = null;
    }
    try {
      return await _supabase
          .from('documents')
          .upsert(payload)
          .select('updated_at')
          .single();
    } on PostgrestException catch (error) {
      final unknownScanner =
          error.code == '23503' &&
          '${error.message} ${error.details}'.contains('scanned_by');
      if (!unknownScanner) rethrow;
      payload['scanned_by'] = null;
      return _supabase
          .from('documents')
          .upsert(payload)
          .select('updated_at')
          .single();
    }
  }

  Future<({int synced, int failed})> _pushAuditLogs(
    dynamic db,
    Map<String, dynamic> profile,
  ) async {
    final logs = await db.getUnsyncedAuditLogs() as List<AuditLog>;
    var synced = 0;
    var failed = 0;
    final payloads = <String, Map<String, dynamic>>{};
    for (final log in logs) {
      payloads[log.id] = _auditLogPayload(log, profile);
    }

    Future<void> markSynced(Iterable<String> ids) async {
      await db.runBatch(() async {
        for (final id in ids) {
          await db.markAuditLogAsSynced(id);
        }
      });
    }

    // Audit rows are immutable and are inserted, never upserted. An upsert
    // needs UPDATE, which this table never grants, so every upload failed and
    // was silently discarded. ON CONFLICT DO NOTHING is no better: a conflict
    // target needs SELECT, which staff do not have on audit logs. A duplicate
    // key (an earlier upload whose response was lost) counts as uploaded.
    const chunkSize = 100;
    final ids = payloads.keys.toList();
    for (var start = 0; start < ids.length; start += chunkSize) {
      final chunkIds = ids.sublist(
        start,
        (start + chunkSize).clamp(0, ids.length),
      );
      try {
        await _supabase.from('audit_logs').insert([
          for (final id in chunkIds) payloads[id]!,
        ]);
        await markSynced(chunkIds);
        synced += chunkIds.length;
        continue;
      } catch (error) {
        if (!_isPermanentRejection(error)) {
          debugPrint('Audit log upload deferred: $error');
          failed++;
          continue;
        }
      }

      // One rejected row fails its whole chunk; retry individually so only
      // that row is dropped.
      for (final id in chunkIds) {
        try {
          await _supabase.from('audit_logs').insert(payloads[id]!);
          await markSynced([id]);
          synced++;
        } catch (error) {
          debugPrint('Audit log sync failed ($id): $error');
          if (_isPermanentRejection(error)) {
            await markSynced([id]);
          } else {
            failed++;
          }
        }
      }
    }
    return (synced: synced, failed: failed);
  }

  Map<String, dynamic> _auditLogPayload(
    AuditLog log,
    Map<String, dynamic> profile,
  ) {
    final validUserId = _isValidUuid(log.userId) ? log.userId : null;
    final validPatientId = _isValidUuid(log.patientId) ? log.patientId : null;
    final resolvedClinicId = log.clinicId != null && log.clinicId!.isNotEmpty
        ? log.clinicId
        : profile['clinic_id'] as String?;
    final validClinicId = _isValidUuid(resolvedClinicId)
        ? resolvedClinicId
        : null;

    Map<String, dynamic>? newVals;
    if (log.newValues != null && log.newValues!.isNotEmpty) {
      try {
        newVals = Map<String, dynamic>.from(jsonDecode(log.newValues!));
      } catch (_) {
        newVals = {'raw': log.newValues};
      }
    }
    if (validUserId == null && log.userId.isNotEmpty) {
      newVals ??= <String, dynamic>{};
      newVals['_actor'] = log.userId;
      if (log.userName != null) newVals['_user_name'] = log.userName;
      if (log.userRole != null) newVals['_user_role'] = log.userRole;
    }

    // Bulk inserts need identical keys in every row.
    final payload = <String, dynamic>{
      'id': _isValidUuid(log.id)
          ? log.id
          : _uuid.v5(Namespace.url.value, log.id),
      'clinic_id': validClinicId,
      'user_id': validUserId,
      'action': log.action.name,
      'entity_type': log.entityType,
      'entity_id': log.entityId,
      'patient_id': validPatientId,
      'occurred_at': log.timestamp.toUtc().toIso8601String(),
      'old_values': null,
      'new_values': newVals,
    };
    if (log.oldValues != null && log.oldValues!.isNotEmpty) {
      try {
        payload['old_values'] = jsonDecode(log.oldValues!);
      } catch (_) {
        payload['old_values'] = {'raw': log.oldValues};
      }
    }
    return payload;
  }

  Future<void> _pullRemoteDeletions(
    dynamic db,
    Map<String, dynamic> profile,
  ) async {
    final cursorKey = 'sync_tombstones:${profile['id']}';
    final cursor = await db.getSyncCursor(cursorKey) as DateTime?;
    final rows = await _selectAllRows(
      'sync_tombstones',
      columns: 'entity_type,record_id,deleted_at',
      orderBy: const ['deleted_at', 'record_id'],
      sinceColumn: 'deleted_at',
      since: cursor?.subtract(_cursorOverlap),
    );
    if (rows.isEmpty) return;

    final paths = <String>[];
    await db.runBatch(() async {
      for (final deletion in rows) {
        paths.addAll(
          await db.applyRemoteDelete(
                deletion['entity_type'] as String,
                deletion['record_id'] as String,
              )
              as List<String>,
        );
      }
    });
    await _deleteLocalFiles(paths);
    final latest = _latestTimestamp(rows, 'deleted_at');
    if (latest != null) await db.setSyncCursor(cursorKey, latest);
  }

  /// Rows committed by a slow transaction can carry an earlier timestamp than
  /// rows already seen; re-reading this window keeps them from being missed.
  static const Duration _cursorOverlap = Duration(minutes: 5);

  static DateTime? _latestTimestamp(
    List<Map<String, dynamic>> rows,
    String column,
  ) {
    DateTime? latest;
    for (final row in rows) {
      final value = row[column];
      final parsed = value is String ? DateTime.tryParse(value) : null;
      if (parsed != null && (latest == null || parsed.isAfter(latest))) {
        latest = parsed;
      }
    }
    return latest;
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
      final remoteIsNewer =
          local != null &&
          local.syncStatus == _synced &&
          _isRemoteVersionNewer(remote.updatedAt, local.updatedAt);
      final localFileExists =
          local != null &&
          local.filePath.trim().isNotEmpty &&
          await DocumentService.hasLocalDocumentFile(local.filePath);
      final cloudFileAvailable = remote.storagePath?.isNotEmpty == true;

      if (local == null ||
          remoteIsNewer ||
          (!localFileExists && cloudFileAvailable)) {
        var localFilePath = localFileExists ? local!.filePath : '';
        if (!localFileExists && cloudFileAvailable) {
          try {
            final bytes = await _supabase.storage
                .from(_documentBucket)
                .download(remote.storagePath!);
            localFilePath = await DocumentService.saveDocument(
              documentId: remote.id,
              patientId: remote.patientId,
              bytes: bytes,
              fileName: DocumentService.fileNameForDocument(remote),
            );
          } catch (error) {
            debugPrint(
              'Document binary download skipped (${remote.id}): $error',
            );
          }
        }

        final documentToSave = local == null || remoteIsNewer
            ? remote.copyWith(filePath: localFilePath, syncStatus: _synced)
            : local.copyWith(filePath: localFilePath);
        await db.updateDocument(documentToSave);
      }
    }
    await _deleteLocalFiles(
      await db.dropSyncedRecordsMissingFrom('documents', {
        for (final row in rows) row['id'] as String,
      }),
    );
  }

  String _documentContentType(MedicalDocument document) {
    return switch (document.mimeType?.toLowerCase()) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => 'application/octet-stream',
    };
  }

  /// Removes stored files for one document or for every document of a
  /// patient. Must run before the rows are deleted: storage access policies
  /// look up the document row, so orphaned files could never be removed.
  Future<void> _removeRemoteDocumentFiles({
    String? documentId,
    String? patientId,
  }) async {
    var query = _supabase.from('documents').select('storage_path');
    query = documentId != null
        ? query.eq('id', documentId)
        : query.eq('patient_id', patientId!);
    final rows = await query;
    final paths = [
      for (final row in rows)
        if (row['storage_path'] is String &&
            (row['storage_path'] as String).isNotEmpty)
          row['storage_path'] as String,
    ];
    if (paths.isNotEmpty) {
      await _supabase.storage.from(_documentBucket).remove(paths);
    }
  }

  Future<void> _pullRemoteUsers(dynamic db) async {
    final localUsers = {
      for (final user in await db.getAllUsers()) user.id: user,
    };
    final rows = await _selectAllRows('users');
    User? signedInUserUpdate;
    await db.runBatch(() async {
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
          if (_ref.read(currentUserProvider)?.id == remote.id) {
            signedInUserUpdate = updated;
          }
        }
      }

      // User deletions leave no tombstone, so drop synced local accounts the
      // server no longer returns. Only within what RLS lets this user read:
      // a Super Admin sees everyone, an Admin only their own RHU.
      final actor = _ref.read(currentUserProvider);
      if (actor == null || rows.isEmpty) return;
      final remoteIds = {for (final raw in rows) raw['id'] as String};
      for (final local in localUsers.values) {
        final visible =
            actor.isSuperAdmin ||
            (actor.role == UserRole.admin && local.clinicId == actor.clinicId);
        if (visible &&
            local.id != actor.id &&
            local.syncStatus == _synced &&
            !remoteIds.contains(local.id)) {
          await db.deleteUser(local.id);
        }
      }
    });

    final updated = signedInUserUpdate;
    if (updated == null) return;
    if (!updated.isActive) {
      await _ref.read(authRepositoryProvider).logout();
      _ref.read(currentUserProvider.notifier).state = null;
    } else {
      _ref.read(currentUserProvider.notifier).state = updated;
    }
  }

  Future<void> _pullRemoteClinics(dynamic db) async {
    final rows = await _selectAllRows('clinics');
    final remote = [
      for (final raw in rows) Clinic.fromJson(Map<String, dynamic>.from(raw)),
    ];
    await _ref.read(clinicRepositoryProvider).reconcileWithRemote(remote);
  }

  Future<void> _pullRemoteAuditLogs(
    dynamic db,
    Map<String, dynamic> profile,
  ) async {
    final cursorKey = 'audit_logs:${profile['id']}';
    final cursor = await db.getSyncCursor(cursorKey) as DateTime?;
    List<Map<String, dynamic>> rows;
    var incremental = true;
    try {
      rows = await _selectAllRows(
        'audit_logs',
        orderBy: const ['recorded_at', 'id'],
        sinceColumn: 'recorded_at',
        since: cursor?.subtract(_cursorOverlap),
      );
    } on PostgrestException catch (error) {
      // Server not yet migrated (no recorded_at column): full pull.
      if (error.code != '42703') rethrow;
      incremental = false;
      rows = await _selectAllRows('audit_logs');
    }
    if (rows.isEmpty) return;

    final localIds = {for (final log in await db.getAllAuditLogs()) log.id};
    final users = {for (final user in await db.getAllUsers()) user.id: user};

    await db.runBatch(() async {
      for (final row in rows) {
        final id = row['id'] as String;
        if (localIds.contains(id)) continue;
        final userId = row['user_id'] as String? ?? 'system';
        final user = users[userId];
        final timestamp = row['occurred_at'] ?? row['timestamp'];
        if (timestamp is! String) continue;
        final parsedTimestamp = DateTime.tryParse(timestamp);
        if (parsedTimestamp == null) continue;
        await db.insertAuditLog(
          AuditLog(
            id: id,
            clinicId: (row['clinic_id'] as String?) ?? user?.clinicId,
            userId: userId,
            userName: user?.fullName,
            userRole: user?.roleDisplay,
            action: _auditActionFromRemote(row['action']?.toString() ?? ''),
            entityType: row['entity_type'] as String? ?? 'system',
            entityId: row['entity_id'] as String?,
            patientId: row['patient_id'] as String?,
            oldValues: _auditJsonValue(row['old_values']),
            newValues: _auditJsonValue(row['new_values']),
            timestamp: parsedTimestamp,
            isSynced: true,
            syncStatus: _synced,
          ),
        );
      }
    });

    if (incremental) {
      final latest = _latestTimestamp(rows, 'recorded_at');
      if (latest != null) await db.setSyncCursor(cursorKey, latest);
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
    List<String>? orderBy,
    String? sinceColumn,
    DateTime? since,
  }) async {
    const pageSize = 500;
    final rows = <Map<String, dynamic>>[];
    var offset = 0;
    final orderColumns =
        orderBy ?? [table == 'sync_tombstones' ? 'deleted_at' : 'id'];

    while (true) {
      var filter = _supabase.from(table).select(columns);
      if (sinceColumn != null && since != null) {
        filter = filter.gte(sinceColumn, since.toUtc().toIso8601String());
      }
      var ordered = filter.order(orderColumns.first, ascending: true);
      for (final column in orderColumns.skip(1)) {
        ordered = ordered.order(column, ascending: true);
      }
      final page = await ordered
          .range(offset, offset + pageSize - 1)
          .timeout(const Duration(seconds: 15));
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
    await db.runBatch(() async {
      for (final raw in rows) {
        final row = Map<String, dynamic>.from(raw);
        final target = row['target'] == 'super_admin' ? 'admin' : row['target'];
        final remote = SystemNotification.fromJson({...row, 'target': target});
        final existing = local[remote.id];
        if (existing == null) {
          await db.insertNotification(remote);
        } else {
          final mergedIsRead = existing.isRead || remote.isRead;
          if (existing.isRead != mergedIsRead ||
              existing.title != remote.title ||
              existing.message != remote.message ||
              existing.priority != remote.priority) {
            await db.insertNotification(remote.copyWith(isRead: mergedIsRead));
          }
        }
      }
    });
  }

  Future<Map<String, dynamic>?> _currentCloudProfile() async {
    final authId = _supabase.auth.currentUser?.id;
    if (authId == null) return null;
    try {
      final row = await _supabase
          .from('users')
          .select('id,role,clinic_id')
          .eq('auth_user_id', authId)
          .maybeSingle()
          .timeout(const Duration(seconds: 15));
      return row == null ? null : Map<String, dynamic>.from(row);
    } catch (e) {
      debugPrint('Error fetching current cloud profile: $e');
      return null;
    }
  }

  Future<String> _clinicIdForUpload(
    String table,
    String recordId,
    Map<String, dynamic> profile, {
    String? recordClinicId,
  }) async {
    if (recordClinicId != null && recordClinicId.isNotEmpty) {
      return recordClinicId;
    }
    final clinicId = profile['clinic_id'];
    if (clinicId is String && clinicId.isNotEmpty) return clinicId;

    if (profile['role'] == 'super_admin') {
      try {
        final existing = await _supabase
            .from(table)
            .select('clinic_id')
            .eq('id', recordId)
            .maybeSingle();
        final existingClinicId = existing?['clinic_id'];
        if (existingClinicId is String && existingClinicId.isNotEmpty) {
          return existingClinicId;
        }
      } catch (_) {}
    }

    final activeClinicId = _ref.read(activeClinicIdProvider);
    if (activeClinicId != null && activeClinicId.isNotEmpty) {
      return activeClinicId;
    }

    // Only a single, unambiguous clinic is a safe default. Inventing a
    // clinic here created tenants on the server that nobody had registered.
    final remoteClinics = await _supabase.from('clinics').select('id').limit(2);
    if (remoteClinics.length == 1 && remoteClinics.first['id'] is String) {
      return remoteClinics.first['id'] as String;
    }

    throw StateError(
      'Cannot sync $table/$recordId because its clinic is not known. '
      'Assign the record to an RHU first.',
    );
  }

  Future<void> _syncSystemSettings(
    dynamic db,
    Map<String, dynamic> profile,
  ) async {
    final role = profile['role'] as String?;
    if (role != 'admin' && role != 'super_admin' && role != 'staff') return;
    final isAdmin = role == 'admin' || role == 'super_admin';
    final clinicId = role == 'super_admin'
        ? null
        : profile['clinic_id'] as String?;
    if (role != 'super_admin' && clinicId == null) {
      debugPrint('Sync system settings skipped: profile has no clinic.');
      return;
    }

    final local = await db.getSystemSettings() as SystemSettings;
    var settingsQuery = _supabase
        .from('system_settings')
        .select('id,value,updated_at')
        .eq('key', 'clinic');
    settingsQuery = clinicId == null
        ? settingsQuery.isFilter('clinic_id', null)
        : settingsQuery.eq('clinic_id', clinicId);
    final remote = await settingsQuery.maybeSingle();
    final remoteUpdatedAt = remote?['updated_at'] != null
        ? DateTime.tryParse(remote!['updated_at'] as String)
        : null;

    // Only administrators write settings; staff pull the clinic's branding.
    final localIsNewer =
        local.updatedAt != null &&
        (remoteUpdatedAt == null || local.updatedAt!.isAfter(remoteUpdatedAt));
    if (isAdmin && (remote == null || localIsNewer)) {
      final updatedAt = local.updatedAt ?? DateTime.now();
      final value = local.toJson()
        ..['updated_at'] = updatedAt.toIso8601String();
      final Map<String, dynamic> saved;
      if (remote != null && remote['id'] != null) {
        saved = await _supabase
            .from('system_settings')
            .update({
              'value': value,
              'updated_by': profile['id'],
              'updated_at': updatedAt.toIso8601String(),
            })
            .eq('id', remote['id'])
            .select('updated_at')
            .single();
      } else {
        saved = await _supabase
            .from('system_settings')
            .insert({
              'clinic_id': clinicId,
              'key': 'clinic',
              'value': value,
              'updated_by': profile['id'],
              'updated_at': updatedAt.toIso8601String(),
            })
            .select('updated_at')
            .single();
      }
      // Adopt the server's timestamp. Keeping the device time made a device
      // whose clock ran ahead re-upload its settings on every sync, and each
      // upload fanned out to every other device as a realtime change.
      final serverUpdatedAt = _serverTimestamp(saved);
      final current = await db.getSystemSettings() as SystemSettings;
      if (serverUpdatedAt != null && current.updatedAt == local.updatedAt) {
        await db.replaceSyncedSystemSettings(
          current.copyWith(updatedAt: serverUpdatedAt),
        );
      }
      return;
    }

    if (remote == null) return;

    final value = Map<String, dynamic>.from(remote['value'] as Map)
      ..['updated_at'] = remoteUpdatedAt?.toIso8601String();
    await db.replaceSyncedSystemSettings(SystemSettings.fromJson(value));
  }

  Future<({int synced, int failed})> _syncGeneratedReports(
    dynamic db,
    Map<String, dynamic> profile,
  ) async {
    var synced = 0;
    var failed = 0;
    final localReports =
        await db.getGeneratedReports() as List<GeneratedReport>;
    final localClinics = await db.getAllClinics() as List<Clinic>;
    final fallbackClinicId = localClinics.isNotEmpty
        ? localClinics.first.id
        : null;
    final profileClinicId = profile['clinic_id'] as String?;
    final remoteIds = await _selectAllRows('generated_reports', columns: 'id');
    final remoteReportIds = remoteIds.map((row) => row['id'] as String).toSet();
    for (final report in localReports) {
      if (remoteReportIds.contains(report.id)) continue;
      final clinicId = (report.clinicId != null && report.clinicId!.isNotEmpty)
          ? report.clinicId
          : (profileClinicId != null && profileClinicId.isNotEmpty)
          ? profileClinicId
          : fallbackClinicId;
      if (clinicId == null || clinicId.isEmpty) {
        debugPrint(
          'Generated report sync skipped (${report.id}): '
          'the signed-in profile has no clinic.',
        );
        continue;
      }
      try {
        // A report deleted on another device is hidden from this device but
        // still exists; ignoring the duplicate lets its tombstone remove the
        // local copy instead of failing the insert on every sync.
        await _supabase.from('generated_reports').upsert({
          'id': report.id,
          'clinic_id': clinicId,
          'title': report.title,
          'type': report.type,
          'generated_at': report.generatedAt.toIso8601String(),
          'start_date': report.startDate?.toIso8601String(),
          'end_date': report.endDate?.toIso8601String(),
          'created_by': profile['id'],
        }, ignoreDuplicates: true);
        synced++;
      } catch (error) {
        debugPrint('Generated report upload failed (${report.id}): $error');
        if (!_isPermanentRejection(error)) failed++;
      }
    }

    final remoteReports = await _selectAllRows('generated_reports');
    final localReportIds = localReports.map((report) => report.id).toSet();
    await db.runBatch(() async {
      for (final raw in remoteReports) {
        final data = Map<String, dynamic>.from(raw)..['file_path'] = null;
        if (!localReportIds.contains(data['id'])) {
          await db.insertGeneratedReport(GeneratedReport.fromJson(data));
        }
      }
    });
    return (synced: synced, failed: failed);
  }

  Future<void> _pullRemotePatients(dynamic db) async {
    final remotePatients = await _selectAllRows('patients');
    await db.runBatch(() async {
      for (final raw in remotePatients) {
        final data = Map<String, dynamic>.from(raw);
        final remote = Patient.fromJson(data);
        if (await db.isPatientPurged(remote.id)) {
          continue;
        }
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
          await db.updatePatient(
            remote.copyWith(
              syncStatus: _synced,
              serverUpdatedAt: remote.updatedAt,
            ),
          );
        }
      }
    });
    // Patients this account can no longer see (for example transferred to
    // another RHU) leave this device.
    await _deleteLocalFiles(
      await db.dropSyncedRecordsMissingFrom('patients', {
        for (final row in remotePatients) row['id'] as String,
      }),
    );
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

final syncStatsProvider = FutureProvider<SyncStats>((ref) async {
  ref.watch(databaseChangesProvider);
  ref.watch(activeClinicIdProvider);
  ref.watch(syncServiceStateProvider);
  return ref.read(syncServiceProvider).getSyncStats();
});
