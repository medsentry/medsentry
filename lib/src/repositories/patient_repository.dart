import 'dart:convert';
import 'dart:math';
import '../database/simple_database.dart';
import '../models/models.dart';
import '../services/audit_service.dart';
import '../utils/patient_address_data.dart';

class PatientRepository {
  final SimpleDatabase _db;
  final AuditService _auditService;

  PatientRepository(this._db, this._auditService);

  // Simple UUID generator
  String _generateUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  // Create new patient
  Future<Patient> createPatient({
    required String firstName,
    required String lastName,
    String? middleName,
    String? suffix,
    DateTime? dateOfBirth,
    String? gender,
    String? civilStatus,
    String? contactNumber,
    String? email,
    String? address,
    String? barangay,
    String? purokSitio,
    String? city,
    String? province,
    String? zipCode,
    String? philHealthNumber,
    String? bloodType,
    String? emergencyContactName,
    String? emergencyContactNumber,
    String? emergencyContactRelation,
    String? occupation,
    String? religion,
    bool isPwd = false,
    String? employer,
    double? height,
    double? weight,
    String? allergies,
    String? medicalHistory,
    PatientCategory? category,
    required String userId,
  }) async {
    // Validate PhilHealth number format if provided
    if (philHealthNumber != null &&
        !_isValidPhilHealthNumber(philHealthNumber)) {
      throw ArgumentError('Invalid PhilHealth number format');
    }

    final id = _generateUuid();
    final now = DateTime.now();

    final patient = Patient(
      id: id,
      firstName: firstName,
      lastName: lastName,
      middleName: formatMiddleInitial(middleName),
      suffix: normalizeSuffix(suffix),
      dateOfBirth: dateOfBirth,
      gender: gender,
      civilStatus: civilStatus,
      contactNumber: contactNumber,
      email: email,
      address: address,
      barangay: barangay,
      purokSitio: purokSitio,
      city: city,
      province: province,
      zipCode: zipCode,
      philHealthNumber: philHealthNumber,
      bloodType: bloodType,
      emergencyContactName: emergencyContactName,
      emergencyContactNumber: emergencyContactNumber,
      emergencyContactRelation: emergencyContactRelation,
      occupation: occupation,
      religion: religion,
      isPwd: isPwd,
      employer: employer,
      height: height,
      weight: weight,
      allergies: allergies,
      medicalHistory: medicalHistory,
      category: patientCategoryFromDateOfBirth(dateOfBirth) ?? category,
      createdAt: now,
      updatedAt: now,
      syncStatus: 1, // Pending create
    );

    // Insert into database
    await _db.insertPatient(patient);

    // Log audit
    await _auditService.logAction(
      userId: userId,
      action: AuditAction.create,
      entityType: 'patient',
      entityId: id,
      description: 'Created patient: ${patient.fullName}',
      patientId: id,
      patientName: patient.fullName,
      newValues: jsonEncode(patient.toJson()),
    );

    return patient;
  }

  // Get patient by ID
  Future<Patient?> getPatientById(String id) async {
    return await _db.getPatientById(id);
  }

  // Search patients using FTS5
  Future<List<Patient>> searchPatients(String query) async {
    if (query.isEmpty) {
      return await _db.getAllPatients();
    }
    return await _db.searchPatients(query);
  }

  // Get all patients with pagination
  Future<List<Patient>> getPatients({
    int limit = 50,
    int offset = 0,
    String? sortBy,
    bool descending = true,
  }) async {
    return await _db.getPatientsPaginated(limit, offset);
  }

  // Alias for getAllPatients (used by providers)
  Future<List<Patient>> getAllPatients() async {
    return await _db.getAllPatients();
  }

