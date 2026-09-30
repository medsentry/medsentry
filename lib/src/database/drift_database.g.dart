// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drift_database.dart';

// ignore_for_file: type=lint
class $UsersTable extends Users with TableInfo<$UsersTable, UserEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
      'email', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _firstNameMeta =
      const VerificationMeta('firstName');
  @override
  late final GeneratedColumn<String> firstName = GeneratedColumn<String>(
      'first_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastNameMeta =
      const VerificationMeta('lastName');
  @override
  late final GeneratedColumn<String> lastName = GeneratedColumn<String>(
      'last_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
      'role', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _licenseNumberMeta =
      const VerificationMeta('licenseNumber');
  @override
  late final GeneratedColumn<String> licenseNumber = GeneratedColumn<String>(
      'license_number', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _specializationMeta =
      const VerificationMeta('specialization');
  @override
  late final GeneratedColumn<String> specialization = GeneratedColumn<String>(
      'specialization', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _contactNumberMeta =
      const VerificationMeta('contactNumber');
  @override
  late final GeneratedColumn<String> contactNumber = GeneratedColumn<String>(
      'contact_number', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'));
  static const VerificationMeta _pinEnabledMeta =
      const VerificationMeta('pinEnabled');
  @override
  late final GeneratedColumn<bool> pinEnabled = GeneratedColumn<bool>(
      'pin_enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("pin_enabled" IN (0, 1))'));
  static const VerificationMeta _pinHashMeta =
      const VerificationMeta('pinHash');
  @override
  late final GeneratedColumn<String> pinHash = GeneratedColumn<String>(
      'pin_hash', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _passwordHashMeta =
      const VerificationMeta('passwordHash');
  @override
  late final GeneratedColumn<String> passwordHash = GeneratedColumn<String>(
      'password_hash', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        email,
        firstName,
        lastName,
        role,
        licenseNumber,
        specialization,
        contactNumber,
        isActive,
        pinEnabled,
        pinHash,
        passwordHash,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(Insertable<UserEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
          _emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('first_name')) {
      context.handle(_firstNameMeta,
          firstName.isAcceptableOrUnknown(data['first_name']!, _firstNameMeta));
    } else if (isInserting) {
      context.missing(_firstNameMeta);
    }
    if (data.containsKey('last_name')) {
      context.handle(_lastNameMeta,
          lastName.isAcceptableOrUnknown(data['last_name']!, _lastNameMeta));
    } else if (isInserting) {
      context.missing(_lastNameMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
          _roleMeta, role.isAcceptableOrUnknown(data['role']!, _roleMeta));
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('license_number')) {
      context.handle(
          _licenseNumberMeta,
          licenseNumber.isAcceptableOrUnknown(
              data['license_number']!, _licenseNumberMeta));
    }
    if (data.containsKey('specialization')) {
      context.handle(
          _specializationMeta,
          specialization.isAcceptableOrUnknown(
              data['specialization']!, _specializationMeta));
    }
    if (data.containsKey('contact_number')) {
      context.handle(
          _contactNumberMeta,
          contactNumber.isAcceptableOrUnknown(
              data['contact_number']!, _contactNumberMeta));
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    } else if (isInserting) {
      context.missing(_isActiveMeta);
    }
    if (data.containsKey('pin_enabled')) {
      context.handle(
          _pinEnabledMeta,
          pinEnabled.isAcceptableOrUnknown(
              data['pin_enabled']!, _pinEnabledMeta));
    } else if (isInserting) {
      context.missing(_pinEnabledMeta);
    }
    if (data.containsKey('pin_hash')) {
      context.handle(_pinHashMeta,
          pinHash.isAcceptableOrUnknown(data['pin_hash']!, _pinHashMeta));
    }
    if (data.containsKey('password_hash')) {
      context.handle(
          _passwordHashMeta,
          passwordHash.isAcceptableOrUnknown(
              data['password_hash']!, _passwordHashMeta));
    } else if (isInserting) {
      context.missing(_passwordHashMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      email: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email'])!,
      firstName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}first_name'])!,
      lastName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_name'])!,
      role: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}role'])!,
      licenseNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}license_number']),
      specialization: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}specialization']),
      contactNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}contact_number']),
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
      pinEnabled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}pin_enabled'])!,
      pinHash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pin_hash']),
      passwordHash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}password_hash'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $UsersTable createAlias(String alias) {
    return $UsersTable(attachedDatabase, alias);
  }
}

