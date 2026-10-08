import '../models/models.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'drift_database.g.dart';

extension PatientEntityMapper on PatientEntity {
  Patient toModel() {
    return Patient(
      id: id,
      firstName: firstName,
      lastName: lastName,
      middleName: middleName,
      suffix: suffix,
      dateOfBirth: dateOfBirth,
      gender: gender,
      civilStatus: civilStatus,
      religion: religion,
      contactNumber: contactNumber,
      email: email,
      address: address,
      barangay: barangay,
      purokSitio: purokSitio,
      city: city,
      province: province,
      zipCode: zipCode,
      philHealthNumber: philHealthNumber,
      philHealthCategory: philHealthCategory != null 
          ? PhilHealthCategory.values.firstWhere((e) => e.name == philHealthCategory, orElse: () => PhilHealthCategory.directContributor)
          : null,
      localLguIdNumber: localLguIdNumber,
      bloodType: bloodType,
      emergencyContactName: emergencyContactName,
      emergencyContactNumber: emergencyContactNumber,
      emergencyContactRelation: emergencyContactRelation,
      occupation: occupation,
      employer: employer,
      isPwd: isPwd,
      isSoloParent: isSoloParent,
      isIndigenousPerson: isIndigenousPerson,
      tribeEthnolinguisticGroup: tribeEthnolinguisticGroup,
      is4PsBeneficiary: is4PsBeneficiary,
      householdIdNumber: householdIdNumber,
      waterSource: waterSource != null 
          ? WaterSourceLevel.values.firstWhere((e) => e.name == waterSource, orElse: () => WaterSourceLevel.level1)
          : null,
      toiletFacility: toiletFacility != null 
          ? ToiletFacilityType.values.firstWhere((e) => e.name == toiletFacility, orElse: () => ToiletFacilityType.waterSealed)
          : null,
      height: height,
      weight: weight,
      allergies: allergies,
      medicalHistory: medicalHistory,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastVisitDate: lastVisitDate,
      syncStatus: syncStatus,
      syncError: syncError,
      category: category != null 
          ? PatientCategory.values.firstWhere((e) => e.name == category, orElse: () => PatientCategory.adult)
          : null,
    );
  }
}

extension QueueItemEntityMapper on QueueItemEntity {
  QueueItem toModel() {
    return QueueItem(
      id: id,
      patientId: patientId,
      patientName: "Loading...", // Will be joined in UI ideally, or resolved
      purpose: category ?? "",
      arrivalTime: arrivalTime,
      status: QueueStatus.values.firstWhere((e) => e.name == status, orElse: () => QueueStatus.waiting),
      createdAt: createdAt,
      updatedAt: updatedAt,
      syncStatus: 1, // Defaulting
    );
  }
}

