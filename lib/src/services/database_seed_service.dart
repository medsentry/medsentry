import 'dart:convert';

import '../config/seed_credentials.dart';
import '../database/simple_database.dart';
import '../models/generated_report.dart';
import '../models/models.dart';
import '../utils/password_crypto.dart';
import 'seed/seed_exporter.dart';

/// Seeds a full synthetic MedSentry database for development and demos.
/// Passwords are stored as PBKDF2 hashes only — never plaintext.
class DatabaseSeedService {
  static const bool _allowSeed = bool.fromEnvironment(
    'MEDSENTRY_SEED_DATABASE',
    defaultValue: false,
  );

  final SimpleDatabase _db;

  DatabaseSeedService(this._db);

  bool get isSeedAllowed => _allowSeed;

  Future<bool> isDatabaseEmpty() async {
    final patients = await _db.getAllPatients(includeArchived: true);
    return patients.isEmpty;
  }

  /// Seeds users, patients, queue, consultations, and related records when empty.
  Future<bool> seedIfEmpty({bool force = false}) async {
    if (!_allowSeed && !force) return false;
    if (!force && !await isDatabaseEmpty()) return false;

    final snapshot = buildSeedSnapshot();
    await _db.importSeedSnapshot(snapshot);
    return true;
  }

  /// Builds the complete seed snapshot (safe to serialize — no plaintext passwords).
  Map<String, dynamic> buildSeedSnapshot() {
    if (SeedCredentials.defaultPassword.length < 12) {
      throw StateError(
        'MEDSENTRY_SEED_PASSWORD must be set to a strong development-only password',
      );
    }

    final now = DateTime.now();
    final seedTime = DateTime(now.year, now.month, now.day, 8, 0);
    final passwordHashes = <String, String>{};

    final users = SeedCredentials.accounts.map((account) {
      passwordHashes[account.id] = PasswordCrypto.hashDeterministic(
        SeedCredentials.defaultPassword,
        'pwd:${account.id}',
      );
      return User(
        id: account.id,
        email: account.email,
        firstName: account.firstName,
        lastName: account.lastName,
        role: account.role,
        licenseNumber: account.licenseNumber,
        specialization: account.specialization,
        contactNumber: account.contactNumber,
        isActive: true,
        pinEnabled: false,
        pinHash: null,
        createdAt: seedTime,
        updatedAt: seedTime,
        syncStatus: 0,
      );
    }).toList();

    final patients = _buildPatients(seedTime);
    final queueItems = _buildQueueItems(seedTime, patients, users);
    final consultations = _buildConsultations(
      seedTime,
      patients,
      queueItems,
      users,
    );
    final prescriptions = _buildPrescriptions(seedTime, consultations);
    final labOrders = _buildLabOrders(seedTime, consultations);
    final documents = _buildDocuments(seedTime, patients, consultations, users);
    final auditLogs = _buildAuditLogs(seedTime, users, patients);
    final notifications = _buildNotifications(seedTime);
    final reports = _buildReports(seedTime);

    return {
      'version': 1,
      'patients': patients.map((e) => e.toJson()).toList(),
      'users': users.map((e) => e.toJson()).toList(),
      'queue_items': queueItems.map((e) => e.toJson()).toList(),
      'consultations': consultations.map((e) => e.toJson()).toList(),
      'prescriptions': prescriptions.map((e) => e.toJson()).toList(),
      'lab_orders': labOrders.map((e) => e.toJson()).toList(),
      'documents': documents.map((e) => e.toJson()).toList(),
      'audit_logs': auditLogs.map((e) => e.toJson()).toList(),
      'generated_reports': reports.map((e) => e.toJson()).toList(),
      'user_password_hashes': passwordHashes,
      'last_user_id': SeedCredentials.accounts.first.id,
      'system_settings': const SystemSettings(
        clinicName: 'MedSentry Demo RHU',
        clinicAddress: 'Poblacion, Sample Municipality, Demo Province',
        clinicContact: '(02) 8123-4567',
        patientIdPrefix: 'RHU',
        patientIdSequence: 11,
        passwordMinLength: 8,
        requireStrongPassword: true,
        sessionTimeoutMinutes: 480,
        autoSyncEnabled: false,
        dataRetentionDays: 365,
      ).toJson(),
      'notifications': notifications.map((e) => e.toJson()).toList(),
    };
  }

