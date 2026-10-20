
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../database/simple_database.dart';
import '../models/models.dart';
import 'audit_service.dart';

/// Moves a patient and their documents to another RHU (Super Admin only).
///
/// Document files live under `<clinic id>/<document id>` in storage, and
/// storage access requires the folder to match the document's clinic. Files
/// are therefore downloaded while still readable under the old RHU, removed
/// there, and uploaded under the new RHU after the document is re-pointed.
/// Devices of the old RHU drop their copies on their next sync, because the
/// server no longer shows them the patient.
class PatientTransferService {
  PatientTransferService(this._db, this._audit, {SupabaseClient? client})
    : _clientOverride = client;

  static const _bucket = 'medsentry-medical-documents';

  final SimpleDatabase _db;
  final AuditService _audit;
  final SupabaseClient? _clientOverride;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  /// Returns the number of document files that could not be uploaded under
  /// the new RHU; those are re-uploaded from this device by the next sync.
  Future<int> transfer({
    required Patient patient,
    required Clinic target,
    required User actor,
  }) async {
    if (!actor.isSuperAdmin) {
      throw StateError(
        'Only a Super Administrator can transfer patients between RHUs.',
      );
    }
    if (patient.clinicId == target.id) {
      throw ArgumentError('${patient.fullName} is already in ${target.name}.');
    }
    if ((patient.syncStatus ?? 0) != 0) {
      throw StateError(
        'This patient has changes that have not synced yet. Sync first, '
        'then transfer.',
      );
    }
    if (_client.auth.currentSession == null) {
      throw StateError('Connect to the internet to transfer a patient.');
    }
    final sourceClinicId = patient.clinicId;

    // 1. Read the documents and their files while the old RHU still owns them.
    final documentRows = List<Map<String, dynamic>>.from(
      await _client
          .from('documents')
          .select('id,storage_path,mime_type')
          .eq('patient_id', patient.id),
    );
    final files = <String, Uint8List>{};
    for (final row in documentRows) {
      final path = row['storage_path'];
      if (path is String && path.isNotEmpty) {
        files[row['id'] as String] = await _client.storage
            .from(_bucket)
            .download(path);
      }
    }

    // 2. Move the patient.
    final Map<String, dynamic> saved;
    try {
      saved = await _client
          .from('patients')
          .update({'clinic_id': target.id})
          .eq('id', patient.id)
          .select('updated_at')
          .single();
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw StateError(
          '${target.name} already has a patient with this PhilHealth '
          'number or LGU ID. Merge or correct the records first.',
        );
      }
      rethrow;
    }

    // 3. Move each document and its file.
    var failedUploads = 0;
    final movedDocuments = <String, (String? storagePath, bool uploaded)>{};
    for (final row in documentRows) {
      final documentId = row['id'] as String;
      final oldPath = row['storage_path'] as String?;
      final hasFile = oldPath != null && oldPath.isNotEmpty;
      final newPath = hasFile ? '${target.id}/$documentId' : null;

      if (hasFile) {
        await _client.storage.from(_bucket).remove([oldPath]);
      }
      await _client
          .from('documents')
          .update({'clinic_id': target.id, 'storage_path': newPath})
          .eq('id', documentId);

      var uploaded = true;
      final bytes = files[documentId];
      if (newPath != null && bytes != null) {
        try {
          await _client.storage
              .from(_bucket)
              .uploadBinary(
                newPath,
                bytes,
                fileOptions: FileOptions(
                  upsert: true,
                  contentType: _contentType(row['mime_type'] as String?),
                ),
              );
        } catch (error) {
          debugPrint('Transfer upload failed ($documentId): $error');
          uploaded = false;
          failedUploads++;
        }
      }
      movedDocuments[documentId] = (newPath, uploaded);
    }

    // 4. Update this device to match the server.
    final serverUpdatedAt =
        DateTime.tryParse(saved['updated_at'] as String? ?? '') ??
        DateTime.now();
    await _db.updatePatient(
      patient.copyWith(
        clinicId: target.id,
        updatedAt: serverUpdatedAt,
        serverUpdatedAt: serverUpdatedAt,
        syncStatus: 0,
      ),
    );
    for (final document in await _db.getDocumentsForPatient(patient.id)) {
      final moved = movedDocuments[document.id];
      if (moved == null) continue;
      final (storagePath, uploaded) = moved;
      await _db.updateDocument(
        uploaded
            ? document.copyWith(
                clinicId: target.id,
                storagePath: storagePath,
                syncStatus: 0,
              )
            // Re-uploaded from this device by the next sync.
            : document.copyWith(clinicId: target.id, syncStatus: 2),
      );
    }

    await _audit.logAction(
      actor: actor,
      action: AuditAction.update,
      entityType: 'patient',
      entityId: patient.id,
      clinicId: target.id,
      patientId: patient.id,
      patientName: patient.fullName,
      description:
          'Transferred ${patient.fullName} to ${target.name} '
          '(from clinic $sourceClinicId) with ${documentRows.length} '
          'document${documentRows.length == 1 ? '' : 's'}',
    );
    return failedUploads;
  }

  static String _contentType(String? mimeType) =>
      switch (mimeType?.toLowerCase()) {
        'pdf' => 'application/pdf',
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        _ => 'application/octet-stream',
      };
}