  // Update patient
  Future<Patient> updatePatient({
    required String id,
    String? firstName,
    String? lastName,
    String? middleName,
    String? suffix,
    DateTime? dateOfBirth,
    String? gender,
    String? civilStatus,
    String? contactNumber,
    String? email,
    String? address,
    String? barangay,
    String? purokSitio,
    String? city,
    String? province,
    String? zipCode,
    String? philHealthNumber,
    String? bloodType,
    String? emergencyContactName,
    String? emergencyContactNumber,
    String? emergencyContactRelation,
    String? occupation,
    String? employer,
    String? religion,
    bool? isPwd,
    double? height,
    double? weight,
    String? allergies,
    String? medicalHistory,
    PatientCategory? category,
    Set<String> clearFields = const {},
    required String userId,
  }) async {
    final existing = await _db.getPatientById(id);
    if (existing == null) {
      throw ArgumentError('Patient not found');
    }

    // Validate PhilHealth number if provided
    if (philHealthNumber != null &&
        !_isValidPhilHealthNumber(philHealthNumber)) {
      throw ArgumentError('Invalid PhilHealth number format');
    }

    T? nullable<T>(String field, T? value, T? fallback) {
      if (clearFields.contains(field)) return null;
      return value ?? fallback;
    }

    final updated = Patient(
      id: existing.id,
      firstName: firstName ?? existing.firstName,
      lastName: lastName ?? existing.lastName,
      middleName: nullable(
        'middleName',
        formatMiddleInitial(middleName),
        existing.middleName,
      ),
      suffix: nullable('suffix', normalizeSuffix(suffix), existing.suffix),
      dateOfBirth: nullable('dateOfBirth', dateOfBirth, existing.dateOfBirth),
      gender: nullable('gender', gender, existing.gender),
      civilStatus: nullable('civilStatus', civilStatus, existing.civilStatus),
      religion: nullable('religion', religion, existing.religion),
      contactNumber: nullable(
        'contactNumber',
        contactNumber,
        existing.contactNumber,
      ),
      email: nullable('email', email, existing.email),
      address: nullable('address', address, existing.address),
      barangay: nullable('barangay', barangay, existing.barangay),
      purokSitio: nullable('purokSitio', purokSitio, existing.purokSitio),
      city: nullable('city', city, existing.city),
      province: nullable('province', province, existing.province),
      zipCode: nullable('zipCode', zipCode, existing.zipCode),
      philHealthNumber: nullable(
        'philHealthNumber',
        philHealthNumber,
        existing.philHealthNumber,
      ),
      philHealthCategory: existing.philHealthCategory,
      localLguIdNumber: existing.localLguIdNumber,
      emergencyContactName: nullable(
        'emergencyContactName',
        emergencyContactName,
        existing.emergencyContactName,
      ),
      emergencyContactNumber: nullable(
        'emergencyContactNumber',
        emergencyContactNumber,
        existing.emergencyContactNumber,
      ),
      emergencyContactRelation: nullable(
        'emergencyContactRelation',
        emergencyContactRelation,
        existing.emergencyContactRelation,
      ),
      occupation: nullable('occupation', occupation, existing.occupation),
      employer: nullable('employer', employer, existing.employer),
      isPwd: isPwd ?? existing.isPwd,
      isSoloParent: existing.isSoloParent,
      isIndigenousPerson: existing.isIndigenousPerson,
      tribeEthnolinguisticGroup: existing.tribeEthnolinguisticGroup,
      is4PsBeneficiary: existing.is4PsBeneficiary,
      householdIdNumber: existing.householdIdNumber,
      waterSource: existing.waterSource,
      toiletFacility: existing.toiletFacility,
      bloodType: nullable('bloodType', bloodType, existing.bloodType),
      height: nullable('height', height, existing.height),
      weight: nullable('weight', weight, existing.weight),
      allergies: nullable('allergies', allergies, existing.allergies),
      medicalHistory: nullable(
        'medicalHistory',
        medicalHistory,
        existing.medicalHistory,
      ),
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
      lastVisitDate: existing.lastVisitDate,
      syncStatus: existing.syncStatus == 0 ? 2 : existing.syncStatus,
      syncError: null,
      category:
          patientCategoryFromDateOfBirth(
            nullable('dateOfBirth', dateOfBirth, existing.dateOfBirth),
          ) ??
          nullable('category', category, existing.category),
    );

    await _db.updatePatient(updated);

    await _auditService.logAction(
      userId: userId,
      action: AuditAction.update,
      entityType: 'patient',
      entityId: id,
      description: 'Updated patient: ${updated.fullName}',
      patientId: id,
      patientName: updated.fullName,
      oldValues: jsonEncode(existing.toJson()),
      newValues: jsonEncode(updated.toJson()),
    );

    return updated;
  }

  // Delete patient (soft delete)
  Future<void> deletePatient(String id, String userId) async {
    final patient = await _db.getPatientById(id);
    if (patient == null) {
      throw ArgumentError('Patient not found');
    }

    // Healthcare records must remain recoverable and keep their child
    // consultations/documents intact. Archive instead of physically deleting.
    await _db.archivePatient(id);

    await _auditService.logAction(
      userId: userId,
      action: AuditAction.delete,
      entityType: 'patient',
      entityId: id,
      description: 'Archived patient: ${patient.fullName}',
      patientId: id,
      patientName: patient.fullName,
      oldValues: jsonEncode(patient.toJson()),
    );
  }

  // Get patient count
  Future<int> getPatientCount() async {
    return await _db.getPatientCount();
  }

  // Validate PhilHealth number (12 digits)
  bool _isValidPhilHealthNumber(String number) {
    final cleaned = number.replaceAll(RegExp(r'[^0-9]'), '');
    return cleaned.length == 12;
  }

  // Get patients by barangay (for reporting)
  Future<List<Patient>> getPatientsByBarangay(String barangay) async {
    return await _db.getPatientsByBarangay(barangay);
  }

  // Get recent patients
  Future<List<Patient>> getRecentPatients({int limit = 10}) async {
    return await _db.getRecentPatients(limit);
  }
}