  Future<dynamic> exportSeedToFile(String outputPath) async {
    final snapshot = buildSeedSnapshot();
    const encoder = JsonEncoder.withIndent('  ');
    final content = encoder.convert(snapshot);
    final exporter = createSeedExporter();
    return await exporter.exportToFile(outputPath, content);
  }

  List<Patient> _buildPatients(DateTime seedTime) {
    return [
      _patient(
        id: 'p0000001-0001-4001-8001-000000000001',
        firstName: 'Pedro',
        lastName: 'Mendoza',
        middleName: 'L.',
        dob: DateTime(1985, 3, 15),
        gender: 'Male',
        barangay: 'Poblacion',
        contact: '09181111001',
        philHealth: '12-345678901-2',
        category: PatientCategory.adult,
        bloodType: 'O+',
        allergies: 'Penicillin',
        seedTime: seedTime,
      ),
      _patient(
        id: 'p0000002-0002-4002-8002-000000000002',
        firstName: 'Liza',
        lastName: 'Fernandez',
        middleName: 'M.',
        dob: DateTime(1992, 7, 22),
        gender: 'Female',
        barangay: 'San Roque',
        contact: '09181111002',
        philHealth: '12-345678902-0',
        category: PatientCategory.pregnant,
        bloodType: 'A+',
        seedTime: seedTime,
      ),
      _patient(
        id: 'p0000003-0003-4003-8003-000000000003',
        firstName: 'Miguel',
        lastName: 'Torres',
        dob: DateTime(1958, 11, 5),
        gender: 'Male',
        barangay: 'Sta. Cruz',
        contact: '09181111003',
        philHealth: '12-345678903-8',
        category: PatientCategory.seniorCitizen,
        bloodType: 'B+',
        medicalHistory: 'Hypertension, Type 2 Diabetes',
        seedTime: seedTime,
      ),
      _patient(
        id: 'p0000004-0004-4004-8004-000000000004',
        firstName: 'Sofia',
        lastName: 'Ramos',
        dob: DateTime(2023, 1, 10),
        gender: 'Female',
        barangay: 'Poblacion',
        contact: '09181111004',
        category: PatientCategory.infant,
        seedTime: seedTime,
      ),
      _patient(
        id: 'p0000005-0005-4005-8005-000000000005',
        firstName: 'Carlos',
        lastName: 'Bautista',
        dob: DateTime(2010, 6, 18),
        gender: 'Male',
        barangay: 'San Jose',
        contact: '09181111005',
        category: PatientCategory.schoolAge,
        seedTime: seedTime,
      ),
      _patient(
        id: 'p0000006-0006-4006-8006-000000000006',
        firstName: 'Elena',
        lastName: 'Castillo',
        dob: DateTime(1975, 9, 30),
        gender: 'Female',
        barangay: 'San Miguel',
        contact: '09181111006',
        philHealth: '12-345678906-2',
        category: PatientCategory.pwd,
        isPwd: true,
        seedTime: seedTime,
      ),
      _patient(
        id: 'p0000007-0007-4007-8007-000000000007',
        firstName: 'Ramon',
        lastName: 'Villanueva',
        dob: DateTime(2000, 4, 12),
        gender: 'Male',
        barangay: 'Poblacion',
        contact: '09181111007',
        category: PatientCategory.adult,
        seedTime: seedTime,
      ),
      _patient(
        id: 'p0000008-0008-4008-8008-000000000008',
        firstName: 'Teresa',
        lastName: 'Aquino',
        dob: DateTime(1968, 12, 25),
        gender: 'Female',
        barangay: 'Sta. Maria',
        contact: '09181111008',
        philHealth: '12-345678908-8',
        category: PatientCategory.adult,
        seedTime: seedTime,
        isArchived: true,
        archivedAt: seedTime.subtract(const Duration(days: 30)),
      ),
    ];
  }

