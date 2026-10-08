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

  /// Default starter clinics for Surigao del Sur region
  static final List<Clinic> defaultInitialClinics = [
    Clinic(
      id: 'c1111111-1111-1111-1111-111111111111',
      name: 'RHU Cantilan',
      code: 'RHU-CAN',
      address: 'Poblacion, Cantilan, Surigao del Sur',
      contactNumber: '0917-111-2222',
      email: 'cantilan.rhu@gmail.com',
      status: 'active',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Clinic(
      id: 'c2222222-2222-2222-2222-222222222222',
      name: 'RHU Madrid',
      code: 'RHU-MAD',
      address: 'Poblacion, Madrid, Surigao del Sur',
      contactNumber: '0917-333-4444',
      email: 'madrid.rhu@gmail.com',
      status: 'active',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Clinic(
      id: 'c3333333-3333-3333-3333-333333333333',
      name: 'RHU Carmen',
      code: 'RHU-CAR',
      address: 'Poblacion, Carmen, Surigao del Sur',
      contactNumber: '0917-555-6666',
      email: 'carmen.rhu@gmail.com',
      status: 'active',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  Future<List<Clinic>> getClinics({bool includeInactive = true}) async {
    // Render cached RHUs immediately. A remote refresh updates the cache in
    // the background and triggers the provider through database changes.
    var list = await _db.getAllClinics();
    unawaited(_refreshRemoteClinics());

    // Seed a first-run offline installation with usable RHU data.
    if (list.isEmpty) {
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

        for (final clinic in remote) {
          await _db.insertClinic(clinic);
        }
      }
    } catch (e) {
      debugPrint('ClinicRepository: remote refresh failed: $e');
    }
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

    // Try Supabase insert
    try {
      final client = _supabase;
      if (client != null && client.auth.currentSession != null) {
        await client.from('clinics').insert(clinic.toJson());
      }
    } catch (e) {
      debugPrint('ClinicRepository: createClinic remote insert error: $e');
    }

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
        // 1. Unassign all users from this clinic in Supabase
        await client
            .from('users')
            .update({'clinic_id': null})
            .eq('clinic_id', id);

        // 2. Cascade delete dependent clinic operational records
        try {
          await client.from('documents').delete().eq('clinic_id', id);
          await client.from('generated_reports').delete().eq('clinic_id', id);
          await client.from('patients').delete().eq('clinic_id', id);
        } catch (childErr) {
          debugPrint(
            'ClinicRepository: child records cascade cleanup notice: $childErr',
          );
        }

        // 3. Delete the clinic itself from Supabase
        await client.from('clinics').delete().eq('id', id);
      } catch (e) {
        debugPrint('ClinicRepository: deleteClinic remote delete error: $e');
        rethrow;
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
