// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$driftDatabaseHash() => r'f984d73dae1c353030a522e6c99b9fe95be7a3dc';

/// See also [driftDatabase].
@ProviderFor(driftDatabase)
final driftDatabaseProvider = Provider<MedSentryDatabase>.internal(
  driftDatabase,
  name: r'driftDatabaseProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$driftDatabaseHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef DriftDatabaseRef = ProviderRef<MedSentryDatabase>;
String _$databaseHash() => r'1c45c031f878333923e84f371a22efa605224660';

/// See also [database].
@ProviderFor(database)
final databaseProvider = Provider<SimpleDatabase>.internal(
  database,
  name: r'databaseProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$databaseHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef DatabaseRef = ProviderRef<SimpleDatabase>;
String _$auditServiceHash() => r'93f2c334a9a6194d8b63e4e607981a0ca5459812';

/// See also [auditService].
@ProviderFor(auditService)
final auditServiceProvider = Provider<AuditService>.internal(
  auditService,
  name: r'auditServiceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$auditServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef AuditServiceRef = ProviderRef<AuditService>;
String _$authRepositoryHash() => r'eb99f2a1b1aa0a40d995e7bb00878f69f81cd40e';

/// See also [authRepository].
@ProviderFor(authRepository)
final authRepositoryProvider = Provider<AuthRepository>.internal(
  authRepository,
  name: r'authRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$authRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef AuthRepositoryRef = ProviderRef<AuthRepository>;
String _$patientRepositoryHash() => r'be7f3bb4290284132965aa102cef2de6f2808fc5';

/// See also [patientRepository].
@ProviderFor(patientRepository)
final patientRepositoryProvider = Provider<PatientRepository>.internal(
  patientRepository,
  name: r'patientRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$patientRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef PatientRepositoryRef = ProviderRef<PatientRepository>;
String _$consultationRepositoryHash() =>
    r'78082f782ce194f7253a7cb20b999caa762b9d63';

/// See also [consultationRepository].
@ProviderFor(consultationRepository)
final consultationRepositoryProvider =
    Provider<ConsultationRepository>.internal(
  consultationRepository,
  name: r'consultationRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$consultationRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ConsultationRepositoryRef = ProviderRef<ConsultationRepository>;
String _$queueRepositoryHash() => r'969f5eccb3dcece0045bdd4453ca00350b059594';

/// See also [queueRepository].
@ProviderFor(queueRepository)
final queueRepositoryProvider = Provider<QueueRepository>.internal(
  queueRepository,
  name: r'queueRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$queueRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef QueueRepositoryRef = ProviderRef<QueueRepository>;
String _$usersHash() => r'a721c94ff33b1f6e556e6c68c13e68474cd3e11d';

/// See also [users].
@ProviderFor(users)
final usersProvider = FutureProvider<List<User>>.internal(
  users,
  name: r'usersProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$usersHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef UsersRef = FutureProviderRef<List<User>>;
String _$patientsHash() => r'a8d1ca48c08b2ce424b35d89ce2ac8f008a3806d';

/// See also [patients].
@ProviderFor(patients)
final patientsProvider = FutureProvider<List<Patient>>.internal(
  patients,
  name: r'patientsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$patientsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef PatientsRef = FutureProviderRef<List<Patient>>;
String _$patientHash() => r'9df53fe4ca0c94c87d4cf02e2e185446f6a3058d';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [patient].
@ProviderFor(patient)
const patientProvider = PatientFamily();

/// See also [patient].
class PatientFamily extends Family<AsyncValue<Patient?>> {
  /// See also [patient].
  const PatientFamily();

  /// See also [patient].
  PatientProvider call(
    String patientId,
  ) {
    return PatientProvider(
      patientId,
    );
  }

  @override
  PatientProvider getProviderOverride(
    covariant PatientProvider provider,
  ) {
    return call(
      provider.patientId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'patientProvider';
}

/// See also [patient].
class PatientProvider extends FutureProvider<Patient?> {
  /// See also [patient].
  PatientProvider(
    String patientId,
  ) : this._internal(
          (ref) => patient(
            ref as PatientRef,
            patientId,
          ),
          from: patientProvider,
          name: r'patientProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$patientHash,
          dependencies: PatientFamily._dependencies,
          allTransitiveDependencies: PatientFamily._allTransitiveDependencies,
          patientId: patientId,
        );

  PatientProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.patientId,
  }) : super.internal();

  final String patientId;

  @override
  Override overrideWith(
    FutureOr<Patient?> Function(PatientRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PatientProvider._internal(
        (ref) => create(ref as PatientRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        patientId: patientId,
      ),
    );
  }

  @override
  FutureProviderElement<Patient?> createElement() {
    return _PatientProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PatientProvider && other.patientId == patientId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, patientId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin PatientRef on FutureProviderRef<Patient?> {
  /// The parameter `patientId` of this provider.
  String get patientId;
}

class _PatientProviderElement extends FutureProviderElement<Patient?>
    with PatientRef {
  _PatientProviderElement(super.provider);

  @override
  String get patientId => (origin as PatientProvider).patientId;
}

String _$queueHash() => r'1678b9e564926ebcac1bd899c5604d78d1560363';

/// See also [queue].
@ProviderFor(queue)
final queueProvider = FutureProvider<List<QueueItem>>.internal(
  queue,
  name: r'queueProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$queueHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef QueueRef = FutureProviderRef<List<QueueItem>>;
String _$queueItemHash() => r'b8f2ccf819c16ed91744a3da4634d3331103df95';

/// See also [queueItem].
@ProviderFor(queueItem)
const queueItemProvider = QueueItemFamily();

/// See also [queueItem].
class QueueItemFamily extends Family<AsyncValue<QueueItem?>> {
  /// See also [queueItem].
  const QueueItemFamily();

  /// See also [queueItem].
  QueueItemProvider call(
    String queueItemId,
  ) {
    return QueueItemProvider(
      queueItemId,
    );
  }

  @override
  QueueItemProvider getProviderOverride(
    covariant QueueItemProvider provider,
  ) {
    return call(
      provider.queueItemId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'queueItemProvider';
}

/// See also [queueItem].
class QueueItemProvider extends FutureProvider<QueueItem?> {
  /// See also [queueItem].
  QueueItemProvider(
    String queueItemId,
  ) : this._internal(
          (ref) => queueItem(
            ref as QueueItemRef,
            queueItemId,
          ),
          from: queueItemProvider,
          name: r'queueItemProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$queueItemHash,
          dependencies: QueueItemFamily._dependencies,
          allTransitiveDependencies: QueueItemFamily._allTransitiveDependencies,
          queueItemId: queueItemId,
        );

  QueueItemProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.queueItemId,
  }) : super.internal();

  final String queueItemId;

  @override
  Override overrideWith(
    FutureOr<QueueItem?> Function(QueueItemRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: QueueItemProvider._internal(
        (ref) => create(ref as QueueItemRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        queueItemId: queueItemId,
      ),
    );
  }

  @override
  FutureProviderElement<QueueItem?> createElement() {
    return _QueueItemProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is QueueItemProvider && other.queueItemId == queueItemId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, queueItemId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin QueueItemRef on FutureProviderRef<QueueItem?> {
  /// The parameter `queueItemId` of this provider.
  String get queueItemId;
}

class _QueueItemProviderElement extends FutureProviderElement<QueueItem?>
    with QueueItemRef {
  _QueueItemProviderElement(super.provider);

  @override
  String get queueItemId => (origin as QueueItemProvider).queueItemId;
}

String _$documentsHash() => r'6fa6f899a7da51eb79119f234ef856c5fec9ef24';

/// See also [documents].
@ProviderFor(documents)
final documentsProvider = FutureProvider<List<MedicalDocument>>.internal(
  documents,
  name: r'documentsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$documentsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef DocumentsRef = FutureProviderRef<List<MedicalDocument>>;
String _$patientConsultationsHash() =>
    r'9215ec05df6046e8b24034cc906ae53e10ce2ead';

/// See also [patientConsultations].
@ProviderFor(patientConsultations)
const patientConsultationsProvider = PatientConsultationsFamily();

/// See also [patientConsultations].
class PatientConsultationsFamily
    extends Family<AsyncValue<List<Consultation>>> {
  /// See also [patientConsultations].
  const PatientConsultationsFamily();

  /// See also [patientConsultations].
  PatientConsultationsProvider call(
    String patientId,
  ) {
    return PatientConsultationsProvider(
      patientId,
    );
  }

  @override
  PatientConsultationsProvider getProviderOverride(
    covariant PatientConsultationsProvider provider,
  ) {
    return call(
      provider.patientId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'patientConsultationsProvider';
}

/// See also [patientConsultations].
class PatientConsultationsProvider extends FutureProvider<List<Consultation>> {
  /// See also [patientConsultations].
  PatientConsultationsProvider(
    String patientId,
  ) : this._internal(
          (ref) => patientConsultations(
            ref as PatientConsultationsRef,
            patientId,
          ),
          from: patientConsultationsProvider,
          name: r'patientConsultationsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$patientConsultationsHash,
          dependencies: PatientConsultationsFamily._dependencies,
          allTransitiveDependencies:
              PatientConsultationsFamily._allTransitiveDependencies,
          patientId: patientId,
        );

  PatientConsultationsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.patientId,
  }) : super.internal();

  final String patientId;

  @override
  Override overrideWith(
    FutureOr<List<Consultation>> Function(PatientConsultationsRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PatientConsultationsProvider._internal(
        (ref) => create(ref as PatientConsultationsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        patientId: patientId,
      ),
    );
  }

  @override
  FutureProviderElement<List<Consultation>> createElement() {
    return _PatientConsultationsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PatientConsultationsProvider &&
        other.patientId == patientId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, patientId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin PatientConsultationsRef on FutureProviderRef<List<Consultation>> {
  /// The parameter `patientId` of this provider.
  String get patientId;
}

class _PatientConsultationsProviderElement
    extends FutureProviderElement<List<Consultation>>
    with PatientConsultationsRef {
  _PatientConsultationsProviderElement(super.provider);

  @override
  String get patientId => (origin as PatientConsultationsProvider).patientId;
}

String _$patientDocumentsHash() => r'595c1cc1c693dcd7c14fd16632a3dca77b5c0788';

/// See also [patientDocuments].
@ProviderFor(patientDocuments)
const patientDocumentsProvider = PatientDocumentsFamily();

/// See also [patientDocuments].
class PatientDocumentsFamily extends Family<AsyncValue<List<MedicalDocument>>> {
  /// See also [patientDocuments].
  const PatientDocumentsFamily();

  /// See also [patientDocuments].
  PatientDocumentsProvider call(
    String patientId,
  ) {
    return PatientDocumentsProvider(
      patientId,
    );
  }

  @override
  PatientDocumentsProvider getProviderOverride(
    covariant PatientDocumentsProvider provider,
  ) {
    return call(
      provider.patientId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'patientDocumentsProvider';
}

/// See also [patientDocuments].
class PatientDocumentsProvider extends FutureProvider<List<MedicalDocument>> {
  /// See also [patientDocuments].
  PatientDocumentsProvider(
    String patientId,
  ) : this._internal(
          (ref) => patientDocuments(
            ref as PatientDocumentsRef,
            patientId,
          ),
          from: patientDocumentsProvider,
          name: r'patientDocumentsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$patientDocumentsHash,
          dependencies: PatientDocumentsFamily._dependencies,
          allTransitiveDependencies:
              PatientDocumentsFamily._allTransitiveDependencies,
          patientId: patientId,
        );

  PatientDocumentsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.patientId,
  }) : super.internal();

  final String patientId;

  @override
  Override overrideWith(
    FutureOr<List<MedicalDocument>> Function(PatientDocumentsRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PatientDocumentsProvider._internal(
        (ref) => create(ref as PatientDocumentsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        patientId: patientId,
      ),
    );
  }

  @override
  FutureProviderElement<List<MedicalDocument>> createElement() {
    return _PatientDocumentsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PatientDocumentsProvider && other.patientId == patientId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, patientId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin PatientDocumentsRef on FutureProviderRef<List<MedicalDocument>> {
  /// The parameter `patientId` of this provider.
  String get patientId;
}

class _PatientDocumentsProviderElement
    extends FutureProviderElement<List<MedicalDocument>>
    with PatientDocumentsRef {
  _PatientDocumentsProviderElement(super.provider);

  @override
  String get patientId => (origin as PatientDocumentsProvider).patientId;
}

String _$patientQueueHistoryHash() =>
    r'c8b043b2eff026ee8e1c5594d03d89746ae25a05';

/// See also [patientQueueHistory].
@ProviderFor(patientQueueHistory)
const patientQueueHistoryProvider = PatientQueueHistoryFamily();

/// See also [patientQueueHistory].
class PatientQueueHistoryFamily extends Family<AsyncValue<List<QueueItem>>> {
  /// See also [patientQueueHistory].
  const PatientQueueHistoryFamily();

  /// See also [patientQueueHistory].
  PatientQueueHistoryProvider call(
    String patientId,
  ) {
    return PatientQueueHistoryProvider(
      patientId,
    );
  }

  @override
  PatientQueueHistoryProvider getProviderOverride(
    covariant PatientQueueHistoryProvider provider,
  ) {
    return call(
      provider.patientId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'patientQueueHistoryProvider';
}

/// See also [patientQueueHistory].
class PatientQueueHistoryProvider extends FutureProvider<List<QueueItem>> {
  /// See also [patientQueueHistory].
  PatientQueueHistoryProvider(
    String patientId,
  ) : this._internal(
          (ref) => patientQueueHistory(
            ref as PatientQueueHistoryRef,
            patientId,
          ),
          from: patientQueueHistoryProvider,
          name: r'patientQueueHistoryProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$patientQueueHistoryHash,
          dependencies: PatientQueueHistoryFamily._dependencies,
          allTransitiveDependencies:
              PatientQueueHistoryFamily._allTransitiveDependencies,
          patientId: patientId,
        );

  PatientQueueHistoryProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.patientId,
  }) : super.internal();

  final String patientId;

  @override
  Override overrideWith(
    FutureOr<List<QueueItem>> Function(PatientQueueHistoryRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PatientQueueHistoryProvider._internal(
        (ref) => create(ref as PatientQueueHistoryRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        patientId: patientId,
      ),
    );
  }

  @override
  FutureProviderElement<List<QueueItem>> createElement() {
    return _PatientQueueHistoryProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PatientQueueHistoryProvider && other.patientId == patientId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, patientId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin PatientQueueHistoryRef on FutureProviderRef<List<QueueItem>> {
  /// The parameter `patientId` of this provider.
  String get patientId;
}

class _PatientQueueHistoryProviderElement
    extends FutureProviderElement<List<QueueItem>> with PatientQueueHistoryRef {
  _PatientQueueHistoryProviderElement(super.provider);

  @override
  String get patientId => (origin as PatientQueueHistoryProvider).patientId;
}

String _$patientAuditLogsHash() => r'aac5182b26117f15f1f911c699ddc6e9360f3f90';

/// See also [patientAuditLogs].
@ProviderFor(patientAuditLogs)
const patientAuditLogsProvider = PatientAuditLogsFamily();

/// See also [patientAuditLogs].
class PatientAuditLogsFamily extends Family<AsyncValue<List<AuditLog>>> {
  /// See also [patientAuditLogs].
  const PatientAuditLogsFamily();

  /// See also [patientAuditLogs].
  PatientAuditLogsProvider call(
    String patientId,
  ) {
    return PatientAuditLogsProvider(
      patientId,
    );
  }

  @override
  PatientAuditLogsProvider getProviderOverride(
    covariant PatientAuditLogsProvider provider,
  ) {
    return call(
      provider.patientId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'patientAuditLogsProvider';
}

/// See also [patientAuditLogs].
class PatientAuditLogsProvider extends FutureProvider<List<AuditLog>> {
  /// See also [patientAuditLogs].
  PatientAuditLogsProvider(
    String patientId,
  ) : this._internal(
          (ref) => patientAuditLogs(
            ref as PatientAuditLogsRef,
            patientId,
          ),
          from: patientAuditLogsProvider,
          name: r'patientAuditLogsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$patientAuditLogsHash,
          dependencies: PatientAuditLogsFamily._dependencies,
          allTransitiveDependencies:
              PatientAuditLogsFamily._allTransitiveDependencies,
          patientId: patientId,
        );

  PatientAuditLogsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.patientId,
  }) : super.internal();

  final String patientId;

  @override
  Override overrideWith(
    FutureOr<List<AuditLog>> Function(PatientAuditLogsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PatientAuditLogsProvider._internal(
        (ref) => create(ref as PatientAuditLogsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        patientId: patientId,
      ),
    );
  }

  @override
  FutureProviderElement<List<AuditLog>> createElement() {
    return _PatientAuditLogsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PatientAuditLogsProvider && other.patientId == patientId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, patientId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin PatientAuditLogsRef on FutureProviderRef<List<AuditLog>> {
  /// The parameter `patientId` of this provider.
  String get patientId;
}

class _PatientAuditLogsProviderElement
    extends FutureProviderElement<List<AuditLog>> with PatientAuditLogsRef {
  _PatientAuditLogsProviderElement(super.provider);

  @override
  String get patientId => (origin as PatientAuditLogsProvider).patientId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