  Patient _patient({
    required String id,
    required String firstName,
    required String lastName,
    String? middleName,
    required DateTime dob,
    required String gender,
    required String barangay,
    required String contact,
    String? philHealth,
    required PatientCategory category,
    String? bloodType,
    String? allergies,
    String? medicalHistory,
    required DateTime seedTime,
    bool isPwd = false,
    bool isArchived = false,
    DateTime? archivedAt,
  }) {
    return Patient(
      id: id,
      firstName: firstName,
      lastName: lastName,
      middleName: middleName,
      dateOfBirth: dob,
      gender: gender,
      civilStatus: 'Single',
      contactNumber: contact,
      address: '123 Sample Street',
      barangay: barangay,
      purokSitio: 'Purok 1',
      city: 'Sample City',
      province: 'Demo Province',
      zipCode: '1000',
      philHealthNumber: philHealth,
      philHealthCategory: philHealth != null
          ? PhilHealthCategory.indigent
          : null,
      emergencyContactName: 'Emergency Contact',
      emergencyContactNumber: '09189999000',
      emergencyContactRelation: 'Spouse',
      occupation: 'Farmer',
      waterSource: WaterSourceLevel.level2,
      toiletFacility: ToiletFacilityType.waterSealed,
      bloodType: bloodType,
      height: gender == 'Female' ? 160.0 : 170.0,
      weight: 65.0,
      allergies: allergies,
      medicalHistory: medicalHistory,
      isPwd: isPwd,
      category: category,
      isArchived: isArchived,
      archivedAt: archivedAt,
      createdAt: seedTime,
      updatedAt: seedTime,
      lastVisitDate: isArchived ? null : seedTime,
      syncStatus: 0,
    );
  }

  List<QueueItem> _buildQueueItems(
    DateTime seedTime,
    List<Patient> patients,
    List<User> users,
  ) {
    final nurse = users.firstWhere((u) => u.email == 'nurse@gmail.com');
    final doctor = users.firstWhere((u) => u.email == 'doctor@gmail.com');

    return [
      QueueItem(
        id: 'q0000001-0001-4001-8001-000000000001',
        patientId: patients[0].id,
        patientName: patients[0].fullName,
        arrivalTime: seedTime.add(const Duration(minutes: 15)),
        status: QueueStatus.waiting,
        nurseId: nurse.id,
        complaint: 'Fever and cough for 3 days',
        purpose: 'General Consultation',
        temperature: 38.2,
        bloodPressureSystolic: 120,
        bloodPressureDiastolic: 80,
        heartRate: 88,
        respiratoryRate: 20,
        oxygenSaturation: 97,
        priority: Priority.normal,
        createdAt: seedTime,
        updatedAt: seedTime,
      ),
      QueueItem(
        id: 'q0000002-0002-4002-8002-000000000002',
        patientId: patients[1].id,
        patientName: patients[1].fullName,
        isPregnant: true,
        arrivalTime: seedTime.add(const Duration(minutes: 30)),
        startTime: seedTime.add(const Duration(minutes: 45)),
        status: QueueStatus.inProgress,
        nurseId: nurse.id,
        doctorId: doctor.id,
        complaint: 'Prenatal checkup - 28 weeks',
        purpose: 'Prenatal',
        temperature: 36.8,
        bloodPressureSystolic: 110,
        bloodPressureDiastolic: 70,
        heartRate: 78,
        priority: Priority.normal,
        roomNumber: 'Consultation 1',
        createdAt: seedTime,
        updatedAt: seedTime,
      ),
      QueueItem(
        id: 'q0000003-0003-4003-8003-000000000003',
        patientId: patients[2].id,
        patientName: patients[2].fullName,
        isSenior: true,
        arrivalTime: seedTime.subtract(const Duration(hours: 1)),
        startTime: seedTime.subtract(const Duration(minutes: 45)),
        endTime: seedTime.subtract(const Duration(minutes: 15)),
        status: QueueStatus.completed,
        nurseId: nurse.id,
        doctorId: doctor.id,
        complaint: 'Follow-up for hypertension',
        purpose: 'General Consultation',
        temperature: 36.5,
        bloodPressureSystolic: 145,
        bloodPressureDiastolic: 92,
        heartRate: 72,
        priority: Priority.high,
        createdAt: seedTime,
        updatedAt: seedTime,
      ),
      QueueItem(
        id: 'q0000004-0004-4004-8004-000000000004',
        patientId: patients[6].id,
        patientName: patients[6].fullName,
        arrivalTime: seedTime.add(const Duration(minutes: 5)),
        status: QueueStatus.waiting,
        complaint: 'Skin rash on arms',
        purpose: 'General Consultation',
        redFlags: const [],
        painScale: 3,
        priority: Priority.low,
        createdAt: seedTime,
        updatedAt: seedTime,
      ),
    ];
  }