extension ConsultationEntityMapper on ConsultationEntity {
  Consultation toModel() {
    return Consultation(
      id: id,
      patientId: patientId,
      doctorId: createdBy,
      consultationDate: createdAt,
      subjective: subjective,
      objective: objective,
      assessment: assessment,
      plan: plan,
      icd10Code: icd10Code,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

extension DocumentEntityMapper on DocumentEntity {
  MedicalDocument toModel() {
    return MedicalDocument(
      id: id,
      patientId: patientId,
      title: title,
      description: description,
      type: DocumentType.values.firstWhere((e) => e.name == type, orElse: () => DocumentType.labResult),
      filePath: filePath ?? '',
      fileUrl: fileUrl,
      fileSize: 0,
      mimeType: fileType,
      scannedBy: uploadedBy,
      scanDate: createdAt,
      status: DocumentStatus.values.firstWhere((e) => e.name == status, orElse: () => DocumentStatus.pending),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

extension AuditLogEntityMapper on AuditLogEntity {
  AuditLog toModel() {
    return AuditLog(
      id: id.toString(),
      userId: userId,
      action: AuditAction.values.firstWhere((e) => e.name == action, orElse: () => AuditAction.read),
      entityType: entityType,
      entityId: entityId,
      description: description ?? '',
      timestamp: timestamp,
    );
  }
}

extension MedSentryDatabaseExtensions on MedSentryDatabase {
  Stream<List<Patient>> watchAllPatients() {
    return select(patients).watch().map((rows) => rows.map((e) => e.toModel()).toList());
  }

  Stream<Patient?> watchPatientById(String id) {
    return (select(patients)..where((t) => t.id.equals(id))).watchSingleOrNull().map((e) => e?.toModel());
  }

  Stream<List<QueueItem>> watchQueueItems() {
    return select(queueItems).watch().map((rows) => rows.map((e) => e.toModel()).toList());
  }

  Stream<QueueItem?> watchQueueItemById(String id) {
    return (select(queueItems)..where((t) => t.id.equals(id))).watchSingleOrNull().map((e) => e?.toModel());
  }

  Stream<List<MedicalDocument>> watchDocuments() {
    return select(documents).watch().map((rows) => rows.map((e) => e.toModel()).toList());
  }

  Stream<List<Consultation>> watchConsultationsForPatient(String pId) {
    return (select(consultations)..where((t) => t.patientId.equals(pId))).watch().map((rows) => rows.map((e) => e.toModel()).toList());
  }

  Stream<List<MedicalDocument>> watchDocumentsForPatient(String pId) {
    return (select(documents)..where((t) => t.patientId.equals(pId))).watch().map((rows) => rows.map((e) => e.toModel()).toList());
  }

  Stream<List<QueueItem>> watchPatientQueueHistory(String pId) {
    return (select(queueItems)..where((t) => t.patientId.equals(pId))).watch().map((rows) => rows.map((e) => e.toModel()).toList());
  }

  Stream<List<AuditLog>> watchAuditLogsForPatient(String pId) {
    return (select(auditLogs)..where((t) => t.entityId.equals(pId))).watch().map((rows) => rows.map((e) => e.toModel()).toList());
  }
}

// ==================== USERS TABLE ====================
@DataClassName('UserEntity')
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get email => text()();
  TextColumn get firstName => text()();
  TextColumn get lastName => text()();
  TextColumn get role => text()();
  TextColumn get licenseNumber => text().nullable()();
  TextColumn get specialization => text().nullable()();
  TextColumn get contactNumber => text().nullable()();
  BoolColumn get isActive => boolean()();
  BoolColumn get pinEnabled => boolean()();
  TextColumn get pinHash => text().nullable()();
  TextColumn get passwordHash => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ==================== PATIENTS TABLE ====================
@DataClassName('PatientEntity')
class Patients extends Table {
  TextColumn get id => text()();
  TextColumn get firstName => text()();
  TextColumn get lastName => text()();
  TextColumn get middleName => text().nullable()();
  TextColumn get suffix => text().nullable()();
  DateTimeColumn get dateOfBirth => dateTime().nullable()();
  TextColumn get gender => text().nullable()();
  TextColumn get civilStatus => text().nullable()();
  TextColumn get religion => text().nullable()();
  TextColumn get contactNumber => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get barangay => text().nullable()();
  TextColumn get purokSitio => text().nullable()();
  TextColumn get city => text().nullable()();
  TextColumn get province => text().nullable()();
  TextColumn get zipCode => text().nullable()();
  
  TextColumn get philHealthNumber => text().nullable()();
  TextColumn get philHealthCategory => text().nullable()();
  TextColumn get localLguIdNumber => text().nullable()();
  
  TextColumn get bloodType => text().nullable()();
  TextColumn get emergencyContactName => text().nullable()();
  TextColumn get emergencyContactNumber => text().nullable()();
  TextColumn get emergencyContactRelation => text().nullable()();
  
  TextColumn get occupation => text().nullable()();
  TextColumn get employer => text().nullable()();
  BoolColumn get isPwd => boolean().withDefault(const Constant(false))();
  BoolColumn get isSoloParent => boolean().withDefault(const Constant(false))();
  BoolColumn get isIndigenousPerson => boolean().withDefault(const Constant(false))();
  TextColumn get tribeEthnolinguisticGroup => text().nullable()();
  BoolColumn get is4PsBeneficiary => boolean().withDefault(const Constant(false))();
  TextColumn get householdIdNumber => text().nullable()();
  
  TextColumn get waterSource => text().nullable()();
  TextColumn get toiletFacility => text().nullable()();
  
  RealColumn get height => real().nullable()();
  RealColumn get weight => real().nullable()();
  TextColumn get allergies => text().nullable()();
  TextColumn get medicalHistory => text().nullable()();
  TextColumn get category => text().nullable()();
  
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get lastVisitDate => dateTime().nullable()();
  IntColumn get syncStatus => integer().nullable()();
  TextColumn get syncError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ==================== QUEUE TABLE ====================
@DataClassName('QueueItemEntity')
class QueueItems extends Table {
  TextColumn get id => text()();
  TextColumn get patientId => text()();
  TextColumn get status => text()();
  TextColumn get priority => text()();
  TextColumn get nurseId => text().nullable()();
  TextColumn get roomNumber => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get vitalsBp => text().nullable()();
  RealColumn get vitalsWeight => real().nullable()();
  RealColumn get vitalsTemperature => real().nullable()();
  TextColumn get vitalsNotes => text().nullable()();
  DateTimeColumn get arrivalTime => dateTime()();
  DateTimeColumn get startTime => dateTime().nullable()();
  DateTimeColumn get endTime => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ==================== CONSULTATIONS TABLE ====================
@DataClassName('ConsultationEntity')
class Consultations extends Table {
  TextColumn get id => text()();
  TextColumn get patientId => text()();
  TextColumn get queueId => text().nullable()();
  TextColumn get subjective => text().nullable()();
  TextColumn get objective => text().nullable()();
  TextColumn get assessment => text().nullable()();
  TextColumn get plan => text().nullable()();
  TextColumn get icd10Code => text().nullable()();
  TextColumn get createdBy => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ==================== DOCUMENTS TABLE ====================
@DataClassName('DocumentEntity')
class Documents extends Table {
  TextColumn get id => text()();
  TextColumn get patientId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get type => text()();
  TextColumn get fileType => text().nullable()();
  TextColumn get filePath => text().nullable()();
  TextColumn get fileUrl => text().nullable()();
  TextColumn get uploadedBy => text()();
  TextColumn get status => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ==================== AUDIT LOGS TABLE ====================
@DataClassName('AuditLogEntity')
class AuditLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get userId => text()();
  TextColumn get action => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get oldValues => text().nullable()();
  TextColumn get newValues => text().nullable()();
  DateTimeColumn get timestamp => dateTime()();
}

// ==================== SETTINGS TABLE ====================
@DataClassName('SettingEntity')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

// ==================== SYNC QUEUE TABLE ====================
@DataClassName('SyncQueueEntity')
class SyncQueueItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityTable => text()();
  TextColumn get recordId => text()();
  TextColumn get operation => text()();
  TextColumn get data => text()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  TextColumn get error => text().nullable()();
}

// ==================== MEDICAL SNIPPETS TABLE ====================
@DataClassName('MedicalSnippetEntity')
class MedicalSnippets extends Table {
  TextColumn get id => text()();
  TextColumn get shortcut => text()();
  TextColumn get title => text()();
  TextColumn get content => text()();
  TextColumn get category => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ==================== DRIFT DATABASE ====================
@DriftDatabase(
  tables: [
    Users,
    Patients,
    QueueItems,
    Consultations,
    Documents,
    AuditLogs,
    Settings,
    SyncQueueItems,
    MedicalSnippets,
  ],
)
class MedSentryDatabase extends _$MedSentryDatabase {
  MedSentryDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'medsentry_database');
  }
}
