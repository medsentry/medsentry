import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../database/simple_database.dart';
import '../models/consultation.dart';
import '../models/audit_log.dart';
import '../services/audit_service.dart';

class ConsultationRepository {
  final SimpleDatabase _db;
  final AuditService _auditService;
  final _uuid = const Uuid();

  ConsultationRepository(this._db, this._auditService);

  /// Create a new consultation (SOAP note)
  Future<Consultation> createConsultation({
    required String patientId,
    String? queueId,
    required String subjective,
    required String objective,
    required String assessment,
    required String plan,
    required String icd10Code,
    required String createdBy,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();

    final consultation = Consultation(
      id: id,
      patientId: patientId,
      queueId: queueId,
      subjective: subjective,
      objective: objective,
      assessment: assessment,
      plan: plan,
      icd10Code: icd10Code,
      createdBy: createdBy,
      createdAt: now,
      updatedAt: now,
      syncStatus: 1,
    );

    // Save to database
    await _db.insertConsultation(consultation);

    // Log audit
    await _auditService.logAction(
      userId: createdBy,
      action: AuditAction.create,
      entityType: 'consultation',
      entityId: id,
      patientId: patientId,
      description: 'Created consultation for patient: $patientId',
      newValues: jsonEncode(consultation.toJson()),
    );

    return consultation;
  }

  /// Get consultation by ID
  Future<Consultation?> getConsultationById(String id) async {
    return await _db.getConsultationById(id);
  }

  /// Get all consultations for a patient
  Future<List<Consultation>> getConsultationsForPatient(
    String patientId,
  ) async {
    return await _db.getConsultationsForPatient(patientId);
  }

  /// Get consultation by queue ID
  Future<Consultation?> getConsultationByQueueId(String queueId) async {
    return await _db.getConsultationByQueueId(queueId);
  }

  /// Update an existing consultation
  Future<Consultation> updateConsultation({
    required String id,
    String? subjective,
    String? objective,
    String? assessment,
    String? plan,
    String? icd10Code,
    Set<String> clearFields = const {},
    required String updatedBy,
  }) async {
    final existing = await _db.getConsultationById(id);
    if (existing == null) {
      throw ArgumentError('Consultation not found: $id');
    }

    String? nullable(String field, String? value, String? fallback) {
      if (clearFields.contains(field)) return null;
      return value ?? fallback;
    }

    final updated = Consultation(
      id: existing.id,
      patientId: existing.patientId,
      queueId: existing.queueId,
      doctorId: existing.doctorId,
      consultationDate: existing.consultationDate,
      subjective: nullable('subjective', subjective, existing.subjective),
      objective: nullable('objective', objective, existing.objective),
      assessment: nullable('assessment', assessment, existing.assessment),
      plan: nullable('plan', plan, existing.plan),
      icd10Code: nullable('icd10Code', icd10Code, existing.icd10Code),
      icd10Description: existing.icd10Description,
      isFollowUp: existing.isFollowUp,
      followUpInstructions: existing.followUpInstructions,
      notes: existing.notes,
      createdBy: existing.createdBy,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
      syncStatus: existing.syncStatus == 0 ? 2 : existing.syncStatus,
    );

    // Save to database
    await _db.updateConsultation(updated);

    // Log audit
    await _auditService.logAction(
      userId: updatedBy,
      action: AuditAction.update,
      entityType: 'consultation',
      entityId: id,
      patientId: existing.patientId,
      description: 'Updated consultation: $id',
      oldValues: jsonEncode(existing.toJson()),
      newValues: jsonEncode(updated.toJson()),
    );

    return updated;
  }

  /// Delete a consultation
  Future<void> deleteConsultation({
    required String id,
    required String deletedBy,
  }) async {
    final existing = await _db.getConsultationById(id);
    if (existing == null) {
      throw ArgumentError('Consultation not found: $id');
    }

    // Delete from database
    await _db.deleteConsultation(id);

    // Log audit
    await _auditService.logAction(
      userId: deletedBy,
      action: AuditAction.delete,
      entityType: 'consultation',
      entityId: id,
      patientId: existing.patientId,
      description: 'Deleted consultation: $id',
      oldValues: jsonEncode(existing.toJson()),
    );
  }

  /// Get all consultations (for admin/reports)
  Future<List<Consultation>> getAllConsultations({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var consultations = await _db.getAllConsultations();

    if (startDate != null) {
      consultations = consultations
          .where((c) => c.createdAt != null && c.createdAt!.isAfter(startDate))
          .toList();
    }

    if (endDate != null) {
      consultations = consultations
          .where((c) => c.createdAt != null && c.createdAt!.isBefore(endDate))
          .toList();
    }

    return consultations;
  }

  /// Search consultations by ICD-10 code
  Future<List<Consultation>> searchByIcd10Code(String code) async {
    final all = await _db.getAllConsultations();
    return all
        .where(
          (c) =>
              c.icd10Code != null &&
              c.icd10Code!.toLowerCase().contains(code.toLowerCase()),
        )
        .toList();
  }
}