  List<Consultation> _buildConsultations(
    DateTime seedTime,
    List<Patient> patients,
    List<QueueItem> queueItems,
    List<User> users,
  ) {
    final doctor = users.firstWhere((u) => u.email == 'doctor@gmail.com');

    return [
      Consultation(
        id: 'c0000001-0001-4001-8001-000000000001',
        patientId: patients[2].id,
        queueId: queueItems[2].id,
        doctorId: doctor.id,
        consultationDate: seedTime.subtract(const Duration(minutes: 30)),
        subjective:
            'Patient reports persistent headache and elevated BP readings at home.',
        objective: 'BP 145/92, alert and oriented, no edema.',
        assessment: 'Uncontrolled hypertension',
        plan:
            'Continue Amlodipine 5mg OD, lifestyle counseling, follow-up in 2 weeks.',
        icd10Code: 'I10',
        icd10Description: 'Essential (primary) hypertension',
        createdBy: doctor.id,
        createdAt: seedTime,
        updatedAt: seedTime,
        syncStatus: 0,
      ),
      Consultation(
        id: 'c0000002-0002-4002-8002-000000000002',
        patientId: patients[1].id,
        queueId: queueItems[1].id,
        doctorId: doctor.id,
        consultationDate: seedTime,
        subjective: '28 weeks pregnant, no complaints, regular fetal movement.',
        objective: 'Fundal height 28cm, FHT 140 bpm, no contractions.',
        assessment: 'Normal prenatal visit at 28 weeks',
        plan:
            'Iron supplementation, return in 2 weeks for next prenatal visit.',
        icd10Code: 'Z34.8',
        icd10Description: 'Encounter for supervision of other normal pregnancy',
        createdBy: doctor.id,
        createdAt: seedTime,
        updatedAt: seedTime,
        syncStatus: 0,
      ),
      Consultation(
        id: 'c0000003-0003-4003-8003-000000000003',
        patientId: patients[0].id,
        queueId: queueItems[0].id,
        doctorId: doctor.id,
        consultationDate: seedTime.add(const Duration(hours: 1)),
        subjective: 'Fever, productive cough, body malaise x 3 days.',
        objective: 'Temp 38.2C, clear breath sounds, no wheezing.',
        assessment: 'Acute upper respiratory tract infection',
        plan: 'Paracetamol PRN, increased fluids, return if symptoms worsen.',
        icd10Code: 'J06.9',
        icd10Description: 'Acute upper respiratory infection, unspecified',
        createdBy: doctor.id,
        createdAt: seedTime,
        updatedAt: seedTime,
        syncStatus: 0,
      ),
    ];
  }

  List<Prescription> _buildPrescriptions(
    DateTime seedTime,
    List<Consultation> consultations,
  ) {
    return [
      Prescription(
        id: 'rx000001-0001-4001-8001-000000000001',
        consultationId: consultations[0].id,
        medicationName: 'Amlodipine',
        genericName: 'Amlodipine Besylate',
        dosage: '5mg',
        frequency: 'Once daily',
        duration: '30 days',
        quantity: 30,
        instructions: 'Take in the morning',
        createdAt: seedTime,
        syncStatus: 0,
      ),
      Prescription(
        id: 'rx000002-0002-4002-8002-000000000002',
        consultationId: consultations[1].id,
        medicationName: 'Ferrous Sulfate',
        genericName: 'Ferrous Sulfate',
        dosage: '325mg',
        frequency: 'Once daily',
        duration: '30 days',
        quantity: 30,
        instructions: 'Take after meals',
        createdAt: seedTime,
        syncStatus: 0,
      ),
      Prescription(
        id: 'rx000003-0003-4003-8003-000000000003',
        consultationId: consultations[2].id,
        medicationName: 'Paracetamol',
        genericName: 'Acetaminophen',
        dosage: '500mg',
        frequency: 'Every 6 hours as needed',
        duration: '5 days',
        quantity: 20,
        instructions: 'For fever, max 4g per day',
        createdAt: seedTime,
        syncStatus: 0,
      ),
    ];
  }

  List<LabOrder> _buildLabOrders(
    DateTime seedTime,
    List<Consultation> consultations,
  ) {
    return [
      LabOrder(
        id: 'lab00001-0001-4001-8001-000000000001',
        consultationId: consultations[0].id,
        testName: 'Fasting Blood Sugar',
        testCode: 'FBS',
        status: 'completed',
        requestedDate: seedTime,
        completedDate: seedTime.add(const Duration(hours: 2)),
        results: '126 mg/dL',
        createdAt: seedTime,
        syncStatus: 0,
      ),
      LabOrder(
        id: 'lab00002-0002-4002-8002-000000000002',
        consultationId: consultations[1].id,
        testName: 'Urinalysis',
        testCode: 'UA',
        status: 'pending',
        requestedDate: seedTime,
        createdAt: seedTime,
        syncStatus: 0,
      ),
    ];
  }