class UserEntity extends DataClass implements Insertable<UserEntity> {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final String? licenseNumber;
  final String? specialization;
  final String? contactNumber;
  final bool isActive;
  final bool pinEnabled;
  final String? pinHash;
  final String passwordHash;
  final DateTime createdAt;
  final DateTime updatedAt;
  const UserEntity(
      {required this.id,
      required this.email,
      required this.firstName,
      required this.lastName,
      required this.role,
      this.licenseNumber,
      this.specialization,
      this.contactNumber,
      required this.isActive,
      required this.pinEnabled,
      this.pinHash,
      required this.passwordHash,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['email'] = Variable<String>(email);
    map['first_name'] = Variable<String>(firstName);
    map['last_name'] = Variable<String>(lastName);
    map['role'] = Variable<String>(role);
    if (!nullToAbsent || licenseNumber != null) {
      map['license_number'] = Variable<String>(licenseNumber);
    }
    if (!nullToAbsent || specialization != null) {
      map['specialization'] = Variable<String>(specialization);
    }
    if (!nullToAbsent || contactNumber != null) {
      map['contact_number'] = Variable<String>(contactNumber);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['pin_enabled'] = Variable<bool>(pinEnabled);
    if (!nullToAbsent || pinHash != null) {
      map['pin_hash'] = Variable<String>(pinHash);
    }
    map['password_hash'] = Variable<String>(passwordHash);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UsersCompanion toCompanion(bool nullToAbsent) {
    return UsersCompanion(
      id: Value(id),
      email: Value(email),
      firstName: Value(firstName),
      lastName: Value(lastName),
      role: Value(role),
      licenseNumber: licenseNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(licenseNumber),
      specialization: specialization == null && nullToAbsent
          ? const Value.absent()
          : Value(specialization),
      contactNumber: contactNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(contactNumber),
      isActive: Value(isActive),
      pinEnabled: Value(pinEnabled),
      pinHash: pinHash == null && nullToAbsent
          ? const Value.absent()
          : Value(pinHash),
      passwordHash: Value(passwordHash),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserEntity(
      id: serializer.fromJson<String>(json['id']),
      email: serializer.fromJson<String>(json['email']),
      firstName: serializer.fromJson<String>(json['firstName']),
      lastName: serializer.fromJson<String>(json['lastName']),
      role: serializer.fromJson<String>(json['role']),
      licenseNumber: serializer.fromJson<String?>(json['licenseNumber']),
      specialization: serializer.fromJson<String?>(json['specialization']),
      contactNumber: serializer.fromJson<String?>(json['contactNumber']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      pinEnabled: serializer.fromJson<bool>(json['pinEnabled']),
      pinHash: serializer.fromJson<String?>(json['pinHash']),
      passwordHash: serializer.fromJson<String>(json['passwordHash']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'email': serializer.toJson<String>(email),
      'firstName': serializer.toJson<String>(firstName),
      'lastName': serializer.toJson<String>(lastName),
      'role': serializer.toJson<String>(role),
      'licenseNumber': serializer.toJson<String?>(licenseNumber),
      'specialization': serializer.toJson<String?>(specialization),
      'contactNumber': serializer.toJson<String?>(contactNumber),
      'isActive': serializer.toJson<bool>(isActive),
      'pinEnabled': serializer.toJson<bool>(pinEnabled),
      'pinHash': serializer.toJson<String?>(pinHash),
      'passwordHash': serializer.toJson<String>(passwordHash),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UserEntity copyWith(
          {String? id,
          String? email,
          String? firstName,
          String? lastName,
          String? role,
          Value<String?> licenseNumber = const Value.absent(),
          Value<String?> specialization = const Value.absent(),
          Value<String?> contactNumber = const Value.absent(),
          bool? isActive,
          bool? pinEnabled,
          Value<String?> pinHash = const Value.absent(),
          String? passwordHash,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      UserEntity(
        id: id ?? this.id,
        email: email ?? this.email,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        role: role ?? this.role,
        licenseNumber:
            licenseNumber.present ? licenseNumber.value : this.licenseNumber,
        specialization:
            specialization.present ? specialization.value : this.specialization,
        contactNumber:
            contactNumber.present ? contactNumber.value : this.contactNumber,
        isActive: isActive ?? this.isActive,
        pinEnabled: pinEnabled ?? this.pinEnabled,
        pinHash: pinHash.present ? pinHash.value : this.pinHash,
        passwordHash: passwordHash ?? this.passwordHash,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  UserEntity copyWithCompanion(UsersCompanion data) {
    return UserEntity(
      id: data.id.present ? data.id.value : this.id,
      email: data.email.present ? data.email.value : this.email,
      firstName: data.firstName.present ? data.firstName.value : this.firstName,
      lastName: data.lastName.present ? data.lastName.value : this.lastName,
      role: data.role.present ? data.role.value : this.role,
      licenseNumber: data.licenseNumber.present
          ? data.licenseNumber.value
          : this.licenseNumber,
      specialization: data.specialization.present
          ? data.specialization.value
          : this.specialization,
      contactNumber: data.contactNumber.present
          ? data.contactNumber.value
          : this.contactNumber,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      pinEnabled:
          data.pinEnabled.present ? data.pinEnabled.value : this.pinEnabled,
      pinHash: data.pinHash.present ? data.pinHash.value : this.pinHash,
      passwordHash: data.passwordHash.present
          ? data.passwordHash.value
          : this.passwordHash,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserEntity(')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('firstName: $firstName, ')
          ..write('lastName: $lastName, ')
          ..write('role: $role, ')
          ..write('licenseNumber: $licenseNumber, ')
          ..write('specialization: $specialization, ')
          ..write('contactNumber: $contactNumber, ')
          ..write('isActive: $isActive, ')
          ..write('pinEnabled: $pinEnabled, ')
          ..write('pinHash: $pinHash, ')
          ..write('passwordHash: $passwordHash, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      email,
      firstName,
      lastName,
      role,
      licenseNumber,
      specialization,
      contactNumber,
      isActive,
      pinEnabled,
      pinHash,
      passwordHash,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserEntity &&
          other.id == this.id &&
          other.email == this.email &&
          other.firstName == this.firstName &&
          other.lastName == this.lastName &&
          other.role == this.role &&
          other.licenseNumber == this.licenseNumber &&
          other.specialization == this.specialization &&
          other.contactNumber == this.contactNumber &&
          other.isActive == this.isActive &&
          other.pinEnabled == this.pinEnabled &&
          other.pinHash == this.pinHash &&
          other.passwordHash == this.passwordHash &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class UsersCompanion extends UpdateCompanion<UserEntity> {
  final Value<String> id;
  final Value<String> email;
  final Value<String> firstName;
  final Value<String> lastName;
  final Value<String> role;
  final Value<String?> licenseNumber;
  final Value<String?> specialization;
  final Value<String?> contactNumber;
  final Value<bool> isActive;
  final Value<bool> pinEnabled;
  final Value<String?> pinHash;
  final Value<String> passwordHash;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const UsersCompanion({
    this.id = const Value.absent(),
    this.email = const Value.absent(),
    this.firstName = const Value.absent(),
    this.lastName = const Value.absent(),
    this.role = const Value.absent(),
    this.licenseNumber = const Value.absent(),
    this.specialization = const Value.absent(),
    this.contactNumber = const Value.absent(),
    this.isActive = const Value.absent(),
    this.pinEnabled = const Value.absent(),
    this.pinHash = const Value.absent(),
    this.passwordHash = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UsersCompanion.insert({
    required String id,
    required String email,
    required String firstName,
    required String lastName,
    required String role,
    this.licenseNumber = const Value.absent(),
    this.specialization = const Value.absent(),
    this.contactNumber = const Value.absent(),
    required bool isActive,
    required bool pinEnabled,
    this.pinHash = const Value.absent(),
    required String passwordHash,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        email = Value(email),
        firstName = Value(firstName),
        lastName = Value(lastName),
        role = Value(role),
        isActive = Value(isActive),
        pinEnabled = Value(pinEnabled),
        passwordHash = Value(passwordHash),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<UserEntity> custom({
    Expression<String>? id,
    Expression<String>? email,
    Expression<String>? firstName,
    Expression<String>? lastName,
    Expression<String>? role,
    Expression<String>? licenseNumber,
    Expression<String>? specialization,
    Expression<String>? contactNumber,
    Expression<bool>? isActive,
    Expression<bool>? pinEnabled,
    Expression<String>? pinHash,
    Expression<String>? passwordHash,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (email != null) 'email': email,
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
      if (role != null) 'role': role,
      if (licenseNumber != null) 'license_number': licenseNumber,
      if (specialization != null) 'specialization': specialization,
      if (contactNumber != null) 'contact_number': contactNumber,
      if (isActive != null) 'is_active': isActive,
      if (pinEnabled != null) 'pin_enabled': pinEnabled,
      if (pinHash != null) 'pin_hash': pinHash,
      if (passwordHash != null) 'password_hash': passwordHash,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UsersCompanion copyWith(
      {Value<String>? id,
      Value<String>? email,
      Value<String>? firstName,
      Value<String>? lastName,
      Value<String>? role,
      Value<String?>? licenseNumber,
      Value<String?>? specialization,
      Value<String?>? contactNumber,
      Value<bool>? isActive,
      Value<bool>? pinEnabled,
      Value<String?>? pinHash,
      Value<String>? passwordHash,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return UsersCompanion(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      role: role ?? this.role,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      specialization: specialization ?? this.specialization,
      contactNumber: contactNumber ?? this.contactNumber,
      isActive: isActive ?? this.isActive,
      pinEnabled: pinEnabled ?? this.pinEnabled,
      pinHash: pinHash ?? this.pinHash,
      passwordHash: passwordHash ?? this.passwordHash,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (firstName.present) {
      map['first_name'] = Variable<String>(firstName.value);
    }
    if (lastName.present) {
      map['last_name'] = Variable<String>(lastName.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (licenseNumber.present) {
      map['license_number'] = Variable<String>(licenseNumber.value);
    }
    if (specialization.present) {
      map['specialization'] = Variable<String>(specialization.value);
    }
    if (contactNumber.present) {
      map['contact_number'] = Variable<String>(contactNumber.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (pinEnabled.present) {
      map['pin_enabled'] = Variable<bool>(pinEnabled.value);
    }
    if (pinHash.present) {
      map['pin_hash'] = Variable<String>(pinHash.value);
    }
    if (passwordHash.present) {
      map['password_hash'] = Variable<String>(passwordHash.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersCompanion(')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('firstName: $firstName, ')
          ..write('lastName: $lastName, ')
          ..write('role: $role, ')
          ..write('licenseNumber: $licenseNumber, ')
          ..write('specialization: $specialization, ')
          ..write('contactNumber: $contactNumber, ')
          ..write('isActive: $isActive, ')
          ..write('pinEnabled: $pinEnabled, ')
          ..write('pinHash: $pinHash, ')
          ..write('passwordHash: $passwordHash, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PatientsTable extends Patients
    with TableInfo<$PatientsTable, PatientEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PatientsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _firstNameMeta =
      const VerificationMeta('firstName');
  @override
  late final GeneratedColumn<String> firstName = GeneratedColumn<String>(
      'first_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastNameMeta =
      const VerificationMeta('lastName');
  @override
  late final GeneratedColumn<String> lastName = GeneratedColumn<String>(
      'last_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _middleNameMeta =
      const VerificationMeta('middleName');
  @override
  late final GeneratedColumn<String> middleName = GeneratedColumn<String>(
      'middle_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _suffixMeta = const VerificationMeta('suffix');
  @override
  late final GeneratedColumn<String> suffix = GeneratedColumn<String>(
      'suffix', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _dateOfBirthMeta =
      const VerificationMeta('dateOfBirth');
  @override
  late final GeneratedColumn<DateTime> dateOfBirth = GeneratedColumn<DateTime>(
      'date_of_birth', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _genderMeta = const VerificationMeta('gender');
  @override
  late final GeneratedColumn<String> gender = GeneratedColumn<String>(
      'gender', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _civilStatusMeta =
      const VerificationMeta('civilStatus');
  @override
  late final GeneratedColumn<String> civilStatus = GeneratedColumn<String>(
      'civil_status', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _religionMeta =
      const VerificationMeta('religion');
  @override
  late final GeneratedColumn<String> religion = GeneratedColumn<String>(
      'religion', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _contactNumberMeta =
      const VerificationMeta('contactNumber');
  @override
  late final GeneratedColumn<String> contactNumber = GeneratedColumn<String>(
      'contact_number', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
      'email', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _addressMeta =
      const VerificationMeta('address');
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
      'address', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _barangayMeta =
      const VerificationMeta('barangay');
  @override
  late final GeneratedColumn<String> barangay = GeneratedColumn<String>(
      'barangay', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _purokSitioMeta =
      const VerificationMeta('purokSitio');
  @override
  late final GeneratedColumn<String> purokSitio = GeneratedColumn<String>(
      'purok_sitio', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cityMeta = const VerificationMeta('city');
  @override
  late final GeneratedColumn<String> city = GeneratedColumn<String>(
      'city', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _provinceMeta =
      const VerificationMeta('province');
  @override
  late final GeneratedColumn<String> province = GeneratedColumn<String>(
      'province', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _zipCodeMeta =
      const VerificationMeta('zipCode');
  @override
  late final GeneratedColumn<String> zipCode = GeneratedColumn<String>(
      'zip_code', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _philHealthNumberMeta =
      const VerificationMeta('philHealthNumber');
  @override
  late final GeneratedColumn<String> philHealthNumber = GeneratedColumn<String>(
      'phil_health_number', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _philHealthCategoryMeta =
      const VerificationMeta('philHealthCategory');
  @override
  late final GeneratedColumn<String> philHealthCategory =
      GeneratedColumn<String>('phil_health_category', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _localLguIdNumberMeta =
      const VerificationMeta('localLguIdNumber');
  @override
  late final GeneratedColumn<String> localLguIdNumber = GeneratedColumn<String>(
      'local_lgu_id_number', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _bloodTypeMeta =
      const VerificationMeta('bloodType');
  @override
  late final GeneratedColumn<String> bloodType = GeneratedColumn<String>(
      'blood_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _emergencyContactNameMeta =
      const VerificationMeta('emergencyContactName');
  @override
  late final GeneratedColumn<String> emergencyContactName =
      GeneratedColumn<String>('emergency_contact_name', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _emergencyContactNumberMeta =
      const VerificationMeta('emergencyContactNumber');
  @override
  late final GeneratedColumn<String> emergencyContactNumber =
      GeneratedColumn<String>('emergency_contact_number', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _emergencyContactRelationMeta =
      const VerificationMeta('emergencyContactRelation');
  @override
  late final GeneratedColumn<String> emergencyContactRelation =
      GeneratedColumn<String>('emergency_contact_relation', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _occupationMeta =
      const VerificationMeta('occupation');
  @override
  late final GeneratedColumn<String> occupation = GeneratedColumn<String>(
      'occupation', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _employerMeta =
      const VerificationMeta('employer');
  @override
  late final GeneratedColumn<String> employer = GeneratedColumn<String>(
      'employer', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isPwdMeta = const VerificationMeta('isPwd');
  @override
  late final GeneratedColumn<bool> isPwd = GeneratedColumn<bool>(
      'is_pwd', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_pwd" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isSoloParentMeta =
      const VerificationMeta('isSoloParent');
  @override
  late final GeneratedColumn<bool> isSoloParent = GeneratedColumn<bool>(
      'is_solo_parent', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_solo_parent" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isIndigenousPersonMeta =
      const VerificationMeta('isIndigenousPerson');
  @override
  late final GeneratedColumn<bool> isIndigenousPerson = GeneratedColumn<bool>(
      'is_indigenous_person', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_indigenous_person" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _tribeEthnolinguisticGroupMeta =
      const VerificationMeta('tribeEthnolinguisticGroup');
  @override
  late final GeneratedColumn<String> tribeEthnolinguisticGroup =
      GeneratedColumn<String>('tribe_ethnolinguistic_group', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _is4PsBeneficiaryMeta =
      const VerificationMeta('is4PsBeneficiary');
  @override
  late final GeneratedColumn<bool> is4PsBeneficiary = GeneratedColumn<bool>(
      'is4_ps_beneficiary', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is4_ps_beneficiary" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _householdIdNumberMeta =
      const VerificationMeta('householdIdNumber');
  @override
  late final GeneratedColumn<String> householdIdNumber =
      GeneratedColumn<String>('household_id_number', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _waterSourceMeta =
      const VerificationMeta('waterSource');
  @override
  late final GeneratedColumn<String> waterSource = GeneratedColumn<String>(
      'water_source', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _toiletFacilityMeta =
      const VerificationMeta('toiletFacility');
  @override
  late final GeneratedColumn<String> toiletFacility = GeneratedColumn<String>(
      'toilet_facility', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<double> height = GeneratedColumn<double>(
      'height', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _weightMeta = const VerificationMeta('weight');
  @override
  late final GeneratedColumn<double> weight = GeneratedColumn<double>(
      'weight', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _allergiesMeta =
      const VerificationMeta('allergies');
  @override
  late final GeneratedColumn<String> allergies = GeneratedColumn<String>(
      'allergies', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _medicalHistoryMeta =
      const VerificationMeta('medicalHistory');
  @override
  late final GeneratedColumn<String> medicalHistory = GeneratedColumn<String>(
      'medical_history', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _lastVisitDateMeta =
      const VerificationMeta('lastVisitDate');
  @override
  late final GeneratedColumn<DateTime> lastVisitDate =
      GeneratedColumn<DateTime>('last_visit_date', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _syncStatusMeta =
      const VerificationMeta('syncStatus');
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
      'sync_status', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _syncErrorMeta =
      const VerificationMeta('syncError');
  @override
  late final GeneratedColumn<String> syncError = GeneratedColumn<String>(
      'sync_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        firstName,
        lastName,
        middleName,
        suffix,
        dateOfBirth,
        gender,
        civilStatus,
        religion,
        contactNumber,
        email,
        address,
        barangay,
        purokSitio,
        city,
        province,
        zipCode,
        philHealthNumber,
        philHealthCategory,
        localLguIdNumber,
        bloodType,
        emergencyContactName,
        emergencyContactNumber,
        emergencyContactRelation,
        occupation,
        employer,
        isPwd,
        isSoloParent,
        isIndigenousPerson,
        tribeEthnolinguisticGroup,
        is4PsBeneficiary,
        householdIdNumber,
        waterSource,
        toiletFacility,
        height,
        weight,
        allergies,
        medicalHistory,
        category,
        createdAt,
        updatedAt,
        lastVisitDate,
        syncStatus,
        syncError
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'patients';
  @override
  VerificationContext validateIntegrity(Insertable<PatientEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('first_name')) {
      context.handle(_firstNameMeta,
          firstName.isAcceptableOrUnknown(data['first_name']!, _firstNameMeta));
    } else if (isInserting) {
      context.missing(_firstNameMeta);
    }
    if (data.containsKey('last_name')) {
      context.handle(_lastNameMeta,
          lastName.isAcceptableOrUnknown(data['last_name']!, _lastNameMeta));
    } else if (isInserting) {
      context.missing(_lastNameMeta);
    }
    if (data.containsKey('middle_name')) {
      context.handle(
          _middleNameMeta,
          middleName.isAcceptableOrUnknown(
              data['middle_name']!, _middleNameMeta));
    }
    if (data.containsKey('suffix')) {
      context.handle(_suffixMeta,
          suffix.isAcceptableOrUnknown(data['suffix']!, _suffixMeta));
    }
    if (data.containsKey('date_of_birth')) {
      context.handle(
          _dateOfBirthMeta,
          dateOfBirth.isAcceptableOrUnknown(
              data['date_of_birth']!, _dateOfBirthMeta));
    }
    if (data.containsKey('gender')) {
      context.handle(_genderMeta,
          gender.isAcceptableOrUnknown(data['gender']!, _genderMeta));
    }
    if (data.containsKey('civil_status')) {
      context.handle(
          _civilStatusMeta,
          civilStatus.isAcceptableOrUnknown(
              data['civil_status']!, _civilStatusMeta));
    }
    if (data.containsKey('religion')) {
      context.handle(_religionMeta,
          religion.isAcceptableOrUnknown(data['religion']!, _religionMeta));
    }
    if (data.containsKey('contact_number')) {
      context.handle(
          _contactNumberMeta,
          contactNumber.isAcceptableOrUnknown(
              data['contact_number']!, _contactNumberMeta));
    }
    if (data.containsKey('email')) {
      context.handle(
          _emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    }
    if (data.containsKey('address')) {
      context.handle(_addressMeta,
          address.isAcceptableOrUnknown(data['address']!, _addressMeta));
    }
    if (data.containsKey('barangay')) {
      context.handle(_barangayMeta,
          barangay.isAcceptableOrUnknown(data['barangay']!, _barangayMeta));
    }
    if (data.containsKey('purok_sitio')) {
      context.handle(
          _purokSitioMeta,
          purokSitio.isAcceptableOrUnknown(
              data['purok_sitio']!, _purokSitioMeta));
    }
    if (data.containsKey('city')) {
      context.handle(
          _cityMeta, city.isAcceptableOrUnknown(data['city']!, _cityMeta));
    }
    if (data.containsKey('province')) {
      context.handle(_provinceMeta,
          province.isAcceptableOrUnknown(data['province']!, _provinceMeta));
    }
    if (data.containsKey('zip_code')) {
      context.handle(_zipCodeMeta,
          zipCode.isAcceptableOrUnknown(data['zip_code']!, _zipCodeMeta));
    }
    if (data.containsKey('phil_health_number')) {
      context.handle(
          _philHealthNumberMeta,
          philHealthNumber.isAcceptableOrUnknown(
              data['phil_health_number']!, _philHealthNumberMeta));
    }
    if (data.containsKey('phil_health_category')) {
      context.handle(
          _philHealthCategoryMeta,
          philHealthCategory.isAcceptableOrUnknown(
              data['phil_health_category']!, _philHealthCategoryMeta));
    }
    if (data.containsKey('local_lgu_id_number')) {
      context.handle(
          _localLguIdNumberMeta,
          localLguIdNumber.isAcceptableOrUnknown(
              data['local_lgu_id_number']!, _localLguIdNumberMeta));
    }
    if (data.containsKey('blood_type')) {
      context.handle(_bloodTypeMeta,
          bloodType.isAcceptableOrUnknown(data['blood_type']!, _bloodTypeMeta));
    }
    if (data.containsKey('emergency_contact_name')) {
      context.handle(
          _emergencyContactNameMeta,
          emergencyContactName.isAcceptableOrUnknown(
              data['emergency_contact_name']!, _emergencyContactNameMeta));
    }
    if (data.containsKey('emergency_contact_number')) {
      context.handle(
          _emergencyContactNumberMeta,
          emergencyContactNumber.isAcceptableOrUnknown(
              data['emergency_contact_number']!, _emergencyContactNumberMeta));
    }
    if (data.containsKey('emergency_contact_relation')) {
      context.handle(
          _emergencyContactRelationMeta,
          emergencyContactRelation.isAcceptableOrUnknown(
              data['emergency_contact_relation']!,
              _emergencyContactRelationMeta));
    }
    if (data.containsKey('occupation')) {
      context.handle(
          _occupationMeta,
          occupation.isAcceptableOrUnknown(
              data['occupation']!, _occupationMeta));
    }
    if (data.containsKey('employer')) {
      context.handle(_employerMeta,
          employer.isAcceptableOrUnknown(data['employer']!, _employerMeta));
    }
    if (data.containsKey('is_pwd')) {
      context.handle(
          _isPwdMeta, isPwd.isAcceptableOrUnknown(data['is_pwd']!, _isPwdMeta));
    }
    if (data.containsKey('is_solo_parent')) {
      context.handle(
          _isSoloParentMeta,
          isSoloParent.isAcceptableOrUnknown(
              data['is_solo_parent']!, _isSoloParentMeta));
    }
    if (data.containsKey('is_indigenous_person')) {
      context.handle(
          _isIndigenousPersonMeta,
          isIndigenousPerson.isAcceptableOrUnknown(
              data['is_indigenous_person']!, _isIndigenousPersonMeta));
    }
    if (data.containsKey('tribe_ethnolinguistic_group')) {
      context.handle(
          _tribeEthnolinguisticGroupMeta,
          tribeEthnolinguisticGroup.isAcceptableOrUnknown(
              data['tribe_ethnolinguistic_group']!,
              _tribeEthnolinguisticGroupMeta));
    }
    if (data.containsKey('is4_ps_beneficiary')) {
      context.handle(
          _is4PsBeneficiaryMeta,
          is4PsBeneficiary.isAcceptableOrUnknown(
              data['is4_ps_beneficiary']!, _is4PsBeneficiaryMeta));
    }
    if (data.containsKey('household_id_number')) {
      context.handle(
          _householdIdNumberMeta,
          householdIdNumber.isAcceptableOrUnknown(
              data['household_id_number']!, _householdIdNumberMeta));
    }
    if (data.containsKey('water_source')) {
      context.handle(
          _waterSourceMeta,
          waterSource.isAcceptableOrUnknown(
              data['water_source']!, _waterSourceMeta));
    }
    if (data.containsKey('toilet_facility')) {
      context.handle(
          _toiletFacilityMeta,
          toiletFacility.isAcceptableOrUnknown(
              data['toilet_facility']!, _toiletFacilityMeta));
    }
    if (data.containsKey('height')) {
      context.handle(_heightMeta,
          height.isAcceptableOrUnknown(data['height']!, _heightMeta));
    }
    if (data.containsKey('weight')) {
      context.handle(_weightMeta,
          weight.isAcceptableOrUnknown(data['weight']!, _weightMeta));
    }
    if (data.containsKey('allergies')) {
      context.handle(_allergiesMeta,
          allergies.isAcceptableOrUnknown(data['allergies']!, _allergiesMeta));
    }
    if (data.containsKey('medical_history')) {
      context.handle(
          _medicalHistoryMeta,
          medicalHistory.isAcceptableOrUnknown(
              data['medical_history']!, _medicalHistoryMeta));
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('last_visit_date')) {
      context.handle(
          _lastVisitDateMeta,
          lastVisitDate.isAcceptableOrUnknown(
              data['last_visit_date']!, _lastVisitDateMeta));
    }
    if (data.containsKey('sync_status')) {
      context.handle(
          _syncStatusMeta,
          syncStatus.isAcceptableOrUnknown(
              data['sync_status']!, _syncStatusMeta));
    }
    if (data.containsKey('sync_error')) {
      context.handle(_syncErrorMeta,
          syncError.isAcceptableOrUnknown(data['sync_error']!, _syncErrorMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PatientEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PatientEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      firstName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}first_name'])!,
      lastName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_name'])!,
      middleName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}middle_name']),
      suffix: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}suffix']),
      dateOfBirth: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date_of_birth']),
      gender: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}gender']),
      civilStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}civil_status']),
      religion: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}religion']),
      contactNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}contact_number']),
      email: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email']),
      address: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}address']),
      barangay: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}barangay']),
      purokSitio: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}purok_sitio']),
      city: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}city']),
      province: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}province']),
      zipCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}zip_code']),
      philHealthNumber: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}phil_health_number']),
      philHealthCategory: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}phil_health_category']),
      localLguIdNumber: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}local_lgu_id_number']),
      bloodType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}blood_type']),
      emergencyContactName: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}emergency_contact_name']),
      emergencyContactNumber: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}emergency_contact_number']),
      emergencyContactRelation: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}emergency_contact_relation']),
      occupation: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}occupation']),
      employer: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}employer']),
      isPwd: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_pwd'])!,
      isSoloParent: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_solo_parent'])!,
      isIndigenousPerson: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}is_indigenous_person'])!,
      tribeEthnolinguisticGroup: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}tribe_ethnolinguistic_group']),
      is4PsBeneficiary: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}is4_ps_beneficiary'])!,
      householdIdNumber: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}household_id_number']),
      waterSource: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}water_source']),
      toiletFacility: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}toilet_facility']),
      height: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}height']),
      weight: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}weight']),
      allergies: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}allergies']),
      medicalHistory: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}medical_history']),
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
      lastVisitDate: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_visit_date']),
      syncStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sync_status']),
      syncError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_error']),
    );
  }

  @override
  $PatientsTable createAlias(String alias) {
    return $PatientsTable(attachedDatabase, alias);
  }
}

class PatientEntity extends DataClass implements Insertable<PatientEntity> {
  final String id;
  final String firstName;
  final String lastName;
  final String? middleName;
  final String? suffix;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? civilStatus;
  final String? religion;
  final String? contactNumber;
  final String? email;
  final String? address;
  final String? barangay;
  final String? purokSitio;
  final String? city;
  final String? province;
  final String? zipCode;
  final String? philHealthNumber;
  final String? philHealthCategory;
  final String? localLguIdNumber;
  final String? bloodType;
  final String? emergencyContactName;
  final String? emergencyContactNumber;
  final String? emergencyContactRelation;
  final String? occupation;
  final String? employer;
  final bool isPwd;
  final bool isSoloParent;
  final bool isIndigenousPerson;
  final String? tribeEthnolinguisticGroup;
  final bool is4PsBeneficiary;
  final String? householdIdNumber;
  final String? waterSource;
  final String? toiletFacility;
  final double? height;
  final double? weight;
  final String? allergies;
  final String? medicalHistory;
  final String? category;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastVisitDate;
  final int? syncStatus;
  final String? syncError;
  const PatientEntity(
      {required this.id,
      required this.firstName,
      required this.lastName,
      this.middleName,
      this.suffix,
      this.dateOfBirth,
      this.gender,
      this.civilStatus,
      this.religion,
      this.contactNumber,
      this.email,
      this.address,
      this.barangay,
      this.purokSitio,
      this.city,
      this.province,
      this.zipCode,
      this.philHealthNumber,
      this.philHealthCategory,
      this.localLguIdNumber,
      this.bloodType,
      this.emergencyContactName,
      this.emergencyContactNumber,
      this.emergencyContactRelation,
      this.occupation,
      this.employer,
      required this.isPwd,
      required this.isSoloParent,
      required this.isIndigenousPerson,
      this.tribeEthnolinguisticGroup,
      required this.is4PsBeneficiary,
      this.householdIdNumber,
      this.waterSource,
      this.toiletFacility,
      this.height,
      this.weight,
      this.allergies,
      this.medicalHistory,
      this.category,
      this.createdAt,
      this.updatedAt,
      this.lastVisitDate,
      this.syncStatus,
      this.syncError});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['first_name'] = Variable<String>(firstName);
    map['last_name'] = Variable<String>(lastName);
    if (!nullToAbsent || middleName != null) {
      map['middle_name'] = Variable<String>(middleName);
    }
    if (!nullToAbsent || suffix != null) {
      map['suffix'] = Variable<String>(suffix);
    }
    if (!nullToAbsent || dateOfBirth != null) {
      map['date_of_birth'] = Variable<DateTime>(dateOfBirth);
    }
    if (!nullToAbsent || gender != null) {
      map['gender'] = Variable<String>(gender);
    }
    if (!nullToAbsent || civilStatus != null) {
      map['civil_status'] = Variable<String>(civilStatus);
    }
    if (!nullToAbsent || religion != null) {
      map['religion'] = Variable<String>(religion);
    }
    if (!nullToAbsent || contactNumber != null) {
      map['contact_number'] = Variable<String>(contactNumber);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || barangay != null) {
      map['barangay'] = Variable<String>(barangay);
    }
    if (!nullToAbsent || purokSitio != null) {
      map['purok_sitio'] = Variable<String>(purokSitio);
    }
    if (!nullToAbsent || city != null) {
      map['city'] = Variable<String>(city);
    }
    if (!nullToAbsent || province != null) {
      map['province'] = Variable<String>(province);
    }
    if (!nullToAbsent || zipCode != null) {
      map['zip_code'] = Variable<String>(zipCode);
    }
    if (!nullToAbsent || philHealthNumber != null) {
      map['phil_health_number'] = Variable<String>(philHealthNumber);
    }
    if (!nullToAbsent || philHealthCategory != null) {
      map['phil_health_category'] = Variable<String>(philHealthCategory);
    }
    if (!nullToAbsent || localLguIdNumber != null) {
      map['local_lgu_id_number'] = Variable<String>(localLguIdNumber);
    }
    if (!nullToAbsent || bloodType != null) {
      map['blood_type'] = Variable<String>(bloodType);
    }
    if (!nullToAbsent || emergencyContactName != null) {
      map['emergency_contact_name'] = Variable<String>(emergencyContactName);
    }
    if (!nullToAbsent || emergencyContactNumber != null) {
      map['emergency_contact_number'] =
          Variable<String>(emergencyContactNumber);
    }
    if (!nullToAbsent || emergencyContactRelation != null) {
      map['emergency_contact_relation'] =
          Variable<String>(emergencyContactRelation);
    }
    if (!nullToAbsent || occupation != null) {
      map['occupation'] = Variable<String>(occupation);
    }
    if (!nullToAbsent || employer != null) {
      map['employer'] = Variable<String>(employer);
    }
    map['is_pwd'] = Variable<bool>(isPwd);
    map['is_solo_parent'] = Variable<bool>(isSoloParent);
    map['is_indigenous_person'] = Variable<bool>(isIndigenousPerson);
    if (!nullToAbsent || tribeEthnolinguisticGroup != null) {
      map['tribe_ethnolinguistic_group'] =
          Variable<String>(tribeEthnolinguisticGroup);
    }
    map['is4_ps_beneficiary'] = Variable<bool>(is4PsBeneficiary);
    if (!nullToAbsent || householdIdNumber != null) {
      map['household_id_number'] = Variable<String>(householdIdNumber);
    }
    if (!nullToAbsent || waterSource != null) {
      map['water_source'] = Variable<String>(waterSource);
    }
    if (!nullToAbsent || toiletFacility != null) {
      map['toilet_facility'] = Variable<String>(toiletFacility);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<double>(height);
    }
    if (!nullToAbsent || weight != null) {
      map['weight'] = Variable<double>(weight);
    }
    if (!nullToAbsent || allergies != null) {
      map['allergies'] = Variable<String>(allergies);
    }
    if (!nullToAbsent || medicalHistory != null) {
      map['medical_history'] = Variable<String>(medicalHistory);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    if (!nullToAbsent || lastVisitDate != null) {
      map['last_visit_date'] = Variable<DateTime>(lastVisitDate);
    }
    if (!nullToAbsent || syncStatus != null) {
      map['sync_status'] = Variable<int>(syncStatus);
    }
    if (!nullToAbsent || syncError != null) {
      map['sync_error'] = Variable<String>(syncError);
    }
    return map;
  }

  PatientsCompanion toCompanion(bool nullToAbsent) {
    return PatientsCompanion(
      id: Value(id),
      firstName: Value(firstName),
      lastName: Value(lastName),
      middleName: middleName == null && nullToAbsent
          ? const Value.absent()
          : Value(middleName),
      suffix:
          suffix == null && nullToAbsent ? const Value.absent() : Value(suffix),
      dateOfBirth: dateOfBirth == null && nullToAbsent
          ? const Value.absent()
          : Value(dateOfBirth),
      gender:
          gender == null && nullToAbsent ? const Value.absent() : Value(gender),
      civilStatus: civilStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(civilStatus),
      religion: religion == null && nullToAbsent
          ? const Value.absent()
          : Value(religion),
      contactNumber: contactNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(contactNumber),
      email:
          email == null && nullToAbsent ? const Value.absent() : Value(email),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      barangay: barangay == null && nullToAbsent
          ? const Value.absent()
          : Value(barangay),
      purokSitio: purokSitio == null && nullToAbsent
          ? const Value.absent()
          : Value(purokSitio),
      city: city == null && nullToAbsent ? const Value.absent() : Value(city),
      province: province == null && nullToAbsent
          ? const Value.absent()
          : Value(province),
      zipCode: zipCode == null && nullToAbsent
          ? const Value.absent()
          : Value(zipCode),
      philHealthNumber: philHealthNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(philHealthNumber),
      philHealthCategory: philHealthCategory == null && nullToAbsent
          ? const Value.absent()
          : Value(philHealthCategory),
      localLguIdNumber: localLguIdNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(localLguIdNumber),
      bloodType: bloodType == null && nullToAbsent
          ? const Value.absent()
          : Value(bloodType),
      emergencyContactName: emergencyContactName == null && nullToAbsent
          ? const Value.absent()
          : Value(emergencyContactName),
      emergencyContactNumber: emergencyContactNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(emergencyContactNumber),
      emergencyContactRelation: emergencyContactRelation == null && nullToAbsent
          ? const Value.absent()
          : Value(emergencyContactRelation),
      occupation: occupation == null && nullToAbsent
          ? const Value.absent()
          : Value(occupation),
      employer: employer == null && nullToAbsent
          ? const Value.absent()
          : Value(employer),
      isPwd: Value(isPwd),
      isSoloParent: Value(isSoloParent),
      isIndigenousPerson: Value(isIndigenousPerson),
      tribeEthnolinguisticGroup:
          tribeEthnolinguisticGroup == null && nullToAbsent
              ? const Value.absent()
              : Value(tribeEthnolinguisticGroup),
      is4PsBeneficiary: Value(is4PsBeneficiary),
      householdIdNumber: householdIdNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(householdIdNumber),
      waterSource: waterSource == null && nullToAbsent
          ? const Value.absent()
          : Value(waterSource),
      toiletFacility: toiletFacility == null && nullToAbsent
          ? const Value.absent()
          : Value(toiletFacility),
      height:
          height == null && nullToAbsent ? const Value.absent() : Value(height),
      weight:
          weight == null && nullToAbsent ? const Value.absent() : Value(weight),
      allergies: allergies == null && nullToAbsent
          ? const Value.absent()
          : Value(allergies),
      medicalHistory: medicalHistory == null && nullToAbsent
          ? const Value.absent()
          : Value(medicalHistory),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      lastVisitDate: lastVisitDate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastVisitDate),
      syncStatus: syncStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(syncStatus),
      syncError: syncError == null && nullToAbsent
          ? const Value.absent()
          : Value(syncError),
    );
  }

  factory PatientEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PatientEntity(
      id: serializer.fromJson<String>(json['id']),
      firstName: serializer.fromJson<String>(json['firstName']),
      lastName: serializer.fromJson<String>(json['lastName']),
      middleName: serializer.fromJson<String?>(json['middleName']),
      suffix: serializer.fromJson<String?>(json['suffix']),
      dateOfBirth: serializer.fromJson<DateTime?>(json['dateOfBirth']),
      gender: serializer.fromJson<String?>(json['gender']),
      civilStatus: serializer.fromJson<String?>(json['civilStatus']),
      religion: serializer.fromJson<String?>(json['religion']),
      contactNumber: serializer.fromJson<String?>(json['contactNumber']),
      email: serializer.fromJson<String?>(json['email']),
      address: serializer.fromJson<String?>(json['address']),
      barangay: serializer.fromJson<String?>(json['barangay']),
      purokSitio: serializer.fromJson<String?>(json['purokSitio']),
      city: serializer.fromJson<String?>(json['city']),
      province: serializer.fromJson<String?>(json['province']),
      zipCode: serializer.fromJson<String?>(json['zipCode']),
      philHealthNumber: serializer.fromJson<String?>(json['philHealthNumber']),
      philHealthCategory:
          serializer.fromJson<String?>(json['philHealthCategory']),
      localLguIdNumber: serializer.fromJson<String?>(json['localLguIdNumber']),
      bloodType: serializer.fromJson<String?>(json['bloodType']),
      emergencyContactName:
          serializer.fromJson<String?>(json['emergencyContactName']),
      emergencyContactNumber:
          serializer.fromJson<String?>(json['emergencyContactNumber']),
      emergencyContactRelation:
          serializer.fromJson<String?>(json['emergencyContactRelation']),
      occupation: serializer.fromJson<String?>(json['occupation']),
      employer: serializer.fromJson<String?>(json['employer']),
      isPwd: serializer.fromJson<bool>(json['isPwd']),
      isSoloParent: serializer.fromJson<bool>(json['isSoloParent']),
      isIndigenousPerson: serializer.fromJson<bool>(json['isIndigenousPerson']),
      tribeEthnolinguisticGroup:
          serializer.fromJson<String?>(json['tribeEthnolinguisticGroup']),
      is4PsBeneficiary: serializer.fromJson<bool>(json['is4PsBeneficiary']),
      householdIdNumber:
          serializer.fromJson<String?>(json['householdIdNumber']),
      waterSource: serializer.fromJson<String?>(json['waterSource']),
      toiletFacility: serializer.fromJson<String?>(json['toiletFacility']),
      height: serializer.fromJson<double?>(json['height']),
      weight: serializer.fromJson<double?>(json['weight']),
      allergies: serializer.fromJson<String?>(json['allergies']),
      medicalHistory: serializer.fromJson<String?>(json['medicalHistory']),
      category: serializer.fromJson<String?>(json['category']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      lastVisitDate: serializer.fromJson<DateTime?>(json['lastVisitDate']),
      syncStatus: serializer.fromJson<int?>(json['syncStatus']),
      syncError: serializer.fromJson<String?>(json['syncError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'firstName': serializer.toJson<String>(firstName),
      'lastName': serializer.toJson<String>(lastName),
      'middleName': serializer.toJson<String?>(middleName),
      'suffix': serializer.toJson<String?>(suffix),
      'dateOfBirth': serializer.toJson<DateTime?>(dateOfBirth),
      'gender': serializer.toJson<String?>(gender),
      'civilStatus': serializer.toJson<String?>(civilStatus),
      'religion': serializer.toJson<String?>(religion),
      'contactNumber': serializer.toJson<String?>(contactNumber),
      'email': serializer.toJson<String?>(email),
      'address': serializer.toJson<String?>(address),
      'barangay': serializer.toJson<String?>(barangay),
      'purokSitio': serializer.toJson<String?>(purokSitio),
      'city': serializer.toJson<String?>(city),
      'province': serializer.toJson<String?>(province),
      'zipCode': serializer.toJson<String?>(zipCode),
      'philHealthNumber': serializer.toJson<String?>(philHealthNumber),
      'philHealthCategory': serializer.toJson<String?>(philHealthCategory),
      'localLguIdNumber': serializer.toJson<String?>(localLguIdNumber),
      'bloodType': serializer.toJson<String?>(bloodType),
      'emergencyContactName': serializer.toJson<String?>(emergencyContactName),
      'emergencyContactNumber':
          serializer.toJson<String?>(emergencyContactNumber),
      'emergencyContactRelation':
          serializer.toJson<String?>(emergencyContactRelation),
      'occupation': serializer.toJson<String?>(occupation),
      'employer': serializer.toJson<String?>(employer),
      'isPwd': serializer.toJson<bool>(isPwd),
      'isSoloParent': serializer.toJson<bool>(isSoloParent),
      'isIndigenousPerson': serializer.toJson<bool>(isIndigenousPerson),
      'tribeEthnolinguisticGroup':
          serializer.toJson<String?>(tribeEthnolinguisticGroup),
      'is4PsBeneficiary': serializer.toJson<bool>(is4PsBeneficiary),
      'householdIdNumber': serializer.toJson<String?>(householdIdNumber),
      'waterSource': serializer.toJson<String?>(waterSource),
      'toiletFacility': serializer.toJson<String?>(toiletFacility),
      'height': serializer.toJson<double?>(height),
      'weight': serializer.toJson<double?>(weight),
      'allergies': serializer.toJson<String?>(allergies),
      'medicalHistory': serializer.toJson<String?>(medicalHistory),
      'category': serializer.toJson<String?>(category),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'lastVisitDate': serializer.toJson<DateTime?>(lastVisitDate),
      'syncStatus': serializer.toJson<int?>(syncStatus),
      'syncError': serializer.toJson<String?>(syncError),
    };
  }

  PatientEntity copyWith(
          {String? id,
          String? firstName,
          String? lastName,
          Value<String?> middleName = const Value.absent(),
          Value<String?> suffix = const Value.absent(),
          Value<DateTime?> dateOfBirth = const Value.absent(),
          Value<String?> gender = const Value.absent(),
          Value<String?> civilStatus = const Value.absent(),
          Value<String?> religion = const Value.absent(),
          Value<String?> contactNumber = const Value.absent(),
          Value<String?> email = const Value.absent(),
          Value<String?> address = const Value.absent(),
          Value<String?> barangay = const Value.absent(),
          Value<String?> purokSitio = const Value.absent(),
          Value<String?> city = const Value.absent(),
          Value<String?> province = const Value.absent(),
          Value<String?> zipCode = const Value.absent(),
          Value<String?> philHealthNumber = const Value.absent(),
          Value<String?> philHealthCategory = const Value.absent(),
          Value<String?> localLguIdNumber = const Value.absent(),
          Value<String?> bloodType = const Value.absent(),
          Value<String?> emergencyContactName = const Value.absent(),
          Value<String?> emergencyContactNumber = const Value.absent(),
          Value<String?> emergencyContactRelation = const Value.absent(),
          Value<String?> occupation = const Value.absent(),
          Value<String?> employer = const Value.absent(),
          bool? isPwd,
          bool? isSoloParent,
          bool? isIndigenousPerson,
          Value<String?> tribeEthnolinguisticGroup = const Value.absent(),
          bool? is4PsBeneficiary,
          Value<String?> householdIdNumber = const Value.absent(),
          Value<String?> waterSource = const Value.absent(),
          Value<String?> toiletFacility = const Value.absent(),
          Value<double?> height = const Value.absent(),
          Value<double?> weight = const Value.absent(),
          Value<String?> allergies = const Value.absent(),
          Value<String?> medicalHistory = const Value.absent(),
          Value<String?> category = const Value.absent(),
          Value<DateTime?> createdAt = const Value.absent(),
          Value<DateTime?> updatedAt = const Value.absent(),
          Value<DateTime?> lastVisitDate = const Value.absent(),
          Value<int?> syncStatus = const Value.absent(),
          Value<String?> syncError = const Value.absent()}) =>
      PatientEntity(
        id: id ?? this.id,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        middleName: middleName.present ? middleName.value : this.middleName,
        suffix: suffix.present ? suffix.value : this.suffix,
        dateOfBirth: dateOfBirth.present ? dateOfBirth.value : this.dateOfBirth,
        gender: gender.present ? gender.value : this.gender,
        civilStatus: civilStatus.present ? civilStatus.value : this.civilStatus,
        religion: religion.present ? religion.value : this.religion,
        contactNumber:
            contactNumber.present ? contactNumber.value : this.contactNumber,
        email: email.present ? email.value : this.email,
        address: address.present ? address.value : this.address,
        barangay: barangay.present ? barangay.value : this.barangay,
        purokSitio: purokSitio.present ? purokSitio.value : this.purokSitio,
        city: city.present ? city.value : this.city,
        province: province.present ? province.value : this.province,
        zipCode: zipCode.present ? zipCode.value : this.zipCode,
        philHealthNumber: philHealthNumber.present
            ? philHealthNumber.value
            : this.philHealthNumber,
        philHealthCategory: philHealthCategory.present
            ? philHealthCategory.value
            : this.philHealthCategory,
        localLguIdNumber: localLguIdNumber.present
            ? localLguIdNumber.value
            : this.localLguIdNumber,
        bloodType: bloodType.present ? bloodType.value : this.bloodType,
        emergencyContactName: emergencyContactName.present
            ? emergencyContactName.value
            : this.emergencyContactName,
        emergencyContactNumber: emergencyContactNumber.present
            ? emergencyContactNumber.value
            : this.emergencyContactNumber,
        emergencyContactRelation: emergencyContactRelation.present
            ? emergencyContactRelation.value
            : this.emergencyContactRelation,
        occupation: occupation.present ? occupation.value : this.occupation,
        employer: employer.present ? employer.value : this.employer,
        isPwd: isPwd ?? this.isPwd,
        isSoloParent: isSoloParent ?? this.isSoloParent,
        isIndigenousPerson: isIndigenousPerson ?? this.isIndigenousPerson,
        tribeEthnolinguisticGroup: tribeEthnolinguisticGroup.present
            ? tribeEthnolinguisticGroup.value
            : this.tribeEthnolinguisticGroup,
        is4PsBeneficiary: is4PsBeneficiary ?? this.is4PsBeneficiary,
        householdIdNumber: householdIdNumber.present
            ? householdIdNumber.value
            : this.householdIdNumber,
        waterSource: waterSource.present ? waterSource.value : this.waterSource,
        toiletFacility:
            toiletFacility.present ? toiletFacility.value : this.toiletFacility,
        height: height.present ? height.value : this.height,
        weight: weight.present ? weight.value : this.weight,
        allergies: allergies.present ? allergies.value : this.allergies,
        medicalHistory:
            medicalHistory.present ? medicalHistory.value : this.medicalHistory,
        category: category.present ? category.value : this.category,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
        lastVisitDate:
            lastVisitDate.present ? lastVisitDate.value : this.lastVisitDate,
        syncStatus: syncStatus.present ? syncStatus.value : this.syncStatus,
        syncError: syncError.present ? syncError.value : this.syncError,
      );
  PatientEntity copyWithCompanion(PatientsCompanion data) {
    return PatientEntity(
      id: data.id.present ? data.id.value : this.id,
      firstName: data.firstName.present ? data.firstName.value : this.firstName,
      lastName: data.lastName.present ? data.lastName.value : this.lastName,
      middleName:
          data.middleName.present ? data.middleName.value : this.middleName,
      suffix: data.suffix.present ? data.suffix.value : this.suffix,
      dateOfBirth:
          data.dateOfBirth.present ? data.dateOfBirth.value : this.dateOfBirth,
      gender: data.gender.present ? data.gender.value : this.gender,
      civilStatus:
          data.civilStatus.present ? data.civilStatus.value : this.civilStatus,
      religion: data.religion.present ? data.religion.value : this.religion,
      contactNumber: data.contactNumber.present
          ? data.contactNumber.value
          : this.contactNumber,
      email: data.email.present ? data.email.value : this.email,
      address: data.address.present ? data.address.value : this.address,
      barangay: data.barangay.present ? data.barangay.value : this.barangay,
      purokSitio:
          data.purokSitio.present ? data.purokSitio.value : this.purokSitio,
      city: data.city.present ? data.city.value : this.city,
      province: data.province.present ? data.province.value : this.province,
      zipCode: data.zipCode.present ? data.zipCode.value : this.zipCode,
      philHealthNumber: data.philHealthNumber.present
          ? data.philHealthNumber.value
          : this.philHealthNumber,
      philHealthCategory: data.philHealthCategory.present
          ? data.philHealthCategory.value
          : this.philHealthCategory,
      localLguIdNumber: data.localLguIdNumber.present
          ? data.localLguIdNumber.value
          : this.localLguIdNumber,
      bloodType: data.bloodType.present ? data.bloodType.value : this.bloodType,
      emergencyContactName: data.emergencyContactName.present
          ? data.emergencyContactName.value
          : this.emergencyContactName,
      emergencyContactNumber: data.emergencyContactNumber.present
          ? data.emergencyContactNumber.value
          : this.emergencyContactNumber,
      emergencyContactRelation: data.emergencyContactRelation.present
          ? data.emergencyContactRelation.value
          : this.emergencyContactRelation,
      occupation:
          data.occupation.present ? data.occupation.value : this.occupation,
      employer: data.employer.present ? data.employer.value : this.employer,
      isPwd: data.isPwd.present ? data.isPwd.value : this.isPwd,
      isSoloParent: data.isSoloParent.present
          ? data.isSoloParent.value
          : this.isSoloParent,
      isIndigenousPerson: data.isIndigenousPerson.present
          ? data.isIndigenousPerson.value
          : this.isIndigenousPerson,
      tribeEthnolinguisticGroup: data.tribeEthnolinguisticGroup.present
          ? data.tribeEthnolinguisticGroup.value
          : this.tribeEthnolinguisticGroup,
      is4PsBeneficiary: data.is4PsBeneficiary.present
          ? data.is4PsBeneficiary.value
          : this.is4PsBeneficiary,
      householdIdNumber: data.householdIdNumber.present
          ? data.householdIdNumber.value
          : this.householdIdNumber,
      waterSource:
          data.waterSource.present ? data.waterSource.value : this.waterSource,
      toiletFacility: data.toiletFacility.present
          ? data.toiletFacility.value
          : this.toiletFacility,
      height: data.height.present ? data.height.value : this.height,
      weight: data.weight.present ? data.weight.value : this.weight,
      allergies: data.allergies.present ? data.allergies.value : this.allergies,
      medicalHistory: data.medicalHistory.present
          ? data.medicalHistory.value
          : this.medicalHistory,
      category: data.category.present ? data.category.value : this.category,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      lastVisitDate: data.lastVisitDate.present
          ? data.lastVisitDate.value
          : this.lastVisitDate,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      syncError: data.syncError.present ? data.syncError.value : this.syncError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PatientEntity(')
          ..write('id: $id, ')
          ..write('firstName: $firstName, ')
          ..write('lastName: $lastName, ')
          ..write('middleName: $middleName, ')
          ..write('suffix: $suffix, ')
          ..write('dateOfBirth: $dateOfBirth, ')
          ..write('gender: $gender, ')
          ..write('civilStatus: $civilStatus, ')
          ..write('religion: $religion, ')
          ..write('contactNumber: $contactNumber, ')
          ..write('email: $email, ')
          ..write('address: $address, ')
          ..write('barangay: $barangay, ')
          ..write('purokSitio: $purokSitio, ')
          ..write('city: $city, ')
          ..write('province: $province, ')
          ..write('zipCode: $zipCode, ')
          ..write('philHealthNumber: $philHealthNumber, ')
          ..write('philHealthCategory: $philHealthCategory, ')
          ..write('localLguIdNumber: $localLguIdNumber, ')
          ..write('bloodType: $bloodType, ')
          ..write('emergencyContactName: $emergencyContactName, ')
          ..write('emergencyContactNumber: $emergencyContactNumber, ')
          ..write('emergencyContactRelation: $emergencyContactRelation, ')
          ..write('occupation: $occupation, ')
          ..write('employer: $employer, ')
          ..write('isPwd: $isPwd, ')
          ..write('isSoloParent: $isSoloParent, ')
          ..write('isIndigenousPerson: $isIndigenousPerson, ')
          ..write('tribeEthnolinguisticGroup: $tribeEthnolinguisticGroup, ')
          ..write('is4PsBeneficiary: $is4PsBeneficiary, ')
          ..write('householdIdNumber: $householdIdNumber, ')
          ..write('waterSource: $waterSource, ')
          ..write('toiletFacility: $toiletFacility, ')
          ..write('height: $height, ')
          ..write('weight: $weight, ')
          ..write('allergies: $allergies, ')
          ..write('medicalHistory: $medicalHistory, ')
          ..write('category: $category, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastVisitDate: $lastVisitDate, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncError: $syncError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        firstName,
        lastName,
        middleName,
        suffix,
        dateOfBirth,
        gender,
        civilStatus,
        religion,
        contactNumber,
        email,
        address,
        barangay,
        purokSitio,
        city,
        province,
        zipCode,
        philHealthNumber,
        philHealthCategory,
        localLguIdNumber,
        bloodType,
        emergencyContactName,
        emergencyContactNumber,
        emergencyContactRelation,
        occupation,
        employer,
        isPwd,
        isSoloParent,
        isIndigenousPerson,
        tribeEthnolinguisticGroup,
        is4PsBeneficiary,
        householdIdNumber,
        waterSource,
        toiletFacility,
        height,
        weight,
        allergies,
        medicalHistory,
        category,
        createdAt,
        updatedAt,
        lastVisitDate,
        syncStatus,
        syncError
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PatientEntity &&
          other.id == this.id &&
          other.firstName == this.firstName &&
          other.lastName == this.lastName &&
          other.middleName == this.middleName &&
          other.suffix == this.suffix &&
          other.dateOfBirth == this.dateOfBirth &&
          other.gender == this.gender &&
          other.civilStatus == this.civilStatus &&
          other.religion == this.religion &&
          other.contactNumber == this.contactNumber &&
          other.email == this.email &&
          other.address == this.address &&
          other.barangay == this.barangay &&
          other.purokSitio == this.purokSitio &&
          other.city == this.city &&
          other.province == this.province &&
          other.zipCode == this.zipCode &&
          other.philHealthNumber == this.philHealthNumber &&
          other.philHealthCategory == this.philHealthCategory &&
          other.localLguIdNumber == this.localLguIdNumber &&
          other.bloodType == this.bloodType &&
          other.emergencyContactName == this.emergencyContactName &&
          other.emergencyContactNumber == this.emergencyContactNumber &&
          other.emergencyContactRelation == this.emergencyContactRelation &&
          other.occupation == this.occupation &&
          other.employer == this.employer &&
          other.isPwd == this.isPwd &&
          other.isSoloParent == this.isSoloParent &&
          other.isIndigenousPerson == this.isIndigenousPerson &&
          other.tribeEthnolinguisticGroup == this.tribeEthnolinguisticGroup &&
          other.is4PsBeneficiary == this.is4PsBeneficiary &&
          other.householdIdNumber == this.householdIdNumber &&
          other.waterSource == this.waterSource &&
          other.toiletFacility == this.toiletFacility &&
          other.height == this.height &&
          other.weight == this.weight &&
          other.allergies == this.allergies &&
          other.medicalHistory == this.medicalHistory &&
          other.category == this.category &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.lastVisitDate == this.lastVisitDate &&
          other.syncStatus == this.syncStatus &&
          other.syncError == this.syncError);
}

class PatientsCompanion extends UpdateCompanion<PatientEntity> {
  final Value<String> id;
  final Value<String> firstName;
  final Value<String> lastName;
  final Value<String?> middleName;
  final Value<String?> suffix;
  final Value<DateTime?> dateOfBirth;
  final Value<String?> gender;
  final Value<String?> civilStatus;
  final Value<String?> religion;
  final Value<String?> contactNumber;
  final Value<String?> email;
  final Value<String?> address;
  final Value<String?> barangay;
  final Value<String?> purokSitio;
  final Value<String?> city;
  final Value<String?> province;
  final Value<String?> zipCode;
  final Value<String?> philHealthNumber;
  final Value<String?> philHealthCategory;
  final Value<String?> localLguIdNumber;
  final Value<String?> bloodType;
  final Value<String?> emergencyContactName;
  final Value<String?> emergencyContactNumber;
  final Value<String?> emergencyContactRelation;
  final Value<String?> occupation;
  final Value<String?> employer;
  final Value<bool> isPwd;
  final Value<bool> isSoloParent;
  final Value<bool> isIndigenousPerson;
  final Value<String?> tribeEthnolinguisticGroup;
  final Value<bool> is4PsBeneficiary;
  final Value<String?> householdIdNumber;
  final Value<String?> waterSource;
  final Value<String?> toiletFacility;
  final Value<double?> height;
  final Value<double?> weight;
  final Value<String?> allergies;
  final Value<String?> medicalHistory;
  final Value<String?> category;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<DateTime?> lastVisitDate;
  final Value<int?> syncStatus;
  final Value<String?> syncError;
  final Value<int> rowid;
  const PatientsCompanion({
    this.id = const Value.absent(),
    this.firstName = const Value.absent(),
    this.lastName = const Value.absent(),
    this.middleName = const Value.absent(),
    this.suffix = const Value.absent(),
    this.dateOfBirth = const Value.absent(),
    this.gender = const Value.absent(),
    this.civilStatus = const Value.absent(),
    this.religion = const Value.absent(),
    this.contactNumber = const Value.absent(),
    this.email = const Value.absent(),
    this.address = const Value.absent(),
    this.barangay = const Value.absent(),
    this.purokSitio = const Value.absent(),
    this.city = const Value.absent(),
    this.province = const Value.absent(),
    this.zipCode = const Value.absent(),
    this.philHealthNumber = const Value.absent(),
    this.philHealthCategory = const Value.absent(),
    this.localLguIdNumber = const Value.absent(),
    this.bloodType = const Value.absent(),
    this.emergencyContactName = const Value.absent(),
    this.emergencyContactNumber = const Value.absent(),
    this.emergencyContactRelation = const Value.absent(),
    this.occupation = const Value.absent(),
    this.employer = const Value.absent(),
    this.isPwd = const Value.absent(),
    this.isSoloParent = const Value.absent(),
    this.isIndigenousPerson = const Value.absent(),
    this.tribeEthnolinguisticGroup = const Value.absent(),
    this.is4PsBeneficiary = const Value.absent(),
    this.householdIdNumber = const Value.absent(),
    this.waterSource = const Value.absent(),
    this.toiletFacility = const Value.absent(),
    this.height = const Value.absent(),
    this.weight = const Value.absent(),
    this.allergies = const Value.absent(),
    this.medicalHistory = const Value.absent(),
    this.category = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastVisitDate = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PatientsCompanion.insert({
    required String id,
    required String firstName,
    required String lastName,
    this.middleName = const Value.absent(),
    this.suffix = const Value.absent(),
    this.dateOfBirth = const Value.absent(),
    this.gender = const Value.absent(),
    this.civilStatus = const Value.absent(),
    this.religion = const Value.absent(),
    this.contactNumber = const Value.absent(),
    this.email = const Value.absent(),
    this.address = const Value.absent(),
    this.barangay = const Value.absent(),
    this.purokSitio = const Value.absent(),
    this.city = const Value.absent(),
    this.province = const Value.absent(),
    this.zipCode = const Value.absent(),
    this.philHealthNumber = const Value.absent(),
    this.philHealthCategory = const Value.absent(),
    this.localLguIdNumber = const Value.absent(),
    this.bloodType = const Value.absent(),
    this.emergencyContactName = const Value.absent(),
    this.emergencyContactNumber = const Value.absent(),
    this.emergencyContactRelation = const Value.absent(),
    this.occupation = const Value.absent(),
    this.employer = const Value.absent(),
    this.isPwd = const Value.absent(),
    this.isSoloParent = const Value.absent(),
    this.isIndigenousPerson = const Value.absent(),
    this.tribeEthnolinguisticGroup = const Value.absent(),
    this.is4PsBeneficiary = const Value.absent(),
    this.householdIdNumber = const Value.absent(),
    this.waterSource = const Value.absent(),
    this.toiletFacility = const Value.absent(),
    this.height = const Value.absent(),
    this.weight = const Value.absent(),
    this.allergies = const Value.absent(),
    this.medicalHistory = const Value.absent(),
    this.category = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastVisitDate = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncError = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        firstName = Value(firstName),
        lastName = Value(lastName);
  static Insertable<PatientEntity> custom({
    Expression<String>? id,
    Expression<String>? firstName,
    Expression<String>? lastName,
    Expression<String>? middleName,
    Expression<String>? suffix,
    Expression<DateTime>? dateOfBirth,
    Expression<String>? gender,
    Expression<String>? civilStatus,
    Expression<String>? religion,
    Expression<String>? contactNumber,
    Expression<String>? email,
    Expression<String>? address,
    Expression<String>? barangay,
    Expression<String>? purokSitio,
    Expression<String>? city,
    Expression<String>? province,
    Expression<String>? zipCode,
    Expression<String>? philHealthNumber,
    Expression<String>? philHealthCategory,
    Expression<String>? localLguIdNumber,
    Expression<String>? bloodType,
    Expression<String>? emergencyContactName,
    Expression<String>? emergencyContactNumber,
    Expression<String>? emergencyContactRelation,
    Expression<String>? occupation,
    Expression<String>? employer,
    Expression<bool>? isPwd,
    Expression<bool>? isSoloParent,
    Expression<bool>? isIndigenousPerson,
    Expression<String>? tribeEthnolinguisticGroup,
    Expression<bool>? is4PsBeneficiary,
    Expression<String>? householdIdNumber,
    Expression<String>? waterSource,
    Expression<String>? toiletFacility,
    Expression<double>? height,
    Expression<double>? weight,
    Expression<String>? allergies,
    Expression<String>? medicalHistory,
    Expression<String>? category,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? lastVisitDate,
    Expression<int>? syncStatus,
    Expression<String>? syncError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
      if (middleName != null) 'middle_name': middleName,
      if (suffix != null) 'suffix': suffix,
      if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
      if (gender != null) 'gender': gender,
      if (civilStatus != null) 'civil_status': civilStatus,
      if (religion != null) 'religion': religion,
      if (contactNumber != null) 'contact_number': contactNumber,
      if (email != null) 'email': email,
      if (address != null) 'address': address,
      if (barangay != null) 'barangay': barangay,
      if (purokSitio != null) 'purok_sitio': purokSitio,
      if (city != null) 'city': city,
      if (province != null) 'province': province,
      if (zipCode != null) 'zip_code': zipCode,
      if (philHealthNumber != null) 'phil_health_number': philHealthNumber,
      if (philHealthCategory != null)
        'phil_health_category': philHealthCategory,
      if (localLguIdNumber != null) 'local_lgu_id_number': localLguIdNumber,
      if (bloodType != null) 'blood_type': bloodType,
      if (emergencyContactName != null)
        'emergency_contact_name': emergencyContactName,
      if (emergencyContactNumber != null)
        'emergency_contact_number': emergencyContactNumber,
      if (emergencyContactRelation != null)
        'emergency_contact_relation': emergencyContactRelation,
      if (occupation != null) 'occupation': occupation,
      if (employer != null) 'employer': employer,
      if (isPwd != null) 'is_pwd': isPwd,
      if (isSoloParent != null) 'is_solo_parent': isSoloParent,
      if (isIndigenousPerson != null)
        'is_indigenous_person': isIndigenousPerson,
      if (tribeEthnolinguisticGroup != null)
        'tribe_ethnolinguistic_group': tribeEthnolinguisticGroup,
      if (is4PsBeneficiary != null) 'is4_ps_beneficiary': is4PsBeneficiary,
      if (householdIdNumber != null) 'household_id_number': householdIdNumber,
      if (waterSource != null) 'water_source': waterSource,
      if (toiletFacility != null) 'toilet_facility': toiletFacility,
      if (height != null) 'height': height,
      if (weight != null) 'weight': weight,
      if (allergies != null) 'allergies': allergies,
      if (medicalHistory != null) 'medical_history': medicalHistory,
      if (category != null) 'category': category,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (lastVisitDate != null) 'last_visit_date': lastVisitDate,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (syncError != null) 'sync_error': syncError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PatientsCompanion copyWith(
      {Value<String>? id,
      Value<String>? firstName,
      Value<String>? lastName,
      Value<String?>? middleName,
      Value<String?>? suffix,
      Value<DateTime?>? dateOfBirth,
      Value<String?>? gender,
      Value<String?>? civilStatus,
      Value<String?>? religion,
      Value<String?>? contactNumber,
      Value<String?>? email,
      Value<String?>? address,
      Value<String?>? barangay,
      Value<String?>? purokSitio,
      Value<String?>? city,
      Value<String?>? province,
      Value<String?>? zipCode,
      Value<String?>? philHealthNumber,
      Value<String?>? philHealthCategory,
      Value<String?>? localLguIdNumber,
      Value<String?>? bloodType,
      Value<String?>? emergencyContactName,
      Value<String?>? emergencyContactNumber,
      Value<String?>? emergencyContactRelation,
      Value<String?>? occupation,
      Value<String?>? employer,
      Value<bool>? isPwd,
      Value<bool>? isSoloParent,
      Value<bool>? isIndigenousPerson,
      Value<String?>? tribeEthnolinguisticGroup,
      Value<bool>? is4PsBeneficiary,
      Value<String?>? householdIdNumber,
      Value<String?>? waterSource,
      Value<String?>? toiletFacility,
      Value<double?>? height,
      Value<double?>? weight,
      Value<String?>? allergies,
      Value<String?>? medicalHistory,
      Value<String?>? category,
      Value<DateTime?>? createdAt,
      Value<DateTime?>? updatedAt,
      Value<DateTime?>? lastVisitDate,
      Value<int?>? syncStatus,
      Value<String?>? syncError,
      Value<int>? rowid}) {
    return PatientsCompanion(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      middleName: middleName ?? this.middleName,
      suffix: suffix ?? this.suffix,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      civilStatus: civilStatus ?? this.civilStatus,
      religion: religion ?? this.religion,
      contactNumber: contactNumber ?? this.contactNumber,
      email: email ?? this.email,
      address: address ?? this.address,
      barangay: barangay ?? this.barangay,
      purokSitio: purokSitio ?? this.purokSitio,
      city: city ?? this.city,
      province: province ?? this.province,
      zipCode: zipCode ?? this.zipCode,
      philHealthNumber: philHealthNumber ?? this.philHealthNumber,
      philHealthCategory: philHealthCategory ?? this.philHealthCategory,
      localLguIdNumber: localLguIdNumber ?? this.localLguIdNumber,
      bloodType: bloodType ?? this.bloodType,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactNumber:
          emergencyContactNumber ?? this.emergencyContactNumber,
      emergencyContactRelation:
          emergencyContactRelation ?? this.emergencyContactRelation,
      occupation: occupation ?? this.occupation,
      employer: employer ?? this.employer,
      isPwd: isPwd ?? this.isPwd,
      isSoloParent: isSoloParent ?? this.isSoloParent,
      isIndigenousPerson: isIndigenousPerson ?? this.isIndigenousPerson,
      tribeEthnolinguisticGroup:
          tribeEthnolinguisticGroup ?? this.tribeEthnolinguisticGroup,
      is4PsBeneficiary: is4PsBeneficiary ?? this.is4PsBeneficiary,
      householdIdNumber: householdIdNumber ?? this.householdIdNumber,
      waterSource: waterSource ?? this.waterSource,
      toiletFacility: toiletFacility ?? this.toiletFacility,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      allergies: allergies ?? this.allergies,
      medicalHistory: medicalHistory ?? this.medicalHistory,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastVisitDate: lastVisitDate ?? this.lastVisitDate,
      syncStatus: syncStatus ?? this.syncStatus,
      syncError: syncError ?? this.syncError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (firstName.present) {
      map['first_name'] = Variable<String>(firstName.value);
    }
    if (lastName.present) {
      map['last_name'] = Variable<String>(lastName.value);
    }
    if (middleName.present) {
      map['middle_name'] = Variable<String>(middleName.value);
    }
    if (suffix.present) {
      map['suffix'] = Variable<String>(suffix.value);
    }
    if (dateOfBirth.present) {
      map['date_of_birth'] = Variable<DateTime>(dateOfBirth.value);
    }
    if (gender.present) {
      map['gender'] = Variable<String>(gender.value);
    }
    if (civilStatus.present) {
      map['civil_status'] = Variable<String>(civilStatus.value);
    }
    if (religion.present) {
      map['religion'] = Variable<String>(religion.value);
    }
    if (contactNumber.present) {
      map['contact_number'] = Variable<String>(contactNumber.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (barangay.present) {
      map['barangay'] = Variable<String>(barangay.value);
    }
    if (purokSitio.present) {
      map['purok_sitio'] = Variable<String>(purokSitio.value);
    }
    if (city.present) {
      map['city'] = Variable<String>(city.value);
    }
    if (province.present) {
      map['province'] = Variable<String>(province.value);
    }
    if (zipCode.present) {
      map['zip_code'] = Variable<String>(zipCode.value);
    }
    if (philHealthNumber.present) {
      map['phil_health_number'] = Variable<String>(philHealthNumber.value);
    }
    if (philHealthCategory.present) {
      map['phil_health_category'] = Variable<String>(philHealthCategory.value);
    }
    if (localLguIdNumber.present) {
      map['local_lgu_id_number'] = Variable<String>(localLguIdNumber.value);
    }
    if (bloodType.present) {
      map['blood_type'] = Variable<String>(bloodType.value);
    }
    if (emergencyContactName.present) {
      map['emergency_contact_name'] =
          Variable<String>(emergencyContactName.value);
    }
    if (emergencyContactNumber.present) {
      map['emergency_contact_number'] =
          Variable<String>(emergencyContactNumber.value);
    }
    if (emergencyContactRelation.present) {
      map['emergency_contact_relation'] =
          Variable<String>(emergencyContactRelation.value);
    }
    if (occupation.present) {
      map['occupation'] = Variable<String>(occupation.value);
    }
    if (employer.present) {
      map['employer'] = Variable<String>(employer.value);
    }
    if (isPwd.present) {
      map['is_pwd'] = Variable<bool>(isPwd.value);
    }
    if (isSoloParent.present) {
      map['is_solo_parent'] = Variable<bool>(isSoloParent.value);
    }
    if (isIndigenousPerson.present) {
      map['is_indigenous_person'] = Variable<bool>(isIndigenousPerson.value);
    }
    if (tribeEthnolinguisticGroup.present) {
      map['tribe_ethnolinguistic_group'] =
          Variable<String>(tribeEthnolinguisticGroup.value);
    }
    if (is4PsBeneficiary.present) {
      map['is4_ps_beneficiary'] = Variable<bool>(is4PsBeneficiary.value);
    }
    if (householdIdNumber.present) {
      map['household_id_number'] = Variable<String>(householdIdNumber.value);
    }
    if (waterSource.present) {
      map['water_source'] = Variable<String>(waterSource.value);
    }
    if (toiletFacility.present) {
      map['toilet_facility'] = Variable<String>(toiletFacility.value);
    }
    if (height.present) {
      map['height'] = Variable<double>(height.value);
    }
    if (weight.present) {
      map['weight'] = Variable<double>(weight.value);
    }
    if (allergies.present) {
      map['allergies'] = Variable<String>(allergies.value);
    }
    if (medicalHistory.present) {
      map['medical_history'] = Variable<String>(medicalHistory.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (lastVisitDate.present) {
      map['last_visit_date'] = Variable<DateTime>(lastVisitDate.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    if (syncError.present) {
      map['sync_error'] = Variable<String>(syncError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PatientsCompanion(')
          ..write('id: $id, ')
          ..write('firstName: $firstName, ')
          ..write('lastName: $lastName, ')
          ..write('middleName: $middleName, ')
          ..write('suffix: $suffix, ')
          ..write('dateOfBirth: $dateOfBirth, ')
          ..write('gender: $gender, ')
          ..write('civilStatus: $civilStatus, ')
          ..write('religion: $religion, ')
          ..write('contactNumber: $contactNumber, ')
          ..write('email: $email, ')
          ..write('address: $address, ')
          ..write('barangay: $barangay, ')
          ..write('purokSitio: $purokSitio, ')
          ..write('city: $city, ')
          ..write('province: $province, ')
          ..write('zipCode: $zipCode, ')
          ..write('philHealthNumber: $philHealthNumber, ')
          ..write('philHealthCategory: $philHealthCategory, ')
          ..write('localLguIdNumber: $localLguIdNumber, ')
          ..write('bloodType: $bloodType, ')
          ..write('emergencyContactName: $emergencyContactName, ')
          ..write('emergencyContactNumber: $emergencyContactNumber, ')
          ..write('emergencyContactRelation: $emergencyContactRelation, ')
          ..write('occupation: $occupation, ')
          ..write('employer: $employer, ')
          ..write('isPwd: $isPwd, ')
          ..write('isSoloParent: $isSoloParent, ')
          ..write('isIndigenousPerson: $isIndigenousPerson, ')
          ..write('tribeEthnolinguisticGroup: $tribeEthnolinguisticGroup, ')
          ..write('is4PsBeneficiary: $is4PsBeneficiary, ')
          ..write('householdIdNumber: $householdIdNumber, ')
          ..write('waterSource: $waterSource, ')
          ..write('toiletFacility: $toiletFacility, ')
          ..write('height: $height, ')
          ..write('weight: $weight, ')
          ..write('allergies: $allergies, ')
          ..write('medicalHistory: $medicalHistory, ')
          ..write('category: $category, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastVisitDate: $lastVisitDate, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncError: $syncError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QueueItemsTable extends QueueItems
    with TableInfo<$QueueItemsTable, QueueItemEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QueueItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _patientIdMeta =
      const VerificationMeta('patientId');
  @override
  late final GeneratedColumn<String> patientId = GeneratedColumn<String>(
      'patient_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _priorityMeta =
      const VerificationMeta('priority');
  @override
  late final GeneratedColumn<String> priority = GeneratedColumn<String>(
      'priority', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nurseIdMeta =
      const VerificationMeta('nurseId');
  @override
  late final GeneratedColumn<String> nurseId = GeneratedColumn<String>(
      'nurse_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _roomNumberMeta =
      const VerificationMeta('roomNumber');
  @override
  late final GeneratedColumn<String> roomNumber = GeneratedColumn<String>(
      'room_number', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _vitalsBpMeta =
      const VerificationMeta('vitalsBp');
  @override
  late final GeneratedColumn<String> vitalsBp = GeneratedColumn<String>(
      'vitals_bp', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _vitalsWeightMeta =
      const VerificationMeta('vitalsWeight');
  @override
  late final GeneratedColumn<double> vitalsWeight = GeneratedColumn<double>(
      'vitals_weight', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _vitalsTemperatureMeta =
      const VerificationMeta('vitalsTemperature');
  @override
  late final GeneratedColumn<double> vitalsTemperature =
      GeneratedColumn<double>('vitals_temperature', aliasedName, true,
          type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _vitalsNotesMeta =
      const VerificationMeta('vitalsNotes');
  @override
  late final GeneratedColumn<String> vitalsNotes = GeneratedColumn<String>(
      'vitals_notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _arrivalTimeMeta =
      const VerificationMeta('arrivalTime');
  @override
  late final GeneratedColumn<DateTime> arrivalTime = GeneratedColumn<DateTime>(
      'arrival_time', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _startTimeMeta =
      const VerificationMeta('startTime');
  @override
  late final GeneratedColumn<DateTime> startTime = GeneratedColumn<DateTime>(
      'start_time', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _endTimeMeta =
      const VerificationMeta('endTime');
  @override
  late final GeneratedColumn<DateTime> endTime = GeneratedColumn<DateTime>(
      'end_time', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        patientId,
        status,
        priority,
        nurseId,
        roomNumber,
        category,
        vitalsBp,
        vitalsWeight,
        vitalsTemperature,
        vitalsNotes,
        arrivalTime,
        startTime,
        endTime,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'queue_items';
  @override
  VerificationContext validateIntegrity(Insertable<QueueItemEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('patient_id')) {
      context.handle(_patientIdMeta,
          patientId.isAcceptableOrUnknown(data['patient_id']!, _patientIdMeta));
    } else if (isInserting) {
      context.missing(_patientIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('priority')) {
      context.handle(_priorityMeta,
          priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta));
    } else if (isInserting) {
      context.missing(_priorityMeta);
    }
    if (data.containsKey('nurse_id')) {
      context.handle(_nurseIdMeta,
          nurseId.isAcceptableOrUnknown(data['nurse_id']!, _nurseIdMeta));
    }
    if (data.containsKey('room_number')) {
      context.handle(
          _roomNumberMeta,
          roomNumber.isAcceptableOrUnknown(
              data['room_number']!, _roomNumberMeta));
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    if (data.containsKey('vitals_bp')) {
      context.handle(_vitalsBpMeta,
          vitalsBp.isAcceptableOrUnknown(data['vitals_bp']!, _vitalsBpMeta));
    }
    if (data.containsKey('vitals_weight')) {
      context.handle(
          _vitalsWeightMeta,
          vitalsWeight.isAcceptableOrUnknown(
              data['vitals_weight']!, _vitalsWeightMeta));
    }
    if (data.containsKey('vitals_temperature')) {
      context.handle(
          _vitalsTemperatureMeta,
          vitalsTemperature.isAcceptableOrUnknown(
              data['vitals_temperature']!, _vitalsTemperatureMeta));
    }
    if (data.containsKey('vitals_notes')) {
      context.handle(
          _vitalsNotesMeta,
          vitalsNotes.isAcceptableOrUnknown(
              data['vitals_notes']!, _vitalsNotesMeta));
    }
    if (data.containsKey('arrival_time')) {
      context.handle(
          _arrivalTimeMeta,
          arrivalTime.isAcceptableOrUnknown(
              data['arrival_time']!, _arrivalTimeMeta));
    } else if (isInserting) {
      context.missing(_arrivalTimeMeta);
    }
    if (data.containsKey('start_time')) {
      context.handle(_startTimeMeta,
          startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta));
    }
    if (data.containsKey('end_time')) {
      context.handle(_endTimeMeta,
          endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  QueueItemEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QueueItemEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      patientId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}patient_id'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      priority: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}priority'])!,
      nurseId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}nurse_id']),
      roomNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}room_number']),
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category']),
      vitalsBp: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}vitals_bp']),
      vitalsWeight: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}vitals_weight']),
      vitalsTemperature: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}vitals_temperature']),
      vitalsNotes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}vitals_notes']),
      arrivalTime: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}arrival_time'])!,
      startTime: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}start_time']),
      endTime: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}end_time']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $QueueItemsTable createAlias(String alias) {
    return $QueueItemsTable(attachedDatabase, alias);
  }
}

class QueueItemEntity extends DataClass implements Insertable<QueueItemEntity> {
  final String id;
  final String patientId;
  final String status;
  final String priority;
  final String? nurseId;
  final String? roomNumber;
  final String? category;
  final String? vitalsBp;
  final double? vitalsWeight;
  final double? vitalsTemperature;
  final String? vitalsNotes;
  final DateTime arrivalTime;
  final DateTime? startTime;
  final DateTime? endTime;
  final DateTime createdAt;
  final DateTime updatedAt;
  const QueueItemEntity(
      {required this.id,
      required this.patientId,
      required this.status,
      required this.priority,
      this.nurseId,
      this.roomNumber,
      this.category,
      this.vitalsBp,
      this.vitalsWeight,
      this.vitalsTemperature,
      this.vitalsNotes,
      required this.arrivalTime,
      this.startTime,
      this.endTime,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['patient_id'] = Variable<String>(patientId);
    map['status'] = Variable<String>(status);
    map['priority'] = Variable<String>(priority);
    if (!nullToAbsent || nurseId != null) {
      map['nurse_id'] = Variable<String>(nurseId);
    }
    if (!nullToAbsent || roomNumber != null) {
      map['room_number'] = Variable<String>(roomNumber);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    if (!nullToAbsent || vitalsBp != null) {
      map['vitals_bp'] = Variable<String>(vitalsBp);
    }
    if (!nullToAbsent || vitalsWeight != null) {
      map['vitals_weight'] = Variable<double>(vitalsWeight);
    }
    if (!nullToAbsent || vitalsTemperature != null) {
      map['vitals_temperature'] = Variable<double>(vitalsTemperature);
    }
    if (!nullToAbsent || vitalsNotes != null) {
      map['vitals_notes'] = Variable<String>(vitalsNotes);
    }
    map['arrival_time'] = Variable<DateTime>(arrivalTime);
    if (!nullToAbsent || startTime != null) {
      map['start_time'] = Variable<DateTime>(startTime);
    }
    if (!nullToAbsent || endTime != null) {
      map['end_time'] = Variable<DateTime>(endTime);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  QueueItemsCompanion toCompanion(bool nullToAbsent) {
    return QueueItemsCompanion(
      id: Value(id),
      patientId: Value(patientId),
      status: Value(status),
      priority: Value(priority),
      nurseId: nurseId == null && nullToAbsent
          ? const Value.absent()
          : Value(nurseId),
      roomNumber: roomNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(roomNumber),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      vitalsBp: vitalsBp == null && nullToAbsent
          ? const Value.absent()
          : Value(vitalsBp),
      vitalsWeight: vitalsWeight == null && nullToAbsent
          ? const Value.absent()
          : Value(vitalsWeight),
      vitalsTemperature: vitalsTemperature == null && nullToAbsent
          ? const Value.absent()
          : Value(vitalsTemperature),
      vitalsNotes: vitalsNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(vitalsNotes),
      arrivalTime: Value(arrivalTime),
      startTime: startTime == null && nullToAbsent
          ? const Value.absent()
          : Value(startTime),
      endTime: endTime == null && nullToAbsent
          ? const Value.absent()
          : Value(endTime),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory QueueItemEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QueueItemEntity(
      id: serializer.fromJson<String>(json['id']),
      patientId: serializer.fromJson<String>(json['patientId']),
      status: serializer.fromJson<String>(json['status']),
      priority: serializer.fromJson<String>(json['priority']),
      nurseId: serializer.fromJson<String?>(json['nurseId']),
      roomNumber: serializer.fromJson<String?>(json['roomNumber']),
      category: serializer.fromJson<String?>(json['category']),
      vitalsBp: serializer.fromJson<String?>(json['vitalsBp']),
      vitalsWeight: serializer.fromJson<double?>(json['vitalsWeight']),
      vitalsTemperature:
          serializer.fromJson<double?>(json['vitalsTemperature']),
      vitalsNotes: serializer.fromJson<String?>(json['vitalsNotes']),
      arrivalTime: serializer.fromJson<DateTime>(json['arrivalTime']),
      startTime: serializer.fromJson<DateTime?>(json['startTime']),
      endTime: serializer.fromJson<DateTime?>(json['endTime']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'patientId': serializer.toJson<String>(patientId),
      'status': serializer.toJson<String>(status),
      'priority': serializer.toJson<String>(priority),
      'nurseId': serializer.toJson<String?>(nurseId),
      'roomNumber': serializer.toJson<String?>(roomNumber),
      'category': serializer.toJson<String?>(category),
      'vitalsBp': serializer.toJson<String?>(vitalsBp),
      'vitalsWeight': serializer.toJson<double?>(vitalsWeight),
      'vitalsTemperature': serializer.toJson<double?>(vitalsTemperature),
      'vitalsNotes': serializer.toJson<String?>(vitalsNotes),
      'arrivalTime': serializer.toJson<DateTime>(arrivalTime),
      'startTime': serializer.toJson<DateTime?>(startTime),
      'endTime': serializer.toJson<DateTime?>(endTime),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  QueueItemEntity copyWith(
          {String? id,
          String? patientId,
          String? status,
          String? priority,
          Value<String?> nurseId = const Value.absent(),
          Value<String?> roomNumber = const Value.absent(),
          Value<String?> category = const Value.absent(),
          Value<String?> vitalsBp = const Value.absent(),
          Value<double?> vitalsWeight = const Value.absent(),
          Value<double?> vitalsTemperature = const Value.absent(),
          Value<String?> vitalsNotes = const Value.absent(),
          DateTime? arrivalTime,
          Value<DateTime?> startTime = const Value.absent(),
          Value<DateTime?> endTime = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      QueueItemEntity(
        id: id ?? this.id,
        patientId: patientId ?? this.patientId,
        status: status ?? this.status,
        priority: priority ?? this.priority,
        nurseId: nurseId.present ? nurseId.value : this.nurseId,
        roomNumber: roomNumber.present ? roomNumber.value : this.roomNumber,
        category: category.present ? category.value : this.category,
        vitalsBp: vitalsBp.present ? vitalsBp.value : this.vitalsBp,
        vitalsWeight:
            vitalsWeight.present ? vitalsWeight.value : this.vitalsWeight,
        vitalsTemperature: vitalsTemperature.present
            ? vitalsTemperature.value
            : this.vitalsTemperature,
        vitalsNotes: vitalsNotes.present ? vitalsNotes.value : this.vitalsNotes,
        arrivalTime: arrivalTime ?? this.arrivalTime,
        startTime: startTime.present ? startTime.value : this.startTime,
        endTime: endTime.present ? endTime.value : this.endTime,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  QueueItemEntity copyWithCompanion(QueueItemsCompanion data) {
    return QueueItemEntity(
      id: data.id.present ? data.id.value : this.id,
      patientId: data.patientId.present ? data.patientId.value : this.patientId,
      status: data.status.present ? data.status.value : this.status,
      priority: data.priority.present ? data.priority.value : this.priority,
      nurseId: data.nurseId.present ? data.nurseId.value : this.nurseId,
      roomNumber:
          data.roomNumber.present ? data.roomNumber.value : this.roomNumber,
      category: data.category.present ? data.category.value : this.category,
      vitalsBp: data.vitalsBp.present ? data.vitalsBp.value : this.vitalsBp,
      vitalsWeight: data.vitalsWeight.present
          ? data.vitalsWeight.value
          : this.vitalsWeight,
      vitalsTemperature: data.vitalsTemperature.present
          ? data.vitalsTemperature.value
          : this.vitalsTemperature,
      vitalsNotes:
          data.vitalsNotes.present ? data.vitalsNotes.value : this.vitalsNotes,
      arrivalTime:
          data.arrivalTime.present ? data.arrivalTime.value : this.arrivalTime,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QueueItemEntity(')
          ..write('id: $id, ')
          ..write('patientId: $patientId, ')
          ..write('status: $status, ')
          ..write('priority: $priority, ')
          ..write('nurseId: $nurseId, ')
          ..write('roomNumber: $roomNumber, ')
          ..write('category: $category, ')
          ..write('vitalsBp: $vitalsBp, ')
          ..write('vitalsWeight: $vitalsWeight, ')
          ..write('vitalsTemperature: $vitalsTemperature, ')
          ..write('vitalsNotes: $vitalsNotes, ')
          ..write('arrivalTime: $arrivalTime, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      patientId,
      status,
      priority,
      nurseId,
      roomNumber,
      category,
      vitalsBp,
      vitalsWeight,
      vitalsTemperature,
      vitalsNotes,
      arrivalTime,
      startTime,
      endTime,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QueueItemEntity &&
          other.id == this.id &&
          other.patientId == this.patientId &&
          other.status == this.status &&
          other.priority == this.priority &&
          other.nurseId == this.nurseId &&
          other.roomNumber == this.roomNumber &&
          other.category == this.category &&
          other.vitalsBp == this.vitalsBp &&
          other.vitalsWeight == this.vitalsWeight &&
          other.vitalsTemperature == this.vitalsTemperature &&
          other.vitalsNotes == this.vitalsNotes &&
          other.arrivalTime == this.arrivalTime &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class QueueItemsCompanion extends UpdateCompanion<QueueItemEntity> {
  final Value<String> id;
  final Value<String> patientId;
  final Value<String> status;
  final Value<String> priority;
  final Value<String?> nurseId;
  final Value<String?> roomNumber;
  final Value<String?> category;
  final Value<String?> vitalsBp;
  final Value<double?> vitalsWeight;
  final Value<double?> vitalsTemperature;
  final Value<String?> vitalsNotes;
  final Value<DateTime> arrivalTime;
  final Value<DateTime?> startTime;
  final Value<DateTime?> endTime;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const QueueItemsCompanion({
    this.id = const Value.absent(),
    this.patientId = const Value.absent(),
    this.status = const Value.absent(),
    this.priority = const Value.absent(),
    this.nurseId = const Value.absent(),
    this.roomNumber = const Value.absent(),
    this.category = const Value.absent(),
    this.vitalsBp = const Value.absent(),
    this.vitalsWeight = const Value.absent(),
    this.vitalsTemperature = const Value.absent(),
    this.vitalsNotes = const Value.absent(),
    this.arrivalTime = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QueueItemsCompanion.insert({
    required String id,
    required String patientId,
    required String status,
    required String priority,
    this.nurseId = const Value.absent(),
    this.roomNumber = const Value.absent(),
    this.category = const Value.absent(),
    this.vitalsBp = const Value.absent(),
    this.vitalsWeight = const Value.absent(),
    this.vitalsTemperature = const Value.absent(),
    this.vitalsNotes = const Value.absent(),
    required DateTime arrivalTime,
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        patientId = Value(patientId),
        status = Value(status),
        priority = Value(priority),
        arrivalTime = Value(arrivalTime),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<QueueItemEntity> custom({
    Expression<String>? id,
    Expression<String>? patientId,
    Expression<String>? status,
    Expression<String>? priority,
    Expression<String>? nurseId,
    Expression<String>? roomNumber,
    Expression<String>? category,
    Expression<String>? vitalsBp,
    Expression<double>? vitalsWeight,
    Expression<double>? vitalsTemperature,
    Expression<String>? vitalsNotes,
    Expression<DateTime>? arrivalTime,
    Expression<DateTime>? startTime,
    Expression<DateTime>? endTime,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (patientId != null) 'patient_id': patientId,
      if (status != null) 'status': status,
      if (priority != null) 'priority': priority,
      if (nurseId != null) 'nurse_id': nurseId,
      if (roomNumber != null) 'room_number': roomNumber,
      if (category != null) 'category': category,
      if (vitalsBp != null) 'vitals_bp': vitalsBp,
      if (vitalsWeight != null) 'vitals_weight': vitalsWeight,
      if (vitalsTemperature != null) 'vitals_temperature': vitalsTemperature,
      if (vitalsNotes != null) 'vitals_notes': vitalsNotes,
      if (arrivalTime != null) 'arrival_time': arrivalTime,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QueueItemsCompanion copyWith(
      {Value<String>? id,
      Value<String>? patientId,
      Value<String>? status,
      Value<String>? priority,
      Value<String?>? nurseId,
      Value<String?>? roomNumber,
      Value<String?>? category,
      Value<String?>? vitalsBp,
      Value<double?>? vitalsWeight,
      Value<double?>? vitalsTemperature,
      Value<String?>? vitalsNotes,
      Value<DateTime>? arrivalTime,
      Value<DateTime?>? startTime,
      Value<DateTime?>? endTime,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return QueueItemsCompanion(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      nurseId: nurseId ?? this.nurseId,
      roomNumber: roomNumber ?? this.roomNumber,
      category: category ?? this.category,
      vitalsBp: vitalsBp ?? this.vitalsBp,
      vitalsWeight: vitalsWeight ?? this.vitalsWeight,
      vitalsTemperature: vitalsTemperature ?? this.vitalsTemperature,
      vitalsNotes: vitalsNotes ?? this.vitalsNotes,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (patientId.present) {
      map['patient_id'] = Variable<String>(patientId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (priority.present) {
      map['priority'] = Variable<String>(priority.value);
    }
    if (nurseId.present) {
      map['nurse_id'] = Variable<String>(nurseId.value);
    }
    if (roomNumber.present) {
      map['room_number'] = Variable<String>(roomNumber.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (vitalsBp.present) {
      map['vitals_bp'] = Variable<String>(vitalsBp.value);
    }
    if (vitalsWeight.present) {
      map['vitals_weight'] = Variable<double>(vitalsWeight.value);
    }
    if (vitalsTemperature.present) {
      map['vitals_temperature'] = Variable<double>(vitalsTemperature.value);
    }
    if (vitalsNotes.present) {
      map['vitals_notes'] = Variable<String>(vitalsNotes.value);
    }
    if (arrivalTime.present) {
      map['arrival_time'] = Variable<DateTime>(arrivalTime.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<DateTime>(startTime.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<DateTime>(endTime.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QueueItemsCompanion(')
          ..write('id: $id, ')
          ..write('patientId: $patientId, ')
          ..write('status: $status, ')
          ..write('priority: $priority, ')
          ..write('nurseId: $nurseId, ')
          ..write('roomNumber: $roomNumber, ')
          ..write('category: $category, ')
          ..write('vitalsBp: $vitalsBp, ')
          ..write('vitalsWeight: $vitalsWeight, ')
          ..write('vitalsTemperature: $vitalsTemperature, ')
          ..write('vitalsNotes: $vitalsNotes, ')
          ..write('arrivalTime: $arrivalTime, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConsultationsTable extends Consultations
    with TableInfo<$ConsultationsTable, ConsultationEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConsultationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _patientIdMeta =
      const VerificationMeta('patientId');
  @override
  late final GeneratedColumn<String> patientId = GeneratedColumn<String>(
      'patient_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _queueIdMeta =
      const VerificationMeta('queueId');
  @override
  late final GeneratedColumn<String> queueId = GeneratedColumn<String>(
      'queue_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _subjectiveMeta =
      const VerificationMeta('subjective');
  @override
  late final GeneratedColumn<String> subjective = GeneratedColumn<String>(
      'subjective', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _objectiveMeta =
      const VerificationMeta('objective');
  @override
  late final GeneratedColumn<String> objective = GeneratedColumn<String>(
      'objective', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _assessmentMeta =
      const VerificationMeta('assessment');
  @override
  late final GeneratedColumn<String> assessment = GeneratedColumn<String>(
      'assessment', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _planMeta = const VerificationMeta('plan');
  @override
  late final GeneratedColumn<String> plan = GeneratedColumn<String>(
      'plan', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _icd10CodeMeta =
      const VerificationMeta('icd10Code');
  @override
  late final GeneratedColumn<String> icd10Code = GeneratedColumn<String>(
      'icd10_code', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdByMeta =
      const VerificationMeta('createdBy');
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
      'created_by', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        patientId,
        queueId,
        subjective,
        objective,
        assessment,
        plan,
        icd10Code,
        createdBy,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'consultations';
  @override
  VerificationContext validateIntegrity(Insertable<ConsultationEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('patient_id')) {
      context.handle(_patientIdMeta,
          patientId.isAcceptableOrUnknown(data['patient_id']!, _patientIdMeta));
    } else if (isInserting) {
      context.missing(_patientIdMeta);
    }
    if (data.containsKey('queue_id')) {
      context.handle(_queueIdMeta,
          queueId.isAcceptableOrUnknown(data['queue_id']!, _queueIdMeta));
    }
    if (data.containsKey('subjective')) {
      context.handle(
          _subjectiveMeta,
          subjective.isAcceptableOrUnknown(
              data['subjective']!, _subjectiveMeta));
    }
    if (data.containsKey('objective')) {
      context.handle(_objectiveMeta,
          objective.isAcceptableOrUnknown(data['objective']!, _objectiveMeta));
    }
    if (data.containsKey('assessment')) {
      context.handle(
          _assessmentMeta,
          assessment.isAcceptableOrUnknown(
              data['assessment']!, _assessmentMeta));
    }
    if (data.containsKey('plan')) {
      context.handle(
          _planMeta, plan.isAcceptableOrUnknown(data['plan']!, _planMeta));
    }
    if (data.containsKey('icd10_code')) {
      context.handle(_icd10CodeMeta,
          icd10Code.isAcceptableOrUnknown(data['icd10_code']!, _icd10CodeMeta));
    }
    if (data.containsKey('created_by')) {
      context.handle(_createdByMeta,
          createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta));
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConsultationEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConsultationEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      patientId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}patient_id'])!,
      queueId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}queue_id']),
      subjective: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}subjective']),
      objective: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}objective']),
      assessment: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}assessment']),
      plan: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}plan']),
      icd10Code: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icd10_code']),
      createdBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_by'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ConsultationsTable createAlias(String alias) {
    return $ConsultationsTable(attachedDatabase, alias);
  }
}

class ConsultationEntity extends DataClass
    implements Insertable<ConsultationEntity> {
  final String id;
  final String patientId;
  final String? queueId;
  final String? subjective;
  final String? objective;
  final String? assessment;
  final String? plan;
  final String? icd10Code;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ConsultationEntity(
      {required this.id,
      required this.patientId,
      this.queueId,
      this.subjective,
      this.objective,
      this.assessment,
      this.plan,
      this.icd10Code,
      required this.createdBy,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['patient_id'] = Variable<String>(patientId);
    if (!nullToAbsent || queueId != null) {
      map['queue_id'] = Variable<String>(queueId);
    }
    if (!nullToAbsent || subjective != null) {
      map['subjective'] = Variable<String>(subjective);
    }
    if (!nullToAbsent || objective != null) {
      map['objective'] = Variable<String>(objective);
    }
    if (!nullToAbsent || assessment != null) {
      map['assessment'] = Variable<String>(assessment);
    }
    if (!nullToAbsent || plan != null) {
      map['plan'] = Variable<String>(plan);
    }
    if (!nullToAbsent || icd10Code != null) {
      map['icd10_code'] = Variable<String>(icd10Code);
    }
    map['created_by'] = Variable<String>(createdBy);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ConsultationsCompanion toCompanion(bool nullToAbsent) {
    return ConsultationsCompanion(
      id: Value(id),
      patientId: Value(patientId),
      queueId: queueId == null && nullToAbsent
          ? const Value.absent()
          : Value(queueId),
      subjective: subjective == null && nullToAbsent
          ? const Value.absent()
          : Value(subjective),
      objective: objective == null && nullToAbsent
          ? const Value.absent()
          : Value(objective),
      assessment: assessment == null && nullToAbsent
          ? const Value.absent()
          : Value(assessment),
      plan: plan == null && nullToAbsent ? const Value.absent() : Value(plan),
      icd10Code: icd10Code == null && nullToAbsent
          ? const Value.absent()
          : Value(icd10Code),
      createdBy: Value(createdBy),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ConsultationEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConsultationEntity(
      id: serializer.fromJson<String>(json['id']),
      patientId: serializer.fromJson<String>(json['patientId']),
      queueId: serializer.fromJson<String?>(json['queueId']),
      subjective: serializer.fromJson<String?>(json['subjective']),
      objective: serializer.fromJson<String?>(json['objective']),
      assessment: serializer.fromJson<String?>(json['assessment']),
      plan: serializer.fromJson<String?>(json['plan']),
      icd10Code: serializer.fromJson<String?>(json['icd10Code']),
      createdBy: serializer.fromJson<String>(json['createdBy']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'patientId': serializer.toJson<String>(patientId),
      'queueId': serializer.toJson<String?>(queueId),
      'subjective': serializer.toJson<String?>(subjective),
      'objective': serializer.toJson<String?>(objective),
      'assessment': serializer.toJson<String?>(assessment),
      'plan': serializer.toJson<String?>(plan),
      'icd10Code': serializer.toJson<String?>(icd10Code),
      'createdBy': serializer.toJson<String>(createdBy),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ConsultationEntity copyWith(
          {String? id,
          String? patientId,
          Value<String?> queueId = const Value.absent(),
          Value<String?> subjective = const Value.absent(),
          Value<String?> objective = const Value.absent(),
          Value<String?> assessment = const Value.absent(),
          Value<String?> plan = const Value.absent(),
          Value<String?> icd10Code = const Value.absent(),
          String? createdBy,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      ConsultationEntity(
        id: id ?? this.id,
        patientId: patientId ?? this.patientId,
        queueId: queueId.present ? queueId.value : this.queueId,
        subjective: subjective.present ? subjective.value : this.subjective,
        objective: objective.present ? objective.value : this.objective,
        assessment: assessment.present ? assessment.value : this.assessment,
        plan: plan.present ? plan.value : this.plan,
        icd10Code: icd10Code.present ? icd10Code.value : this.icd10Code,
        createdBy: createdBy ?? this.createdBy,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  ConsultationEntity copyWithCompanion(ConsultationsCompanion data) {
    return ConsultationEntity(
      id: data.id.present ? data.id.value : this.id,
      patientId: data.patientId.present ? data.patientId.value : this.patientId,
      queueId: data.queueId.present ? data.queueId.value : this.queueId,
      subjective:
          data.subjective.present ? data.subjective.value : this.subjective,
      objective: data.objective.present ? data.objective.value : this.objective,
      assessment:
          data.assessment.present ? data.assessment.value : this.assessment,
      plan: data.plan.present ? data.plan.value : this.plan,
      icd10Code: data.icd10Code.present ? data.icd10Code.value : this.icd10Code,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConsultationEntity(')
          ..write('id: $id, ')
          ..write('patientId: $patientId, ')
          ..write('queueId: $queueId, ')
          ..write('subjective: $subjective, ')
          ..write('objective: $objective, ')
          ..write('assessment: $assessment, ')
          ..write('plan: $plan, ')
          ..write('icd10Code: $icd10Code, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, patientId, queueId, subjective, objective,
      assessment, plan, icd10Code, createdBy, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConsultationEntity &&
          other.id == this.id &&
          other.patientId == this.patientId &&
          other.queueId == this.queueId &&
          other.subjective == this.subjective &&
          other.objective == this.objective &&
          other.assessment == this.assessment &&
          other.plan == this.plan &&
          other.icd10Code == this.icd10Code &&
          other.createdBy == this.createdBy &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ConsultationsCompanion extends UpdateCompanion<ConsultationEntity> {
  final Value<String> id;
  final Value<String> patientId;
  final Value<String?> queueId;
  final Value<String?> subjective;
  final Value<String?> objective;
  final Value<String?> assessment;
  final Value<String?> plan;
  final Value<String?> icd10Code;
  final Value<String> createdBy;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ConsultationsCompanion({
    this.id = const Value.absent(),
    this.patientId = const Value.absent(),
    this.queueId = const Value.absent(),
    this.subjective = const Value.absent(),
    this.objective = const Value.absent(),
    this.assessment = const Value.absent(),
    this.plan = const Value.absent(),
    this.icd10Code = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConsultationsCompanion.insert({
    required String id,
    required String patientId,
    this.queueId = const Value.absent(),
    this.subjective = const Value.absent(),
    this.objective = const Value.absent(),
    this.assessment = const Value.absent(),
    this.plan = const Value.absent(),
    this.icd10Code = const Value.absent(),
    required String createdBy,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        patientId = Value(patientId),
        createdBy = Value(createdBy),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<ConsultationEntity> custom({
    Expression<String>? id,
    Expression<String>? patientId,
    Expression<String>? queueId,
    Expression<String>? subjective,
    Expression<String>? objective,
    Expression<String>? assessment,
    Expression<String>? plan,
    Expression<String>? icd10Code,
    Expression<String>? createdBy,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (patientId != null) 'patient_id': patientId,
      if (queueId != null) 'queue_id': queueId,
      if (subjective != null) 'subjective': subjective,
      if (objective != null) 'objective': objective,
      if (assessment != null) 'assessment': assessment,
      if (plan != null) 'plan': plan,
      if (icd10Code != null) 'icd10_code': icd10Code,
      if (createdBy != null) 'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConsultationsCompanion copyWith(
      {Value<String>? id,
      Value<String>? patientId,
      Value<String?>? queueId,
      Value<String?>? subjective,
      Value<String?>? objective,
      Value<String?>? assessment,
      Value<String?>? plan,
      Value<String?>? icd10Code,
      Value<String>? createdBy,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return ConsultationsCompanion(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      queueId: queueId ?? this.queueId,
      subjective: subjective ?? this.subjective,
      objective: objective ?? this.objective,
      assessment: assessment ?? this.assessment,
      plan: plan ?? this.plan,
      icd10Code: icd10Code ?? this.icd10Code,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (patientId.present) {
      map['patient_id'] = Variable<String>(patientId.value);
    }
    if (queueId.present) {
      map['queue_id'] = Variable<String>(queueId.value);
    }
    if (subjective.present) {
      map['subjective'] = Variable<String>(subjective.value);
    }
    if (objective.present) {
      map['objective'] = Variable<String>(objective.value);
    }
    if (assessment.present) {
      map['assessment'] = Variable<String>(assessment.value);
    }
    if (plan.present) {
      map['plan'] = Variable<String>(plan.value);
    }
    if (icd10Code.present) {
      map['icd10_code'] = Variable<String>(icd10Code.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConsultationsCompanion(')
          ..write('id: $id, ')
          ..write('patientId: $patientId, ')
          ..write('queueId: $queueId, ')
          ..write('subjective: $subjective, ')
          ..write('objective: $objective, ')
          ..write('assessment: $assessment, ')
          ..write('plan: $plan, ')
          ..write('icd10Code: $icd10Code, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DocumentsTable extends Documents
    with TableInfo<$DocumentsTable, DocumentEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _patientIdMeta =
      const VerificationMeta('patientId');
  @override
  late final GeneratedColumn<String> patientId = GeneratedColumn<String>(
      'patient_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fileTypeMeta =
      const VerificationMeta('fileType');
  @override
  late final GeneratedColumn<String> fileType = GeneratedColumn<String>(
      'file_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _fileUrlMeta =
      const VerificationMeta('fileUrl');
  @override
  late final GeneratedColumn<String> fileUrl = GeneratedColumn<String>(
      'file_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _uploadedByMeta =
      const VerificationMeta('uploadedBy');
  @override
  late final GeneratedColumn<String> uploadedBy = GeneratedColumn<String>(
      'uploaded_by', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        patientId,
        title,
        description,
        type,
        fileType,
        filePath,
        fileUrl,
        uploadedBy,
        status,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'documents';
  @override
  VerificationContext validateIntegrity(Insertable<DocumentEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('patient_id')) {
      context.handle(_patientIdMeta,
          patientId.isAcceptableOrUnknown(data['patient_id']!, _patientIdMeta));
    } else if (isInserting) {
      context.missing(_patientIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('file_type')) {
      context.handle(_fileTypeMeta,
          fileType.isAcceptableOrUnknown(data['file_type']!, _fileTypeMeta));
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    }
    if (data.containsKey('file_url')) {
      context.handle(_fileUrlMeta,
          fileUrl.isAcceptableOrUnknown(data['file_url']!, _fileUrlMeta));
    }
    if (data.containsKey('uploaded_by')) {
      context.handle(
          _uploadedByMeta,
          uploadedBy.isAcceptableOrUnknown(
              data['uploaded_by']!, _uploadedByMeta));
    } else if (isInserting) {
      context.missing(_uploadedByMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DocumentEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DocumentEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      patientId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}patient_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      fileType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_type']),
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path']),
      fileUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_url']),
      uploadedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uploaded_by'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $DocumentsTable createAlias(String alias) {
    return $DocumentsTable(attachedDatabase, alias);
  }
}

class DocumentEntity extends DataClass implements Insertable<DocumentEntity> {
  final String id;
  final String patientId;
  final String title;
  final String? description;
  final String type;
  final String? fileType;
  final String? filePath;
  final String? fileUrl;
  final String uploadedBy;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  const DocumentEntity(
      {required this.id,
      required this.patientId,
      required this.title,
      this.description,
      required this.type,
      this.fileType,
      this.filePath,
      this.fileUrl,
      required this.uploadedBy,
      required this.status,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['patient_id'] = Variable<String>(patientId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || fileType != null) {
      map['file_type'] = Variable<String>(fileType);
    }
    if (!nullToAbsent || filePath != null) {
      map['file_path'] = Variable<String>(filePath);
    }
    if (!nullToAbsent || fileUrl != null) {
      map['file_url'] = Variable<String>(fileUrl);
    }
    map['uploaded_by'] = Variable<String>(uploadedBy);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DocumentsCompanion toCompanion(bool nullToAbsent) {
    return DocumentsCompanion(
      id: Value(id),
      patientId: Value(patientId),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      type: Value(type),
      fileType: fileType == null && nullToAbsent
          ? const Value.absent()
          : Value(fileType),
      filePath: filePath == null && nullToAbsent
          ? const Value.absent()
          : Value(filePath),
      fileUrl: fileUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(fileUrl),
      uploadedBy: Value(uploadedBy),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DocumentEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DocumentEntity(
      id: serializer.fromJson<String>(json['id']),
      patientId: serializer.fromJson<String>(json['patientId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      type: serializer.fromJson<String>(json['type']),
      fileType: serializer.fromJson<String?>(json['fileType']),
      filePath: serializer.fromJson<String?>(json['filePath']),
      fileUrl: serializer.fromJson<String?>(json['fileUrl']),
      uploadedBy: serializer.fromJson<String>(json['uploadedBy']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'patientId': serializer.toJson<String>(patientId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'type': serializer.toJson<String>(type),
      'fileType': serializer.toJson<String?>(fileType),
      'filePath': serializer.toJson<String?>(filePath),
      'fileUrl': serializer.toJson<String?>(fileUrl),
      'uploadedBy': serializer.toJson<String>(uploadedBy),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DocumentEntity copyWith(
          {String? id,
          String? patientId,
          String? title,
          Value<String?> description = const Value.absent(),
          String? type,
          Value<String?> fileType = const Value.absent(),
          Value<String?> filePath = const Value.absent(),
          Value<String?> fileUrl = const Value.absent(),
          String? uploadedBy,
          String? status,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      DocumentEntity(
        id: id ?? this.id,
        patientId: patientId ?? this.patientId,
        title: title ?? this.title,
        description: description.present ? description.value : this.description,
        type: type ?? this.type,
        fileType: fileType.present ? fileType.value : this.fileType,
        filePath: filePath.present ? filePath.value : this.filePath,
        fileUrl: fileUrl.present ? fileUrl.value : this.fileUrl,
        uploadedBy: uploadedBy ?? this.uploadedBy,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  DocumentEntity copyWithCompanion(DocumentsCompanion data) {
    return DocumentEntity(
      id: data.id.present ? data.id.value : this.id,
      patientId: data.patientId.present ? data.patientId.value : this.patientId,
      title: data.title.present ? data.title.value : this.title,
      description:
          data.description.present ? data.description.value : this.description,
      type: data.type.present ? data.type.value : this.type,
      fileType: data.fileType.present ? data.fileType.value : this.fileType,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      fileUrl: data.fileUrl.present ? data.fileUrl.value : this.fileUrl,
      uploadedBy:
          data.uploadedBy.present ? data.uploadedBy.value : this.uploadedBy,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DocumentEntity(')
          ..write('id: $id, ')
          ..write('patientId: $patientId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('type: $type, ')
          ..write('fileType: $fileType, ')
          ..write('filePath: $filePath, ')
          ..write('fileUrl: $fileUrl, ')
          ..write('uploadedBy: $uploadedBy, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, patientId, title, description, type,
      fileType, filePath, fileUrl, uploadedBy, status, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocumentEntity &&
          other.id == this.id &&
          other.patientId == this.patientId &&
          other.title == this.title &&
          other.description == this.description &&
          other.type == this.type &&
          other.fileType == this.fileType &&
          other.filePath == this.filePath &&
          other.fileUrl == this.fileUrl &&
          other.uploadedBy == this.uploadedBy &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DocumentsCompanion extends UpdateCompanion<DocumentEntity> {
  final Value<String> id;
  final Value<String> patientId;
  final Value<String> title;
  final Value<String?> description;
  final Value<String> type;
  final Value<String?> fileType;
  final Value<String?> filePath;
  final Value<String?> fileUrl;
  final Value<String> uploadedBy;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const DocumentsCompanion({
    this.id = const Value.absent(),
    this.patientId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.type = const Value.absent(),
    this.fileType = const Value.absent(),
    this.filePath = const Value.absent(),
    this.fileUrl = const Value.absent(),
    this.uploadedBy = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocumentsCompanion.insert({
    required String id,
    required String patientId,
    required String title,
    this.description = const Value.absent(),
    required String type,
    this.fileType = const Value.absent(),
    this.filePath = const Value.absent(),
    this.fileUrl = const Value.absent(),
    required String uploadedBy,
    required String status,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        patientId = Value(patientId),
        title = Value(title),
        type = Value(type),
        uploadedBy = Value(uploadedBy),
        status = Value(status),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<DocumentEntity> custom({
    Expression<String>? id,
    Expression<String>? patientId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? type,
    Expression<String>? fileType,
    Expression<String>? filePath,
    Expression<String>? fileUrl,
    Expression<String>? uploadedBy,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (patientId != null) 'patient_id': patientId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (type != null) 'type': type,
      if (fileType != null) 'file_type': fileType,
      if (filePath != null) 'file_path': filePath,
      if (fileUrl != null) 'file_url': fileUrl,
      if (uploadedBy != null) 'uploaded_by': uploadedBy,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocumentsCompanion copyWith(
      {Value<String>? id,
      Value<String>? patientId,
      Value<String>? title,
      Value<String?>? description,
      Value<String>? type,
      Value<String?>? fileType,
      Value<String?>? filePath,
      Value<String?>? fileUrl,
      Value<String>? uploadedBy,
      Value<String>? status,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return DocumentsCompanion(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      fileType: fileType ?? this.fileType,
      filePath: filePath ?? this.filePath,
      fileUrl: fileUrl ?? this.fileUrl,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (patientId.present) {
      map['patient_id'] = Variable<String>(patientId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (fileType.present) {
      map['file_type'] = Variable<String>(fileType.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (fileUrl.present) {
      map['file_url'] = Variable<String>(fileUrl.value);
    }
    if (uploadedBy.present) {
      map['uploaded_by'] = Variable<String>(uploadedBy.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentsCompanion(')
          ..write('id: $id, ')
          ..write('patientId: $patientId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('type: $type, ')
          ..write('fileType: $fileType, ')
          ..write('filePath: $filePath, ')
          ..write('fileUrl: $fileUrl, ')
          ..write('uploadedBy: $uploadedBy, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AuditLogsTable extends AuditLogs
    with TableInfo<$AuditLogsTable, AuditLogEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AuditLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
      'action', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entityTypeMeta =
      const VerificationMeta('entityType');
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
      'entity_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entityIdMeta =
      const VerificationMeta('entityId');
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
      'entity_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _oldValuesMeta =
      const VerificationMeta('oldValues');
  @override
  late final GeneratedColumn<String> oldValues = GeneratedColumn<String>(
      'old_values', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _newValuesMeta =
      const VerificationMeta('newValues');
  @override
  late final GeneratedColumn<String> newValues = GeneratedColumn<String>(
      'new_values', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        userId,
        action,
        entityType,
        entityId,
        description,
        oldValues,
        newValues,
        timestamp
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audit_logs';
  @override
  VerificationContext validateIntegrity(Insertable<AuditLogEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('action')) {
      context.handle(_actionMeta,
          action.isAcceptableOrUnknown(data['action']!, _actionMeta));
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
          _entityTypeMeta,
          entityType.isAcceptableOrUnknown(
              data['entity_type']!, _entityTypeMeta));
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(_entityIdMeta,
          entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta));
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('old_values')) {
      context.handle(_oldValuesMeta,
          oldValues.isAcceptableOrUnknown(data['old_values']!, _oldValuesMeta));
    }
    if (data.containsKey('new_values')) {
      context.handle(_newValuesMeta,
          newValues.isAcceptableOrUnknown(data['new_values']!, _newValuesMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AuditLogEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AuditLogEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      action: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}action'])!,
      entityType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_type'])!,
      entityId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_id']),
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      oldValues: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}old_values']),
      newValues: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}new_values']),
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
    );
  }

  @override
  $AuditLogsTable createAlias(String alias) {
    return $AuditLogsTable(attachedDatabase, alias);
  }
}

class AuditLogEntity extends DataClass implements Insertable<AuditLogEntity> {
  final int id;
  final String userId;
  final String action;
  final String entityType;
  final String? entityId;
  final String? description;
  final String? oldValues;
  final String? newValues;
  final DateTime timestamp;
  const AuditLogEntity(
      {required this.id,
      required this.userId,
      required this.action,
      required this.entityType,
      this.entityId,
      this.description,
      this.oldValues,
      this.newValues,
      required this.timestamp});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['user_id'] = Variable<String>(userId);
    map['action'] = Variable<String>(action);
    map['entity_type'] = Variable<String>(entityType);
    if (!nullToAbsent || entityId != null) {
      map['entity_id'] = Variable<String>(entityId);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || oldValues != null) {
      map['old_values'] = Variable<String>(oldValues);
    }
    if (!nullToAbsent || newValues != null) {
      map['new_values'] = Variable<String>(newValues);
    }
    map['timestamp'] = Variable<DateTime>(timestamp);
    return map;
  }

  AuditLogsCompanion toCompanion(bool nullToAbsent) {
    return AuditLogsCompanion(
      id: Value(id),
      userId: Value(userId),
      action: Value(action),
      entityType: Value(entityType),
      entityId: entityId == null && nullToAbsent
          ? const Value.absent()
          : Value(entityId),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      oldValues: oldValues == null && nullToAbsent
          ? const Value.absent()
          : Value(oldValues),
      newValues: newValues == null && nullToAbsent
          ? const Value.absent()
          : Value(newValues),
      timestamp: Value(timestamp),
    );
  }

  factory AuditLogEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AuditLogEntity(
      id: serializer.fromJson<int>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      action: serializer.fromJson<String>(json['action']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String?>(json['entityId']),
      description: serializer.fromJson<String?>(json['description']),
      oldValues: serializer.fromJson<String?>(json['oldValues']),
      newValues: serializer.fromJson<String?>(json['newValues']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'userId': serializer.toJson<String>(userId),
      'action': serializer.toJson<String>(action),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String?>(entityId),
      'description': serializer.toJson<String?>(description),
      'oldValues': serializer.toJson<String?>(oldValues),
      'newValues': serializer.toJson<String?>(newValues),
      'timestamp': serializer.toJson<DateTime>(timestamp),
    };
  }

  AuditLogEntity copyWith(
          {int? id,
          String? userId,
          String? action,
          String? entityType,
          Value<String?> entityId = const Value.absent(),
          Value<String?> description = const Value.absent(),
          Value<String?> oldValues = const Value.absent(),
          Value<String?> newValues = const Value.absent(),
          DateTime? timestamp}) =>
      AuditLogEntity(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        action: action ?? this.action,
        entityType: entityType ?? this.entityType,
        entityId: entityId.present ? entityId.value : this.entityId,
        description: description.present ? description.value : this.description,
        oldValues: oldValues.present ? oldValues.value : this.oldValues,
        newValues: newValues.present ? newValues.value : this.newValues,
        timestamp: timestamp ?? this.timestamp,
      );
  AuditLogEntity copyWithCompanion(AuditLogsCompanion data) {
    return AuditLogEntity(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      action: data.action.present ? data.action.value : this.action,
      entityType:
          data.entityType.present ? data.entityType.value : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      description:
          data.description.present ? data.description.value : this.description,
      oldValues: data.oldValues.present ? data.oldValues.value : this.oldValues,
      newValues: data.newValues.present ? data.newValues.value : this.newValues,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AuditLogEntity(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('action: $action, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('description: $description, ')
          ..write('oldValues: $oldValues, ')
          ..write('newValues: $newValues, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, userId, action, entityType, entityId,
      description, oldValues, newValues, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuditLogEntity &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.action == this.action &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.description == this.description &&
          other.oldValues == this.oldValues &&
          other.newValues == this.newValues &&
          other.timestamp == this.timestamp);
}

class AuditLogsCompanion extends UpdateCompanion<AuditLogEntity> {
  final Value<int> id;
  final Value<String> userId;
  final Value<String> action;
  final Value<String> entityType;
  final Value<String?> entityId;
  final Value<String?> description;
  final Value<String?> oldValues;
  final Value<String?> newValues;
  final Value<DateTime> timestamp;
  const AuditLogsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.action = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.description = const Value.absent(),
    this.oldValues = const Value.absent(),
    this.newValues = const Value.absent(),
    this.timestamp = const Value.absent(),
  });
  AuditLogsCompanion.insert({
    this.id = const Value.absent(),
    required String userId,
    required String action,
    required String entityType,
    this.entityId = const Value.absent(),
    this.description = const Value.absent(),
    this.oldValues = const Value.absent(),
    this.newValues = const Value.absent(),
    required DateTime timestamp,
  })  : userId = Value(userId),
        action = Value(action),
        entityType = Value(entityType),
        timestamp = Value(timestamp);
  static Insertable<AuditLogEntity> custom({
    Expression<int>? id,
    Expression<String>? userId,
    Expression<String>? action,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? description,
    Expression<String>? oldValues,
    Expression<String>? newValues,
    Expression<DateTime>? timestamp,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (action != null) 'action': action,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (description != null) 'description': description,
      if (oldValues != null) 'old_values': oldValues,
      if (newValues != null) 'new_values': newValues,
      if (timestamp != null) 'timestamp': timestamp,
    });
  }

  AuditLogsCompanion copyWith(
      {Value<int>? id,
      Value<String>? userId,
      Value<String>? action,
      Value<String>? entityType,
      Value<String?>? entityId,
      Value<String?>? description,
      Value<String?>? oldValues,
      Value<String?>? newValues,
      Value<DateTime>? timestamp}) {
    return AuditLogsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      action: action ?? this.action,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      description: description ?? this.description,
      oldValues: oldValues ?? this.oldValues,
      newValues: newValues ?? this.newValues,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (oldValues.present) {
      map['old_values'] = Variable<String>(oldValues.value);
    }
    if (newValues.present) {
      map['new_values'] = Variable<String>(newValues.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AuditLogsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('action: $action, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('description: $description, ')
          ..write('oldValues: $oldValues, ')
          ..write('newValues: $newValues, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(Insertable<SettingEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingEntity(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingEntity extends DataClass implements Insertable<SettingEntity> {
  final String key;
  final String value;
  final DateTime updatedAt;
  const SettingEntity(
      {required this.key, required this.value, required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory SettingEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingEntity(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SettingEntity copyWith({String? key, String? value, DateTime? updatedAt}) =>
      SettingEntity(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  SettingEntity copyWithCompanion(SettingsCompanion data) {
    return SettingEntity(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingEntity(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingEntity &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class SettingsCompanion extends UpdateCompanion<SettingEntity> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value),
        updatedAt = Value(updatedAt);
  static Insertable<SettingEntity> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith(
      {Value<String>? key,
      Value<String>? value,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncQueueItemsTable extends SyncQueueItems
    with TableInfo<$SyncQueueItemsTable, SyncQueueEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _entityTableMeta =
      const VerificationMeta('entityTable');
  @override
  late final GeneratedColumn<String> entityTable = GeneratedColumn<String>(
      'entity_table', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _recordIdMeta =
      const VerificationMeta('recordId');
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
      'record_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _operationMeta =
      const VerificationMeta('operation');
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
      'operation', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
      'data', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _isSyncedMeta =
      const VerificationMeta('isSynced');
  @override
  late final GeneratedColumn<bool> isSynced = GeneratedColumn<bool>(
      'is_synced', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_synced" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
      'synced_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
      'error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        entityTable,
        recordId,
        operation,
        data,
        createdAt,
        isSynced,
        syncedAt,
        error
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue_items';
  @override
  VerificationContext validateIntegrity(Insertable<SyncQueueEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity_table')) {
      context.handle(
          _entityTableMeta,
          entityTable.isAcceptableOrUnknown(
              data['entity_table']!, _entityTableMeta));
    } else if (isInserting) {
      context.missing(_entityTableMeta);
    }
    if (data.containsKey('record_id')) {
      context.handle(_recordIdMeta,
          recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta));
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(_operationMeta,
          operation.isAcceptableOrUnknown(data['operation']!, _operationMeta));
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
          _dataMeta, this.data.isAcceptableOrUnknown(data['data']!, _dataMeta));
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('is_synced')) {
      context.handle(_isSyncedMeta,
          isSynced.isAcceptableOrUnknown(data['is_synced']!, _isSyncedMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    }
    if (data.containsKey('error')) {
      context.handle(
          _errorMeta, error.isAcceptableOrUnknown(data['error']!, _errorMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncQueueEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      entityTable: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_table'])!,
      recordId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}record_id'])!,
      operation: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}operation'])!,
      data: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}data'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      isSynced: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_synced'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}synced_at']),
      error: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}error']),
    );
  }

  @override
  $SyncQueueItemsTable createAlias(String alias) {
    return $SyncQueueItemsTable(attachedDatabase, alias);
  }
}

class SyncQueueEntity extends DataClass implements Insertable<SyncQueueEntity> {
  final int id;
  final String entityTable;
  final String recordId;
  final String operation;
  final String data;
  final DateTime createdAt;
  final bool isSynced;
  final DateTime? syncedAt;
  final String? error;
  const SyncQueueEntity(
      {required this.id,
      required this.entityTable,
      required this.recordId,
      required this.operation,
      required this.data,
      required this.createdAt,
      required this.isSynced,
      this.syncedAt,
      this.error});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity_table'] = Variable<String>(entityTable);
    map['record_id'] = Variable<String>(recordId);
    map['operation'] = Variable<String>(operation);
    map['data'] = Variable<String>(data);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['is_synced'] = Variable<bool>(isSynced);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    return map;
  }

  SyncQueueItemsCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueItemsCompanion(
      id: Value(id),
      entityTable: Value(entityTable),
      recordId: Value(recordId),
      operation: Value(operation),
      data: Value(data),
      createdAt: Value(createdAt),
      isSynced: Value(isSynced),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      error:
          error == null && nullToAbsent ? const Value.absent() : Value(error),
    );
  }

  factory SyncQueueEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueEntity(
      id: serializer.fromJson<int>(json['id']),
      entityTable: serializer.fromJson<String>(json['entityTable']),
      recordId: serializer.fromJson<String>(json['recordId']),
      operation: serializer.fromJson<String>(json['operation']),
      data: serializer.fromJson<String>(json['data']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      isSynced: serializer.fromJson<bool>(json['isSynced']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
      error: serializer.fromJson<String?>(json['error']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entityTable': serializer.toJson<String>(entityTable),
      'recordId': serializer.toJson<String>(recordId),
      'operation': serializer.toJson<String>(operation),
      'data': serializer.toJson<String>(data),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'isSynced': serializer.toJson<bool>(isSynced),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
      'error': serializer.toJson<String?>(error),
    };
  }

  SyncQueueEntity copyWith(
          {int? id,
          String? entityTable,
          String? recordId,
          String? operation,
          String? data,
          DateTime? createdAt,
          bool? isSynced,
          Value<DateTime?> syncedAt = const Value.absent(),
          Value<String?> error = const Value.absent()}) =>
      SyncQueueEntity(
        id: id ?? this.id,
        entityTable: entityTable ?? this.entityTable,
        recordId: recordId ?? this.recordId,
        operation: operation ?? this.operation,
        data: data ?? this.data,
        createdAt: createdAt ?? this.createdAt,
        isSynced: isSynced ?? this.isSynced,
        syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
        error: error.present ? error.value : this.error,
      );
  SyncQueueEntity copyWithCompanion(SyncQueueItemsCompanion data) {
    return SyncQueueEntity(
      id: data.id.present ? data.id.value : this.id,
      entityTable:
          data.entityTable.present ? data.entityTable.value : this.entityTable,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      operation: data.operation.present ? data.operation.value : this.operation,
      data: data.data.present ? data.data.value : this.data,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      error: data.error.present ? data.error.value : this.error,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueEntity(')
          ..write('id: $id, ')
          ..write('entityTable: $entityTable, ')
          ..write('recordId: $recordId, ')
          ..write('operation: $operation, ')
          ..write('data: $data, ')
          ..write('createdAt: $createdAt, ')
          ..write('isSynced: $isSynced, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('error: $error')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, entityTable, recordId, operation, data,
      createdAt, isSynced, syncedAt, error);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueEntity &&
          other.id == this.id &&
          other.entityTable == this.entityTable &&
          other.recordId == this.recordId &&
          other.operation == this.operation &&
          other.data == this.data &&
          other.createdAt == this.createdAt &&
          other.isSynced == this.isSynced &&
          other.syncedAt == this.syncedAt &&
          other.error == this.error);
}

class SyncQueueItemsCompanion extends UpdateCompanion<SyncQueueEntity> {
  final Value<int> id;
  final Value<String> entityTable;
  final Value<String> recordId;
  final Value<String> operation;
  final Value<String> data;
  final Value<DateTime> createdAt;
  final Value<bool> isSynced;
  final Value<DateTime?> syncedAt;
  final Value<String?> error;
  const SyncQueueItemsCompanion({
    this.id = const Value.absent(),
    this.entityTable = const Value.absent(),
    this.recordId = const Value.absent(),
    this.operation = const Value.absent(),
    this.data = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.error = const Value.absent(),
  });
  SyncQueueItemsCompanion.insert({
    this.id = const Value.absent(),
    required String entityTable,
    required String recordId,
    required String operation,
    required String data,
    required DateTime createdAt,
    this.isSynced = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.error = const Value.absent(),
  })  : entityTable = Value(entityTable),
        recordId = Value(recordId),
        operation = Value(operation),
        data = Value(data),
        createdAt = Value(createdAt);
  static Insertable<SyncQueueEntity> custom({
    Expression<int>? id,
    Expression<String>? entityTable,
    Expression<String>? recordId,
    Expression<String>? operation,
    Expression<String>? data,
    Expression<DateTime>? createdAt,
    Expression<bool>? isSynced,
    Expression<DateTime>? syncedAt,
    Expression<String>? error,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityTable != null) 'entity_table': entityTable,
      if (recordId != null) 'record_id': recordId,
      if (operation != null) 'operation': operation,
      if (data != null) 'data': data,
      if (createdAt != null) 'created_at': createdAt,
      if (isSynced != null) 'is_synced': isSynced,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (error != null) 'error': error,
    });
  }

  SyncQueueItemsCompanion copyWith(
      {Value<int>? id,
      Value<String>? entityTable,
      Value<String>? recordId,
      Value<String>? operation,
      Value<String>? data,
      Value<DateTime>? createdAt,
      Value<bool>? isSynced,
      Value<DateTime?>? syncedAt,
      Value<String?>? error}) {
    return SyncQueueItemsCompanion(
      id: id ?? this.id,
      entityTable: entityTable ?? this.entityTable,
      recordId: recordId ?? this.recordId,
      operation: operation ?? this.operation,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
      error: error ?? this.error,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entityTable.present) {
      map['entity_table'] = Variable<String>(entityTable.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (isSynced.present) {
      map['is_synced'] = Variable<bool>(isSynced.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueItemsCompanion(')
          ..write('id: $id, ')
          ..write('entityTable: $entityTable, ')
          ..write('recordId: $recordId, ')
          ..write('operation: $operation, ')
          ..write('data: $data, ')
          ..write('createdAt: $createdAt, ')
          ..write('isSynced: $isSynced, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('error: $error')
          ..write(')'))
        .toString();
  }
}

class $MedicalSnippetsTable extends MedicalSnippets
    with TableInfo<$MedicalSnippetsTable, MedicalSnippetEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MedicalSnippetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _shortcutMeta =
      const VerificationMeta('shortcut');
  @override
  late final GeneratedColumn<String> shortcut = GeneratedColumn<String>(
      'shortcut', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, shortcut, title, content, category, isActive, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'medical_snippets';
  @override
  VerificationContext validateIntegrity(
      Insertable<MedicalSnippetEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('shortcut')) {
      context.handle(_shortcutMeta,
          shortcut.isAcceptableOrUnknown(data['shortcut']!, _shortcutMeta));
    } else if (isInserting) {
      context.missing(_shortcutMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MedicalSnippetEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MedicalSnippetEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      shortcut: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}shortcut'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category']),
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $MedicalSnippetsTable createAlias(String alias) {
    return $MedicalSnippetsTable(attachedDatabase, alias);
  }
}

class MedicalSnippetEntity extends DataClass
    implements Insertable<MedicalSnippetEntity> {
  final String id;
  final String shortcut;
  final String title;
  final String content;
  final String? category;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  const MedicalSnippetEntity(
      {required this.id,
      required this.shortcut,
      required this.title,
      required this.content,
      this.category,
      required this.isActive,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['shortcut'] = Variable<String>(shortcut);
    map['title'] = Variable<String>(title);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MedicalSnippetsCompanion toCompanion(bool nullToAbsent) {
    return MedicalSnippetsCompanion(
      id: Value(id),
      shortcut: Value(shortcut),
      title: Value(title),
      content: Value(content),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MedicalSnippetEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MedicalSnippetEntity(
      id: serializer.fromJson<String>(json['id']),
      shortcut: serializer.fromJson<String>(json['shortcut']),
      title: serializer.fromJson<String>(json['title']),
      content: serializer.fromJson<String>(json['content']),
      category: serializer.fromJson<String?>(json['category']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'shortcut': serializer.toJson<String>(shortcut),
      'title': serializer.toJson<String>(title),
      'content': serializer.toJson<String>(content),
      'category': serializer.toJson<String?>(category),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MedicalSnippetEntity copyWith(
          {String? id,
          String? shortcut,
          String? title,
          String? content,
          Value<String?> category = const Value.absent(),
          bool? isActive,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      MedicalSnippetEntity(
        id: id ?? this.id,
        shortcut: shortcut ?? this.shortcut,
        title: title ?? this.title,
        content: content ?? this.content,
        category: category.present ? category.value : this.category,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  MedicalSnippetEntity copyWithCompanion(MedicalSnippetsCompanion data) {
    return MedicalSnippetEntity(
      id: data.id.present ? data.id.value : this.id,
      shortcut: data.shortcut.present ? data.shortcut.value : this.shortcut,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      category: data.category.present ? data.category.value : this.category,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MedicalSnippetEntity(')
          ..write('id: $id, ')
          ..write('shortcut: $shortcut, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('category: $category, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, shortcut, title, content, category, isActive, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MedicalSnippetEntity &&
          other.id == this.id &&
          other.shortcut == this.shortcut &&
          other.title == this.title &&
          other.content == this.content &&
          other.category == this.category &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MedicalSnippetsCompanion extends UpdateCompanion<MedicalSnippetEntity> {
  final Value<String> id;
  final Value<String> shortcut;
  final Value<String> title;
  final Value<String> content;
  final Value<String?> category;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const MedicalSnippetsCompanion({
    this.id = const Value.absent(),
    this.shortcut = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.category = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MedicalSnippetsCompanion.insert({
    required String id,
    required String shortcut,
    required String title,
    required String content,
    this.category = const Value.absent(),
    this.isActive = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        shortcut = Value(shortcut),
        title = Value(title),
        content = Value(content),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<MedicalSnippetEntity> custom({
    Expression<String>? id,
    Expression<String>? shortcut,
    Expression<String>? title,
    Expression<String>? content,
    Expression<String>? category,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (shortcut != null) 'shortcut': shortcut,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (category != null) 'category': category,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MedicalSnippetsCompanion copyWith(
      {Value<String>? id,
      Value<String>? shortcut,
      Value<String>? title,
      Value<String>? content,
      Value<String?>? category,
      Value<bool>? isActive,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return MedicalSnippetsCompanion(
      id: id ?? this.id,
      shortcut: shortcut ?? this.shortcut,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (shortcut.present) {
      map['shortcut'] = Variable<String>(shortcut.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MedicalSnippetsCompanion(')
          ..write('id: $id, ')
          ..write('shortcut: $shortcut, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('category: $category, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$MedSentryDatabase extends GeneratedDatabase {
  _$MedSentryDatabase(QueryExecutor e) : super(e);
  $MedSentryDatabaseManager get managers => $MedSentryDatabaseManager(this);
  late final $UsersTable users = $UsersTable(this);
  late final $PatientsTable patients = $PatientsTable(this);
  late final $QueueItemsTable queueItems = $QueueItemsTable(this);
  late final $ConsultationsTable consultations = $ConsultationsTable(this);
  late final $DocumentsTable documents = $DocumentsTable(this);
  late final $AuditLogsTable auditLogs = $AuditLogsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $SyncQueueItemsTable syncQueueItems = $SyncQueueItemsTable(this);
  late final $MedicalSnippetsTable medicalSnippets =
      $MedicalSnippetsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        users,
        patients,
        queueItems,
        consultations,
        documents,
        auditLogs,
        settings,
        syncQueueItems,
        medicalSnippets
      ];
}

typedef $$UsersTableCreateCompanionBuilder = UsersCompanion Function({
  required String id,
  required String email,
  required String firstName,
  required String lastName,
  required String role,
  Value<String?> licenseNumber,
  Value<String?> specialization,
  Value<String?> contactNumber,
  required bool isActive,
  required bool pinEnabled,
  Value<String?> pinHash,
  required String passwordHash,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$UsersTableUpdateCompanionBuilder = UsersCompanion Function({
  Value<String> id,
  Value<String> email,
  Value<String> firstName,
  Value<String> lastName,
  Value<String> role,
  Value<String?> licenseNumber,
  Value<String?> specialization,
  Value<String?> contactNumber,
  Value<bool> isActive,
  Value<bool> pinEnabled,
  Value<String?> pinHash,
  Value<String> passwordHash,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$UsersTableTableManager extends RootTableManager<
    _$MedSentryDatabase,
    $UsersTable,
    UserEntity,
    $$UsersTableFilterComposer,
    $$UsersTableOrderingComposer,
    $$UsersTableCreateCompanionBuilder,
    $$UsersTableUpdateCompanionBuilder> {
  $$UsersTableTableManager(_$MedSentryDatabase db, $UsersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$UsersTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$UsersTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> email = const Value.absent(),
            Value<String> firstName = const Value.absent(),
            Value<String> lastName = const Value.absent(),
            Value<String> role = const Value.absent(),
            Value<String?> licenseNumber = const Value.absent(),
            Value<String?> specialization = const Value.absent(),
            Value<String?> contactNumber = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<bool> pinEnabled = const Value.absent(),
            Value<String?> pinHash = const Value.absent(),
            Value<String> passwordHash = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              UsersCompanion(
            id: id,
            email: email,
            firstName: firstName,
            lastName: lastName,
            role: role,
            licenseNumber: licenseNumber,
            specialization: specialization,
            contactNumber: contactNumber,
            isActive: isActive,
            pinEnabled: pinEnabled,
            pinHash: pinHash,
            passwordHash: passwordHash,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String email,
            required String firstName,
            required String lastName,
            required String role,
            Value<String?> licenseNumber = const Value.absent(),
            Value<String?> specialization = const Value.absent(),
            Value<String?> contactNumber = const Value.absent(),
            required bool isActive,
            required bool pinEnabled,
            Value<String?> pinHash = const Value.absent(),
            required String passwordHash,
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              UsersCompanion.insert(
            id: id,
            email: email,
            firstName: firstName,
            lastName: lastName,
            role: role,
            licenseNumber: licenseNumber,
            specialization: specialization,
            contactNumber: contactNumber,
            isActive: isActive,
            pinEnabled: pinEnabled,
            pinHash: pinHash,
            passwordHash: passwordHash,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
        ));
}

class $$UsersTableFilterComposer
    extends FilterComposer<_$MedSentryDatabase, $UsersTable> {
  $$UsersTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get email => $state.composableBuilder(
      column: $state.table.email,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get firstName => $state.composableBuilder(
      column: $state.table.firstName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get lastName => $state.composableBuilder(
      column: $state.table.lastName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get role => $state.composableBuilder(
      column: $state.table.role,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get licenseNumber => $state.composableBuilder(
      column: $state.table.licenseNumber,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get specialization => $state.composableBuilder(
      column: $state.table.specialization,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get contactNumber => $state.composableBuilder(
      column: $state.table.contactNumber,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isActive => $state.composableBuilder(
      column: $state.table.isActive,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get pinEnabled => $state.composableBuilder(
      column: $state.table.pinEnabled,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get pinHash => $state.composableBuilder(
      column: $state.table.pinHash,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get passwordHash => $state.composableBuilder(
      column: $state.table.passwordHash,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$UsersTableOrderingComposer
    extends OrderingComposer<_$MedSentryDatabase, $UsersTable> {
  $$UsersTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get email => $state.composableBuilder(
      column: $state.table.email,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get firstName => $state.composableBuilder(
      column: $state.table.firstName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get lastName => $state.composableBuilder(
      column: $state.table.lastName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get role => $state.composableBuilder(
      column: $state.table.role,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get licenseNumber => $state.composableBuilder(
      column: $state.table.licenseNumber,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get specialization => $state.composableBuilder(
      column: $state.table.specialization,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get contactNumber => $state.composableBuilder(
      column: $state.table.contactNumber,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isActive => $state.composableBuilder(
      column: $state.table.isActive,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get pinEnabled => $state.composableBuilder(
      column: $state.table.pinEnabled,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get pinHash => $state.composableBuilder(
      column: $state.table.pinHash,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get passwordHash => $state.composableBuilder(
      column: $state.table.passwordHash,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$PatientsTableCreateCompanionBuilder = PatientsCompanion Function({
  required String id,
  required String firstName,
  required String lastName,
  Value<String?> middleName,
  Value<String?> suffix,
  Value<DateTime?> dateOfBirth,
  Value<String?> gender,
  Value<String?> civilStatus,
  Value<String?> religion,
  Value<String?> contactNumber,
  Value<String?> email,
  Value<String?> address,
  Value<String?> barangay,
  Value<String?> purokSitio,
  Value<String?> city,
  Value<String?> province,
  Value<String?> zipCode,
  Value<String?> philHealthNumber,
  Value<String?> philHealthCategory,
  Value<String?> localLguIdNumber,
  Value<String?> bloodType,
  Value<String?> emergencyContactName,
  Value<String?> emergencyContactNumber,
  Value<String?> emergencyContactRelation,
  Value<String?> occupation,
  Value<String?> employer,
  Value<bool> isPwd,
  Value<bool> isSoloParent,
  Value<bool> isIndigenousPerson,
  Value<String?> tribeEthnolinguisticGroup,
  Value<bool> is4PsBeneficiary,
  Value<String?> householdIdNumber,
  Value<String?> waterSource,
  Value<String?> toiletFacility,
  Value<double?> height,
  Value<double?> weight,
  Value<String?> allergies,
  Value<String?> medicalHistory,
  Value<String?> category,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
  Value<DateTime?> lastVisitDate,
  Value<int?> syncStatus,
  Value<String?> syncError,
  Value<int> rowid,
});
typedef $$PatientsTableUpdateCompanionBuilder = PatientsCompanion Function({
  Value<String> id,
  Value<String> firstName,
  Value<String> lastName,
  Value<String?> middleName,
  Value<String?> suffix,
  Value<DateTime?> dateOfBirth,
  Value<String?> gender,
  Value<String?> civilStatus,
  Value<String?> religion,
  Value<String?> contactNumber,
  Value<String?> email,
  Value<String?> address,
  Value<String?> barangay,
  Value<String?> purokSitio,
  Value<String?> city,
  Value<String?> province,
  Value<String?> zipCode,
  Value<String?> philHealthNumber,
  Value<String?> philHealthCategory,
  Value<String?> localLguIdNumber,
  Value<String?> bloodType,
  Value<String?> emergencyContactName,
  Value<String?> emergencyContactNumber,
  Value<String?> emergencyContactRelation,
  Value<String?> occupation,
  Value<String?> employer,
  Value<bool> isPwd,
  Value<bool> isSoloParent,
  Value<bool> isIndigenousPerson,
  Value<String?> tribeEthnolinguisticGroup,
  Value<bool> is4PsBeneficiary,
  Value<String?> householdIdNumber,
  Value<String?> waterSource,
  Value<String?> toiletFacility,
  Value<double?> height,
  Value<double?> weight,
  Value<String?> allergies,
  Value<String?> medicalHistory,
  Value<String?> category,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
  Value<DateTime?> lastVisitDate,
  Value<int?> syncStatus,
  Value<String?> syncError,
  Value<int> rowid,
});

class $$PatientsTableTableManager extends RootTableManager<
    _$MedSentryDatabase,
    $PatientsTable,
    PatientEntity,
    $$PatientsTableFilterComposer,
    $$PatientsTableOrderingComposer,
    $$PatientsTableCreateCompanionBuilder,
    $$PatientsTableUpdateCompanionBuilder> {
  $$PatientsTableTableManager(_$MedSentryDatabase db, $PatientsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$PatientsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$PatientsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> firstName = const Value.absent(),
            Value<String> lastName = const Value.absent(),
            Value<String?> middleName = const Value.absent(),
            Value<String?> suffix = const Value.absent(),
            Value<DateTime?> dateOfBirth = const Value.absent(),
            Value<String?> gender = const Value.absent(),
            Value<String?> civilStatus = const Value.absent(),
            Value<String?> religion = const Value.absent(),
            Value<String?> contactNumber = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<String?> address = const Value.absent(),
            Value<String?> barangay = const Value.absent(),
            Value<String?> purokSitio = const Value.absent(),
            Value<String?> city = const Value.absent(),
            Value<String?> province = const Value.absent(),
            Value<String?> zipCode = const Value.absent(),
            Value<String?> philHealthNumber = const Value.absent(),
            Value<String?> philHealthCategory = const Value.absent(),
            Value<String?> localLguIdNumber = const Value.absent(),
            Value<String?> bloodType = const Value.absent(),
            Value<String?> emergencyContactName = const Value.absent(),
            Value<String?> emergencyContactNumber = const Value.absent(),
            Value<String?> emergencyContactRelation = const Value.absent(),
            Value<String?> occupation = const Value.absent(),
            Value<String?> employer = const Value.absent(),
            Value<bool> isPwd = const Value.absent(),
            Value<bool> isSoloParent = const Value.absent(),
            Value<bool> isIndigenousPerson = const Value.absent(),
            Value<String?> tribeEthnolinguisticGroup = const Value.absent(),
            Value<bool> is4PsBeneficiary = const Value.absent(),
            Value<String?> householdIdNumber = const Value.absent(),
            Value<String?> waterSource = const Value.absent(),
            Value<String?> toiletFacility = const Value.absent(),
            Value<double?> height = const Value.absent(),
            Value<double?> weight = const Value.absent(),
            Value<String?> allergies = const Value.absent(),
            Value<String?> medicalHistory = const Value.absent(),
            Value<String?> category = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<DateTime?> lastVisitDate = const Value.absent(),
            Value<int?> syncStatus = const Value.absent(),
            Value<String?> syncError = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PatientsCompanion(
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
            philHealthCategory: philHealthCategory,
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
            waterSource: waterSource,
            toiletFacility: toiletFacility,
            height: height,
            weight: weight,
            allergies: allergies,
            medicalHistory: medicalHistory,
            category: category,
            createdAt: createdAt,
            updatedAt: updatedAt,
            lastVisitDate: lastVisitDate,
            syncStatus: syncStatus,
            syncError: syncError,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String firstName,
            required String lastName,
            Value<String?> middleName = const Value.absent(),
            Value<String?> suffix = const Value.absent(),
            Value<DateTime?> dateOfBirth = const Value.absent(),
            Value<String?> gender = const Value.absent(),
            Value<String?> civilStatus = const Value.absent(),
            Value<String?> religion = const Value.absent(),
            Value<String?> contactNumber = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<String?> address = const Value.absent(),
            Value<String?> barangay = const Value.absent(),
            Value<String?> purokSitio = const Value.absent(),
            Value<String?> city = const Value.absent(),
            Value<String?> province = const Value.absent(),
            Value<String?> zipCode = const Value.absent(),
            Value<String?> philHealthNumber = const Value.absent(),
            Value<String?> philHealthCategory = const Value.absent(),
            Value<String?> localLguIdNumber = const Value.absent(),
            Value<String?> bloodType = const Value.absent(),
            Value<String?> emergencyContactName = const Value.absent(),
            Value<String?> emergencyContactNumber = const Value.absent(),
            Value<String?> emergencyContactRelation = const Value.absent(),
            Value<String?> occupation = const Value.absent(),
            Value<String?> employer = const Value.absent(),
            Value<bool> isPwd = const Value.absent(),
            Value<bool> isSoloParent = const Value.absent(),
            Value<bool> isIndigenousPerson = const Value.absent(),
            Value<String?> tribeEthnolinguisticGroup = const Value.absent(),
            Value<bool> is4PsBeneficiary = const Value.absent(),
            Value<String?> householdIdNumber = const Value.absent(),
            Value<String?> waterSource = const Value.absent(),
            Value<String?> toiletFacility = const Value.absent(),
            Value<double?> height = const Value.absent(),
            Value<double?> weight = const Value.absent(),
            Value<String?> allergies = const Value.absent(),
            Value<String?> medicalHistory = const Value.absent(),
            Value<String?> category = const Value.absent(),
            Value<DateTime?> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<DateTime?> lastVisitDate = const Value.absent(),
            Value<int?> syncStatus = const Value.absent(),
            Value<String?> syncError = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PatientsCompanion.insert(
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
            philHealthCategory: philHealthCategory,
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
            waterSource: waterSource,
            toiletFacility: toiletFacility,
            height: height,
            weight: weight,
            allergies: allergies,
            medicalHistory: medicalHistory,
            category: category,
            createdAt: createdAt,
            updatedAt: updatedAt,
            lastVisitDate: lastVisitDate,
            syncStatus: syncStatus,
            syncError: syncError,
            rowid: rowid,
          ),
        ));
}

class $$PatientsTableFilterComposer
    extends FilterComposer<_$MedSentryDatabase, $PatientsTable> {
  $$PatientsTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get firstName => $state.composableBuilder(
      column: $state.table.firstName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get lastName => $state.composableBuilder(
      column: $state.table.lastName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get middleName => $state.composableBuilder(
      column: $state.table.middleName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get suffix => $state.composableBuilder(
      column: $state.table.suffix,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get dateOfBirth => $state.composableBuilder(
      column: $state.table.dateOfBirth,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get gender => $state.composableBuilder(
      column: $state.table.gender,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get civilStatus => $state.composableBuilder(
      column: $state.table.civilStatus,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get religion => $state.composableBuilder(
      column: $state.table.religion,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get contactNumber => $state.composableBuilder(
      column: $state.table.contactNumber,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get email => $state.composableBuilder(
      column: $state.table.email,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get address => $state.composableBuilder(
      column: $state.table.address,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get barangay => $state.composableBuilder(
      column: $state.table.barangay,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get purokSitio => $state.composableBuilder(
      column: $state.table.purokSitio,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get city => $state.composableBuilder(
      column: $state.table.city,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get province => $state.composableBuilder(
      column: $state.table.province,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get zipCode => $state.composableBuilder(
      column: $state.table.zipCode,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get philHealthNumber => $state.composableBuilder(
      column: $state.table.philHealthNumber,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get philHealthCategory => $state.composableBuilder(
      column: $state.table.philHealthCategory,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get localLguIdNumber => $state.composableBuilder(
      column: $state.table.localLguIdNumber,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get bloodType => $state.composableBuilder(
      column: $state.table.bloodType,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get emergencyContactName => $state.composableBuilder(
      column: $state.table.emergencyContactName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get emergencyContactNumber => $state.composableBuilder(
      column: $state.table.emergencyContactNumber,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get emergencyContactRelation =>
      $state.composableBuilder(
          column: $state.table.emergencyContactRelation,
          builder: (column, joinBuilders) =>
              ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get occupation => $state.composableBuilder(
      column: $state.table.occupation,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get employer => $state.composableBuilder(
      column: $state.table.employer,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isPwd => $state.composableBuilder(
      column: $state.table.isPwd,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isSoloParent => $state.composableBuilder(
      column: $state.table.isSoloParent,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isIndigenousPerson => $state.composableBuilder(
      column: $state.table.isIndigenousPerson,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get tribeEthnolinguisticGroup =>
      $state.composableBuilder(
          column: $state.table.tribeEthnolinguisticGroup,
          builder: (column, joinBuilders) =>
              ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get is4PsBeneficiary => $state.composableBuilder(
      column: $state.table.is4PsBeneficiary,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get householdIdNumber => $state.composableBuilder(
      column: $state.table.householdIdNumber,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get waterSource => $state.composableBuilder(
      column: $state.table.waterSource,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get toiletFacility => $state.composableBuilder(
      column: $state.table.toiletFacility,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get height => $state.composableBuilder(
      column: $state.table.height,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get weight => $state.composableBuilder(
      column: $state.table.weight,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get allergies => $state.composableBuilder(
      column: $state.table.allergies,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get medicalHistory => $state.composableBuilder(
      column: $state.table.medicalHistory,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get category => $state.composableBuilder(
      column: $state.table.category,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get lastVisitDate => $state.composableBuilder(
      column: $state.table.lastVisitDate,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get syncStatus => $state.composableBuilder(
      column: $state.table.syncStatus,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get syncError => $state.composableBuilder(
      column: $state.table.syncError,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$PatientsTableOrderingComposer
    extends OrderingComposer<_$MedSentryDatabase, $PatientsTable> {
  $$PatientsTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get firstName => $state.composableBuilder(
      column: $state.table.firstName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get lastName => $state.composableBuilder(
      column: $state.table.lastName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get middleName => $state.composableBuilder(
      column: $state.table.middleName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get suffix => $state.composableBuilder(
      column: $state.table.suffix,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get dateOfBirth => $state.composableBuilder(
      column: $state.table.dateOfBirth,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get gender => $state.composableBuilder(
      column: $state.table.gender,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get civilStatus => $state.composableBuilder(
      column: $state.table.civilStatus,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get religion => $state.composableBuilder(
      column: $state.table.religion,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get contactNumber => $state.composableBuilder(
      column: $state.table.contactNumber,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get email => $state.composableBuilder(
      column: $state.table.email,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get address => $state.composableBuilder(
      column: $state.table.address,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get barangay => $state.composableBuilder(
      column: $state.table.barangay,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get purokSitio => $state.composableBuilder(
      column: $state.table.purokSitio,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get city => $state.composableBuilder(
      column: $state.table.city,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get province => $state.composableBuilder(
      column: $state.table.province,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get zipCode => $state.composableBuilder(
      column: $state.table.zipCode,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get philHealthNumber => $state.composableBuilder(
      column: $state.table.philHealthNumber,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get philHealthCategory => $state.composableBuilder(
      column: $state.table.philHealthCategory,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get localLguIdNumber => $state.composableBuilder(
      column: $state.table.localLguIdNumber,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get bloodType => $state.composableBuilder(
      column: $state.table.bloodType,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get emergencyContactName => $state.composableBuilder(
      column: $state.table.emergencyContactName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get emergencyContactNumber =>
      $state.composableBuilder(
          column: $state.table.emergencyContactNumber,
          builder: (column, joinBuilders) =>
              ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get emergencyContactRelation =>
      $state.composableBuilder(
          column: $state.table.emergencyContactRelation,
          builder: (column, joinBuilders) =>
              ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get occupation => $state.composableBuilder(
      column: $state.table.occupation,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get employer => $state.composableBuilder(
      column: $state.table.employer,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isPwd => $state.composableBuilder(
      column: $state.table.isPwd,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isSoloParent => $state.composableBuilder(
      column: $state.table.isSoloParent,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isIndigenousPerson => $state.composableBuilder(
      column: $state.table.isIndigenousPerson,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get tribeEthnolinguisticGroup => $state
      .composableBuilder(
          column: $state.table.tribeEthnolinguisticGroup,
          builder: (column, joinBuilders) =>
              ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get is4PsBeneficiary => $state.composableBuilder(
      column: $state.table.is4PsBeneficiary,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get householdIdNumber => $state.composableBuilder(
      column: $state.table.householdIdNumber,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get waterSource => $state.composableBuilder(
      column: $state.table.waterSource,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get toiletFacility => $state.composableBuilder(
      column: $state.table.toiletFacility,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get height => $state.composableBuilder(
      column: $state.table.height,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get weight => $state.composableBuilder(
      column: $state.table.weight,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get allergies => $state.composableBuilder(
      column: $state.table.allergies,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get medicalHistory => $state.composableBuilder(
      column: $state.table.medicalHistory,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get category => $state.composableBuilder(
      column: $state.table.category,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get lastVisitDate => $state.composableBuilder(
      column: $state.table.lastVisitDate,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get syncStatus => $state.composableBuilder(
      column: $state.table.syncStatus,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get syncError => $state.composableBuilder(
      column: $state.table.syncError,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$QueueItemsTableCreateCompanionBuilder = QueueItemsCompanion Function({
  required String id,
  required String patientId,
  required String status,
  required String priority,
  Value<String?> nurseId,
  Value<String?> roomNumber,
  Value<String?> category,
  Value<String?> vitalsBp,
  Value<double?> vitalsWeight,
  Value<double?> vitalsTemperature,
  Value<String?> vitalsNotes,
  required DateTime arrivalTime,
  Value<DateTime?> startTime,
  Value<DateTime?> endTime,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$QueueItemsTableUpdateCompanionBuilder = QueueItemsCompanion Function({
  Value<String> id,
  Value<String> patientId,
  Value<String> status,
  Value<String> priority,
  Value<String?> nurseId,
  Value<String?> roomNumber,
  Value<String?> category,
  Value<String?> vitalsBp,
  Value<double?> vitalsWeight,
  Value<double?> vitalsTemperature,
  Value<String?> vitalsNotes,
  Value<DateTime> arrivalTime,
  Value<DateTime?> startTime,
  Value<DateTime?> endTime,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$QueueItemsTableTableManager extends RootTableManager<
    _$MedSentryDatabase,
    $QueueItemsTable,
    QueueItemEntity,
    $$QueueItemsTableFilterComposer,
    $$QueueItemsTableOrderingComposer,
    $$QueueItemsTableCreateCompanionBuilder,
    $$QueueItemsTableUpdateCompanionBuilder> {
  $$QueueItemsTableTableManager(_$MedSentryDatabase db, $QueueItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$QueueItemsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$QueueItemsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> patientId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> priority = const Value.absent(),
            Value<String?> nurseId = const Value.absent(),
            Value<String?> roomNumber = const Value.absent(),
            Value<String?> category = const Value.absent(),
            Value<String?> vitalsBp = const Value.absent(),
            Value<double?> vitalsWeight = const Value.absent(),
            Value<double?> vitalsTemperature = const Value.absent(),
            Value<String?> vitalsNotes = const Value.absent(),
            Value<DateTime> arrivalTime = const Value.absent(),
            Value<DateTime?> startTime = const Value.absent(),
            Value<DateTime?> endTime = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              QueueItemsCompanion(
            id: id,
            patientId: patientId,
            status: status,
            priority: priority,
            nurseId: nurseId,
            roomNumber: roomNumber,
            category: category,
            vitalsBp: vitalsBp,
            vitalsWeight: vitalsWeight,
            vitalsTemperature: vitalsTemperature,
            vitalsNotes: vitalsNotes,
            arrivalTime: arrivalTime,
            startTime: startTime,
            endTime: endTime,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String patientId,
            required String status,
            required String priority,
            Value<String?> nurseId = const Value.absent(),
            Value<String?> roomNumber = const Value.absent(),
            Value<String?> category = const Value.absent(),
            Value<String?> vitalsBp = const Value.absent(),
            Value<double?> vitalsWeight = const Value.absent(),
            Value<double?> vitalsTemperature = const Value.absent(),
            Value<String?> vitalsNotes = const Value.absent(),
            required DateTime arrivalTime,
            Value<DateTime?> startTime = const Value.absent(),
            Value<DateTime?> endTime = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              QueueItemsCompanion.insert(
            id: id,
            patientId: patientId,
            status: status,
            priority: priority,
            nurseId: nurseId,
            roomNumber: roomNumber,
            category: category,
            vitalsBp: vitalsBp,
            vitalsWeight: vitalsWeight,
            vitalsTemperature: vitalsTemperature,
            vitalsNotes: vitalsNotes,
            arrivalTime: arrivalTime,
            startTime: startTime,
            endTime: endTime,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
        ));
}

class $$QueueItemsTableFilterComposer
    extends FilterComposer<_$MedSentryDatabase, $QueueItemsTable> {
  $$QueueItemsTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get patientId => $state.composableBuilder(
      column: $state.table.patientId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get priority => $state.composableBuilder(
      column: $state.table.priority,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get nurseId => $state.composableBuilder(
      column: $state.table.nurseId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get roomNumber => $state.composableBuilder(
      column: $state.table.roomNumber,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get category => $state.composableBuilder(
      column: $state.table.category,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get vitalsBp => $state.composableBuilder(
      column: $state.table.vitalsBp,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get vitalsWeight => $state.composableBuilder(
      column: $state.table.vitalsWeight,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<double> get vitalsTemperature => $state.composableBuilder(
      column: $state.table.vitalsTemperature,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get vitalsNotes => $state.composableBuilder(
      column: $state.table.vitalsNotes,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get arrivalTime => $state.composableBuilder(
      column: $state.table.arrivalTime,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get startTime => $state.composableBuilder(
      column: $state.table.startTime,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get endTime => $state.composableBuilder(
      column: $state.table.endTime,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$QueueItemsTableOrderingComposer
    extends OrderingComposer<_$MedSentryDatabase, $QueueItemsTable> {
  $$QueueItemsTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get patientId => $state.composableBuilder(
      column: $state.table.patientId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get priority => $state.composableBuilder(
      column: $state.table.priority,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get nurseId => $state.composableBuilder(
      column: $state.table.nurseId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get roomNumber => $state.composableBuilder(
      column: $state.table.roomNumber,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get category => $state.composableBuilder(
      column: $state.table.category,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get vitalsBp => $state.composableBuilder(
      column: $state.table.vitalsBp,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get vitalsWeight => $state.composableBuilder(
      column: $state.table.vitalsWeight,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<double> get vitalsTemperature => $state.composableBuilder(
      column: $state.table.vitalsTemperature,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get vitalsNotes => $state.composableBuilder(
      column: $state.table.vitalsNotes,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get arrivalTime => $state.composableBuilder(
      column: $state.table.arrivalTime,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get startTime => $state.composableBuilder(
      column: $state.table.startTime,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get endTime => $state.composableBuilder(
      column: $state.table.endTime,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$ConsultationsTableCreateCompanionBuilder = ConsultationsCompanion
    Function({
  required String id,
  required String patientId,
  Value<String?> queueId,
  Value<String?> subjective,
  Value<String?> objective,
  Value<String?> assessment,
  Value<String?> plan,
  Value<String?> icd10Code,
  required String createdBy,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$ConsultationsTableUpdateCompanionBuilder = ConsultationsCompanion
    Function({
  Value<String> id,
  Value<String> patientId,
  Value<String?> queueId,
  Value<String?> subjective,
  Value<String?> objective,
  Value<String?> assessment,
  Value<String?> plan,
  Value<String?> icd10Code,
  Value<String> createdBy,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$ConsultationsTableTableManager extends RootTableManager<
    _$MedSentryDatabase,
    $ConsultationsTable,
    ConsultationEntity,
    $$ConsultationsTableFilterComposer,
    $$ConsultationsTableOrderingComposer,
    $$ConsultationsTableCreateCompanionBuilder,
    $$ConsultationsTableUpdateCompanionBuilder> {
  $$ConsultationsTableTableManager(
      _$MedSentryDatabase db, $ConsultationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$ConsultationsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$ConsultationsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> patientId = const Value.absent(),
            Value<String?> queueId = const Value.absent(),
            Value<String?> subjective = const Value.absent(),
            Value<String?> objective = const Value.absent(),
            Value<String?> assessment = const Value.absent(),
            Value<String?> plan = const Value.absent(),
            Value<String?> icd10Code = const Value.absent(),
            Value<String> createdBy = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ConsultationsCompanion(
            id: id,
            patientId: patientId,
            queueId: queueId,
            subjective: subjective,
            objective: objective,
            assessment: assessment,
            plan: plan,
            icd10Code: icd10Code,
            createdBy: createdBy,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String patientId,
            Value<String?> queueId = const Value.absent(),
            Value<String?> subjective = const Value.absent(),
            Value<String?> objective = const Value.absent(),
            Value<String?> assessment = const Value.absent(),
            Value<String?> plan = const Value.absent(),
            Value<String?> icd10Code = const Value.absent(),
            required String createdBy,
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ConsultationsCompanion.insert(
            id: id,
            patientId: patientId,
            queueId: queueId,
            subjective: subjective,
            objective: objective,
            assessment: assessment,
            plan: plan,
            icd10Code: icd10Code,
            createdBy: createdBy,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
        ));
}

class $$ConsultationsTableFilterComposer
    extends FilterComposer<_$MedSentryDatabase, $ConsultationsTable> {
  $$ConsultationsTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get patientId => $state.composableBuilder(
      column: $state.table.patientId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get queueId => $state.composableBuilder(
      column: $state.table.queueId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get subjective => $state.composableBuilder(
      column: $state.table.subjective,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get objective => $state.composableBuilder(
      column: $state.table.objective,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get assessment => $state.composableBuilder(
      column: $state.table.assessment,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get plan => $state.composableBuilder(
      column: $state.table.plan,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get icd10Code => $state.composableBuilder(
      column: $state.table.icd10Code,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get createdBy => $state.composableBuilder(
      column: $state.table.createdBy,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$ConsultationsTableOrderingComposer
    extends OrderingComposer<_$MedSentryDatabase, $ConsultationsTable> {
  $$ConsultationsTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get patientId => $state.composableBuilder(
      column: $state.table.patientId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get queueId => $state.composableBuilder(
      column: $state.table.queueId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get subjective => $state.composableBuilder(
      column: $state.table.subjective,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get objective => $state.composableBuilder(
      column: $state.table.objective,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get assessment => $state.composableBuilder(
      column: $state.table.assessment,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get plan => $state.composableBuilder(
      column: $state.table.plan,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get icd10Code => $state.composableBuilder(
      column: $state.table.icd10Code,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get createdBy => $state.composableBuilder(
      column: $state.table.createdBy,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$DocumentsTableCreateCompanionBuilder = DocumentsCompanion Function({
  required String id,
  required String patientId,
  required String title,
  Value<String?> description,
  required String type,
  Value<String?> fileType,
  Value<String?> filePath,
  Value<String?> fileUrl,
  required String uploadedBy,
  required String status,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$DocumentsTableUpdateCompanionBuilder = DocumentsCompanion Function({
  Value<String> id,
  Value<String> patientId,
  Value<String> title,
  Value<String?> description,
  Value<String> type,
  Value<String?> fileType,
  Value<String?> filePath,
  Value<String?> fileUrl,
  Value<String> uploadedBy,
  Value<String> status,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$DocumentsTableTableManager extends RootTableManager<
    _$MedSentryDatabase,
    $DocumentsTable,
    DocumentEntity,
    $$DocumentsTableFilterComposer,
    $$DocumentsTableOrderingComposer,
    $$DocumentsTableCreateCompanionBuilder,
    $$DocumentsTableUpdateCompanionBuilder> {
  $$DocumentsTableTableManager(_$MedSentryDatabase db, $DocumentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$DocumentsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$DocumentsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> patientId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String?> fileType = const Value.absent(),
            Value<String?> filePath = const Value.absent(),
            Value<String?> fileUrl = const Value.absent(),
            Value<String> uploadedBy = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DocumentsCompanion(
            id: id,
            patientId: patientId,
            title: title,
            description: description,
            type: type,
            fileType: fileType,
            filePath: filePath,
            fileUrl: fileUrl,
            uploadedBy: uploadedBy,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String patientId,
            required String title,
            Value<String?> description = const Value.absent(),
            required String type,
            Value<String?> fileType = const Value.absent(),
            Value<String?> filePath = const Value.absent(),
            Value<String?> fileUrl = const Value.absent(),
            required String uploadedBy,
            required String status,
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              DocumentsCompanion.insert(
            id: id,
            patientId: patientId,
            title: title,
            description: description,
            type: type,
            fileType: fileType,
            filePath: filePath,
            fileUrl: fileUrl,
            uploadedBy: uploadedBy,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
        ));
}

class $$DocumentsTableFilterComposer
    extends FilterComposer<_$MedSentryDatabase, $DocumentsTable> {
  $$DocumentsTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get patientId => $state.composableBuilder(
      column: $state.table.patientId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get title => $state.composableBuilder(
      column: $state.table.title,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get type => $state.composableBuilder(
      column: $state.table.type,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get fileType => $state.composableBuilder(
      column: $state.table.fileType,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get filePath => $state.composableBuilder(
      column: $state.table.filePath,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get fileUrl => $state.composableBuilder(
      column: $state.table.fileUrl,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get uploadedBy => $state.composableBuilder(
      column: $state.table.uploadedBy,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$DocumentsTableOrderingComposer
    extends OrderingComposer<_$MedSentryDatabase, $DocumentsTable> {
  $$DocumentsTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get patientId => $state.composableBuilder(
      column: $state.table.patientId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get title => $state.composableBuilder(
      column: $state.table.title,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get type => $state.composableBuilder(
      column: $state.table.type,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get fileType => $state.composableBuilder(
      column: $state.table.fileType,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get filePath => $state.composableBuilder(
      column: $state.table.filePath,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get fileUrl => $state.composableBuilder(
      column: $state.table.fileUrl,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get uploadedBy => $state.composableBuilder(
      column: $state.table.uploadedBy,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get status => $state.composableBuilder(
      column: $state.table.status,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$AuditLogsTableCreateCompanionBuilder = AuditLogsCompanion Function({
  Value<int> id,
  required String userId,
  required String action,
  required String entityType,
  Value<String?> entityId,
  Value<String?> description,
  Value<String?> oldValues,
  Value<String?> newValues,
  required DateTime timestamp,
});
typedef $$AuditLogsTableUpdateCompanionBuilder = AuditLogsCompanion Function({
  Value<int> id,
  Value<String> userId,
  Value<String> action,
  Value<String> entityType,
  Value<String?> entityId,
  Value<String?> description,
  Value<String?> oldValues,
  Value<String?> newValues,
  Value<DateTime> timestamp,
});

class $$AuditLogsTableTableManager extends RootTableManager<
    _$MedSentryDatabase,
    $AuditLogsTable,
    AuditLogEntity,
    $$AuditLogsTableFilterComposer,
    $$AuditLogsTableOrderingComposer,
    $$AuditLogsTableCreateCompanionBuilder,
    $$AuditLogsTableUpdateCompanionBuilder> {
  $$AuditLogsTableTableManager(_$MedSentryDatabase db, $AuditLogsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$AuditLogsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$AuditLogsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> action = const Value.absent(),
            Value<String> entityType = const Value.absent(),
            Value<String?> entityId = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String?> oldValues = const Value.absent(),
            Value<String?> newValues = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
          }) =>
              AuditLogsCompanion(
            id: id,
            userId: userId,
            action: action,
            entityType: entityType,
            entityId: entityId,
            description: description,
            oldValues: oldValues,
            newValues: newValues,
            timestamp: timestamp,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String userId,
            required String action,
            required String entityType,
            Value<String?> entityId = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String?> oldValues = const Value.absent(),
            Value<String?> newValues = const Value.absent(),
            required DateTime timestamp,
          }) =>
              AuditLogsCompanion.insert(
            id: id,
            userId: userId,
            action: action,
            entityType: entityType,
            entityId: entityId,
            description: description,
            oldValues: oldValues,
            newValues: newValues,
            timestamp: timestamp,
          ),
        ));
}

class $$AuditLogsTableFilterComposer
    extends FilterComposer<_$MedSentryDatabase, $AuditLogsTable> {
  $$AuditLogsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get userId => $state.composableBuilder(
      column: $state.table.userId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get action => $state.composableBuilder(
      column: $state.table.action,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get entityType => $state.composableBuilder(
      column: $state.table.entityType,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get entityId => $state.composableBuilder(
      column: $state.table.entityId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get oldValues => $state.composableBuilder(
      column: $state.table.oldValues,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get newValues => $state.composableBuilder(
      column: $state.table.newValues,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get timestamp => $state.composableBuilder(
      column: $state.table.timestamp,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$AuditLogsTableOrderingComposer
    extends OrderingComposer<_$MedSentryDatabase, $AuditLogsTable> {
  $$AuditLogsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get userId => $state.composableBuilder(
      column: $state.table.userId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get action => $state.composableBuilder(
      column: $state.table.action,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get entityType => $state.composableBuilder(
      column: $state.table.entityType,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get entityId => $state.composableBuilder(
      column: $state.table.entityId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get oldValues => $state.composableBuilder(
      column: $state.table.oldValues,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get newValues => $state.composableBuilder(
      column: $state.table.newValues,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get timestamp => $state.composableBuilder(
      column: $state.table.timestamp,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$SettingsTableTableManager extends RootTableManager<
    _$MedSentryDatabase,
    $SettingsTable,
    SettingEntity,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder> {
  $$SettingsTableTableManager(_$MedSentryDatabase db, $SettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$SettingsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$SettingsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion(
            key: key,
            value: value,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion.insert(
            key: key,
            value: value,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
        ));
}

class $$SettingsTableFilterComposer
    extends FilterComposer<_$MedSentryDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer(super.$state);
  ColumnFilters<String> get key => $state.composableBuilder(
      column: $state.table.key,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get value => $state.composableBuilder(
      column: $state.table.value,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$SettingsTableOrderingComposer
    extends OrderingComposer<_$MedSentryDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer(super.$state);
  ColumnOrderings<String> get key => $state.composableBuilder(
      column: $state.table.key,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get value => $state.composableBuilder(
      column: $state.table.value,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$SyncQueueItemsTableCreateCompanionBuilder = SyncQueueItemsCompanion
    Function({
  Value<int> id,
  required String entityTable,
  required String recordId,
  required String operation,
  required String data,
  required DateTime createdAt,
  Value<bool> isSynced,
  Value<DateTime?> syncedAt,
  Value<String?> error,
});
typedef $$SyncQueueItemsTableUpdateCompanionBuilder = SyncQueueItemsCompanion
    Function({
  Value<int> id,
  Value<String> entityTable,
  Value<String> recordId,
  Value<String> operation,
  Value<String> data,
  Value<DateTime> createdAt,
  Value<bool> isSynced,
  Value<DateTime?> syncedAt,
  Value<String?> error,
});

class $$SyncQueueItemsTableTableManager extends RootTableManager<
    _$MedSentryDatabase,
    $SyncQueueItemsTable,
    SyncQueueEntity,
    $$SyncQueueItemsTableFilterComposer,
    $$SyncQueueItemsTableOrderingComposer,
    $$SyncQueueItemsTableCreateCompanionBuilder,
    $$SyncQueueItemsTableUpdateCompanionBuilder> {
  $$SyncQueueItemsTableTableManager(
      _$MedSentryDatabase db, $SyncQueueItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$SyncQueueItemsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$SyncQueueItemsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> entityTable = const Value.absent(),
            Value<String> recordId = const Value.absent(),
            Value<String> operation = const Value.absent(),
            Value<String> data = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<bool> isSynced = const Value.absent(),
            Value<DateTime?> syncedAt = const Value.absent(),
            Value<String?> error = const Value.absent(),
          }) =>
              SyncQueueItemsCompanion(
            id: id,
            entityTable: entityTable,
            recordId: recordId,
            operation: operation,
            data: data,
            createdAt: createdAt,
            isSynced: isSynced,
            syncedAt: syncedAt,
            error: error,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String entityTable,
            required String recordId,
            required String operation,
            required String data,
            required DateTime createdAt,
            Value<bool> isSynced = const Value.absent(),
            Value<DateTime?> syncedAt = const Value.absent(),
            Value<String?> error = const Value.absent(),
          }) =>
              SyncQueueItemsCompanion.insert(
            id: id,
            entityTable: entityTable,
            recordId: recordId,
            operation: operation,
            data: data,
            createdAt: createdAt,
            isSynced: isSynced,
            syncedAt: syncedAt,
            error: error,
          ),
        ));
}

class $$SyncQueueItemsTableFilterComposer
    extends FilterComposer<_$MedSentryDatabase, $SyncQueueItemsTable> {
  $$SyncQueueItemsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get entityTable => $state.composableBuilder(
      column: $state.table.entityTable,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get recordId => $state.composableBuilder(
      column: $state.table.recordId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get operation => $state.composableBuilder(
      column: $state.table.operation,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get data => $state.composableBuilder(
      column: $state.table.data,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isSynced => $state.composableBuilder(
      column: $state.table.isSynced,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get syncedAt => $state.composableBuilder(
      column: $state.table.syncedAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get error => $state.composableBuilder(
      column: $state.table.error,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$SyncQueueItemsTableOrderingComposer
    extends OrderingComposer<_$MedSentryDatabase, $SyncQueueItemsTable> {
  $$SyncQueueItemsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get entityTable => $state.composableBuilder(
      column: $state.table.entityTable,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get recordId => $state.composableBuilder(
      column: $state.table.recordId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get operation => $state.composableBuilder(
      column: $state.table.operation,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get data => $state.composableBuilder(
      column: $state.table.data,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isSynced => $state.composableBuilder(
      column: $state.table.isSynced,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get syncedAt => $state.composableBuilder(
      column: $state.table.syncedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get error => $state.composableBuilder(
      column: $state.table.error,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$MedicalSnippetsTableCreateCompanionBuilder = MedicalSnippetsCompanion
    Function({
  required String id,
  required String shortcut,
  required String title,
  required String content,
  Value<String?> category,
  Value<bool> isActive,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$MedicalSnippetsTableUpdateCompanionBuilder = MedicalSnippetsCompanion
    Function({
  Value<String> id,
  Value<String> shortcut,
  Value<String> title,
  Value<String> content,
  Value<String?> category,
  Value<bool> isActive,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$MedicalSnippetsTableTableManager extends RootTableManager<
    _$MedSentryDatabase,
    $MedicalSnippetsTable,
    MedicalSnippetEntity,
    $$MedicalSnippetsTableFilterComposer,
    $$MedicalSnippetsTableOrderingComposer,
    $$MedicalSnippetsTableCreateCompanionBuilder,
    $$MedicalSnippetsTableUpdateCompanionBuilder> {
  $$MedicalSnippetsTableTableManager(
      _$MedSentryDatabase db, $MedicalSnippetsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$MedicalSnippetsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$MedicalSnippetsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> shortcut = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<String?> category = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MedicalSnippetsCompanion(
            id: id,
            shortcut: shortcut,
            title: title,
            content: content,
            category: category,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String shortcut,
            required String title,
            required String content,
            Value<String?> category = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              MedicalSnippetsCompanion.insert(
            id: id,
            shortcut: shortcut,
            title: title,
            content: content,
            category: category,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
        ));
}

class $$MedicalSnippetsTableFilterComposer
    extends FilterComposer<_$MedSentryDatabase, $MedicalSnippetsTable> {
  $$MedicalSnippetsTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get shortcut => $state.composableBuilder(
      column: $state.table.shortcut,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get title => $state.composableBuilder(
      column: $state.table.title,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get content => $state.composableBuilder(
      column: $state.table.content,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get category => $state.composableBuilder(
      column: $state.table.category,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isActive => $state.composableBuilder(
      column: $state.table.isActive,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$MedicalSnippetsTableOrderingComposer
    extends OrderingComposer<_$MedSentryDatabase, $MedicalSnippetsTable> {
  $$MedicalSnippetsTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get shortcut => $state.composableBuilder(
      column: $state.table.shortcut,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get title => $state.composableBuilder(
      column: $state.table.title,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get content => $state.composableBuilder(
      column: $state.table.content,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get category => $state.composableBuilder(
      column: $state.table.category,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isActive => $state.composableBuilder(
      column: $state.table.isActive,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get updatedAt => $state.composableBuilder(
      column: $state.table.updatedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

class $MedSentryDatabaseManager {
  final _$MedSentryDatabase _db;
  $MedSentryDatabaseManager(this._db);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db, _db.users);
  $$PatientsTableTableManager get patients =>
      $$PatientsTableTableManager(_db, _db.patients);
  $$QueueItemsTableTableManager get queueItems =>
      $$QueueItemsTableTableManager(_db, _db.queueItems);
  $$ConsultationsTableTableManager get consultations =>
      $$ConsultationsTableTableManager(_db, _db.consultations);
  $$DocumentsTableTableManager get documents =>
      $$DocumentsTableTableManager(_db, _db.documents);
  $$AuditLogsTableTableManager get auditLogs =>
      $$AuditLogsTableTableManager(_db, _db.auditLogs);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$SyncQueueItemsTableTableManager get syncQueueItems =>
      $$SyncQueueItemsTableTableManager(_db, _db.syncQueueItems);
  $$MedicalSnippetsTableTableManager get medicalSnippets =>
      $$MedicalSnippetsTableTableManager(_db, _db.medicalSnippets);
}
