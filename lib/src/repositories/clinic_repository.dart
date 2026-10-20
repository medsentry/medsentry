import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/simple_database.dart';
import '../models/clinic.dart';
import '../models/audit_log.dart';
import '../services/audit_service.dart';

class ClinicRepository {
  static const _remoteFetchTimeout = Duration(seconds: 5);

  final SimpleDatabase _db;
  final AuditService _auditService;
  final SupabaseClient? _supabase;
  Future<void>? _remoteRefresh;

  ClinicRepository(this._db, this._auditService, [SupabaseClient? supabase])
    : _supabase = supabase ?? (Supabase.instance.client);

  String _generateUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// First-run offline clinics. These must match the RHUs seeded by
  /// supabase/migrations/20260929000000_initial_schema.sql: records created
  /// under a clinic ID the server does not have can never be uploaded.
  static final List<Clinic> defaultInitialClinics = [
    Clinic(
      id: '11111111-1111-4111-8111-111111111111',
      name: 'RHU Parang',
      code: 'RHU-PARANG',
      address: 'Parang, Maguindanao del Norte',
      contactNumber: '09171110001',
      status: 'active',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Clinic(
      id: '22222222-2222-4222-8222-222222222222',
      name: 'RHU Puyat',
      code: 'RHU-PUYAT',
      address: 'Puyat, San Agustin, Surigao del Sur',
      contactNumber: '09172220002',
      status: 'active',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Clinic(
      id: '33333333-3333-4333-8333-333333333333',
      name: 'RHU Cantilan',
      code: 'RHU-CANTILAN',
      address: 'Cantilan, Surigao del Sur',
      contactNumber: '09173330003',
      status: 'active',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  /// Clinic IDs shipped by earlier builds that never existed on the server.
  static const Set<String> _legacyLocalClinicIds = {
    'c1111111-1111-1111-1111-111111111111',
    'c2222222-2222-2222-2222-222222222222',
    'c3333333-3333-3333-3333-333333333333',
  };

  Future<List<Clinic>> getClinics({bool includeInactive = true}) async {
    // Render cached RHUs immediately. A remote refresh updates the cache in
    // the background and triggers the provider through database changes.
    var list = await _db.getAllClinics();
    unawaited(_refreshRemoteClinics());

    // Seed a first-run offline installation with usable RHU data once.
    if (list.isEmpty && !(await _db.isClinicsSeeded())) {
      await _db.setClinicsSeeded(true);
      for (final def in defaultInitialClinics) {
        await _db.insertClinic(def);
        list.add(def);
      }
    }

    if (!includeInactive) {
      list = list.where((c) => c.isActive).toList();
    }

    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<void> _refreshRemoteClinics() {
    return _remoteRefresh ??= _fetchRemoteClinics().whenComplete(() {
      _remoteRefresh = null;
    });
  }

  Future<void> _fetchRemoteClinics() async {
    try {
      final client = _supabase;
      if (client != null && client.auth.currentSession != null) {
        final query = client.from('clinics').select();
        final response = await query
            .order('name', ascending: true)
            .timeout(_remoteFetchTimeout);
        final remote = (response as List)
            .map((item) => Clinic.fromJson(Map<String, dynamic>.from(item)))
            .toList();

        if (remote.isNotEmpty) {
          await _db.setClinicsSeeded(true);
        }

        await reconcileWithRemote(remote);
      }
    } catch (e) {
      debugPrint('ClinicRepository: remote refresh failed: $e');
    }
  }

  /// Makes the server's clinics authoritative. A local clinic that duplicates
  /// a server clinic by name or code under a different ID was invented
  /// offline; it is replaced and its records move to the server ID. Skipping
  /// the server copy instead would strand those records, because uploads
  /// fail the clinic foreign key.
  Future<void> reconcileWithRemote(List<Clinic> remote) async {
    await _db.runBatch(() async {
      final remoteIds = {for (final clinic in remote) clinic.id};
      for (final clinic in remote) {
        final existing = await _db.getAllClinics();
        for (final local in existing) {
          if (local.id == clinic.id || remoteIds.contains(local.id)) continue;
          final sameName =
              local.name.toLowerCase() == clinic.name.toLowerCase();
          final sameCode =
              local.code.toLowerCase() == clinic.code.toLowerCase();
          if (sameName || sameCode) {
            await _db.replaceClinicId(local.id, clinic);
          }
        }
        await _db.insertClinic(clinic);
      }

      // Unused legacy seed clinics with no server counterpart would only
      // invite new records that can never upload.
      final patients = await _db.getAllPatients(includeArchived: true);
      for (final local in await _db.getAllClinics()) {
        if (_legacyLocalClinicIds.contains(local.id) &&
            !remoteIds.contains(local.id) &&
            !patients.any((patient) => patient.clinicId == local.id)) {
          await _db.applyRemoteDelete('clinics', local.id);
        }
      }
    });
  }

  Future<Clinic?> getClinicById(String id) async {
    try {
      final client = _supabase;
      if (client != null && client.auth.currentSession != null) {
        final response = await client
            .from('clinics')
            .select()
            .eq('id', id)
            .maybeSingle();
        if (response != null) {
          final clinic = Clinic.fromJson(Map<String, dynamic>.from(response));
          await _db.insertClinic(clinic);
          return clinic;
        }
      }
    } catch (e) {
      debugPrint('ClinicRepository: getClinicById remote error: $e');
    }

    return await _db.getClinicById(id);
  }

  Future<Clinic> createClinic({
    required String name,
    required String code,
    String? address,
    String? contactNumber,
    String? email,
    String status = 'active',
    String? actorUserId,
  }) async {
    final now = DateTime.now();
    final clinicId = _generateUuid();

    final clinic = Clinic(
      id: clinicId,
      name: name.trim(),
      code: code.trim().toUpperCase(),
      address: address?.trim(),
      contactNumber: contactNumber?.trim(),
      email: email?.trim().toLowerCase(),
      status: status,
      createdAt: now,
      updatedAt: now,
    );

    // Patients and staff reference clinics by foreign key on the server, so a
    // clinic that exists only on this device would block all their uploads.
    final client = _supabase;
    if (client == null || client.auth.currentSession == null) {
      throw StateError('Connect to the internet to register a new RHU.');
    }
    await client.from('clinics').insert(clinic.toJson());

    await _db.setClinicsSeeded(true);
    await _db.insertClinic(clinic);

    if (actorUserId != null) {
      await _auditService.logAction(
        userId: actorUserId,
        action: AuditAction.create,
        entityType: 'clinic',
        entityId: clinic.id,
        description: 'Created RHU: ${clinic.name} (${clinic.code})',
      );
    }

    return clinic;
  }

  Future<Clinic> updateClinic(Clinic clinic, {String? actorUserId}) async {
    final updated = clinic.copyWith(updatedAt: DateTime.now());

    try {
      final client = _supabase;
      if (client != null && client.auth.currentSession != null) {
        await client
            .from('clinics')
            .update(updated.toJson())
            .eq('id', updated.id);
      }
    } catch (e) {
      debugPrint('ClinicRepository: updateClinic remote update error: $e');
    }

    await _db.updateClinic(updated);

    if (actorUserId != null) {
      await _auditService.logAction(
        userId: actorUserId,
        action: AuditAction.update,
        entityType: 'clinic',
        entityId: updated.id,
        description: 'Updated RHU: ${updated.name} (${updated.code})',
      );
    }

    return updated;
  }

  Future<void> toggleClinicStatus(
    String id,
    bool active, {
    String? actorUserId,
  }) async {
    final existing = await getClinicById(id);
    if (existing == null) return;

    final updated = existing.copyWith(
      status: active ? 'active' : 'inactive',
      updatedAt: DateTime.now(),
    );

    await updateClinic(updated, actorUserId: actorUserId);
  }

  Future<void> deleteClinic(String id, {String? actorUserId}) async {
    final existing = await getClinicById(id);

    final client = _supabase;
    if (client != null && client.auth.currentSession != null) {
      try {
        await client.from('clinics').delete().eq('id', id);
      } catch (e) {
        debugPrint(
          'ClinicRepository: remote clinic hard-delete restricted (archiving instead): $e',
        );
        try {
          await client
              .from('clinics')
              .update({
                'status': 'inactive',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', id);
        } catch (softErr) {
          debugPrint(
            'ClinicRepository: remote soft-deactivate notice: $softErr',
          );
        }
      }
    }

    // Always delete locally and unassign users in simple_database
    await _db.deleteClinic(id);

    if (actorUserId != null && existing != null) {
      await _auditService.logAction(
        userId: actorUserId,
        action: AuditAction.delete,
        entityType: 'clinic',
        entityId: id,
        description: 'Deleted RHU: ${existing.name} (${existing.code})',
      );
    }
  }
}