  List<MedicalDocument> _buildDocuments(
    DateTime seedTime,
    List<Patient> patients,
    List<Consultation> consultations,
    List<User> users,
  ) {
    final nurse = users.firstWhere((u) => u.email == 'nurse@gmail.com');

    return [
      MedicalDocument(
        id: 'd0000001-0001-4001-8001-000000000001',
        patientId: patients[2].id,
        consultationId: consultations[0].id,
        type: DocumentType.labResult,
        title: 'FBS Result - Miguel Torres',
        filePath: 'documents/sample_fbs_result.pdf',
        fileSize: 102400,
        mimeType: 'application/pdf',
        scannedBy: nurse.id,
        scanDate: seedTime,
        status: DocumentStatus.verified,
        verifiedBy: nurse.id,
        verifiedDate: seedTime,
        createdAt: seedTime,
        updatedAt: seedTime,
        syncStatus: 0,
      ),
      MedicalDocument(
        id: 'd0000002-0002-4002-8002-000000000002',
        patientId: patients[1].id,
        consultationId: consultations[1].id,
        type: DocumentType.medicalCertificate,
        title: 'Prenatal Visit Certificate',
        filePath: 'documents/sample_prenatal_cert.pdf',
        fileSize: 51200,
        mimeType: 'application/pdf',
        scannedBy: nurse.id,
        scanDate: seedTime,
        status: DocumentStatus.pending,
        createdAt: seedTime,
        updatedAt: seedTime,
        syncStatus: 0,
      ),
    ];
  }

  List<AuditLog> _buildAuditLogs(
    DateTime seedTime,
    List<User> users,
    List<Patient> patients,
  ) {
    final admin = users.firstWhere((u) => u.email == 'admin@gmail.com');

    return [
      AuditLog(
        id: 'audit0001-0001-4001-8001-000000000001',
        userId: admin.id,
        userName: admin.fullName,
        userRole: admin.role.name,
        action: AuditAction.create,
        entityType: 'patient',
        entityId: patients[0].id,
        patientId: patients[0].id,
        patientName: patients[0].fullName,
        description: 'Registered patient: ${patients[0].fullName}',
        timestamp: seedTime.subtract(const Duration(hours: 2)),
      ),
      AuditLog(
        id: 'audit0002-0002-4002-8002-000000000002',
        userId: admin.id,
        userName: admin.fullName,
        userRole: admin.role.name,
        action: AuditAction.login,
        entityType: 'user',
        entityId: admin.id,
        description: 'User logged in locally: admin@gmail.com',
        timestamp: seedTime.subtract(const Duration(hours: 3)),
      ),
      AuditLog(
        id: 'audit0003-0003-4003-8003-000000000003',
        userId: users[2].id,
        userName: users[2].fullName,
        userRole: users[2].role.name,
        action: AuditAction.create,
        entityType: 'consultation',
        entityId: 'c0000001-0001-4001-8001-000000000001',
        patientId: patients[2].id,
        patientName: patients[2].fullName,
        description: 'Created consultation for ${patients[2].fullName}',
        timestamp: seedTime,
      ),
    ];
  }

  List<SystemNotification> _buildNotifications(DateTime seedTime) {
    return [
      SystemNotification(
        id: 'n0000001-0001-4001-8001-000000000001',
        type: NotificationType.queueAlert,
        target: NotificationTarget.staff,
        priority: NotificationPriority.normal,
        title: 'Patients in Queue',
        message: '3 patients waiting for consultation.',
        actionRoute: '/queue',
        createdAt: seedTime,
      ),
      SystemNotification(
        id: 'n0000002-0002-4002-8002-000000000002',
        type: NotificationType.pendingDocument,
        target: NotificationTarget.all,
        priority: NotificationPriority.low,
        title: 'Pending Document Verification',
        message: '1 medical certificate awaiting verification.',
        actionRoute: '/documents',
        createdAt: seedTime,
      ),
    ];
  }

  List<GeneratedReport> _buildReports(DateTime seedTime) {
    return [
      GeneratedReport(
        id: 'r0000001-0001-4001-8001-000000000001',
        title: 'Daily Patient Summary',
        type: 'daily_summary',
        generatedAt: seedTime,
        startDate: seedTime,
        endDate: seedTime,
        filePath: 'reports/daily_summary_sample.pdf',
      ),
    ];
  }
}
