import 'package:flutter/material.dart';
import '../utils/patient_address_data.dart';

/// Patient category enum
enum PatientCategory {
  infant, // 0-1 year
  toddler, // 1-3 years
  preschool, // 3-5 years
  schoolAge, // 6-12 years
  adolescent, // 13-19 years
  adult, // 20-59 years
  senior, // 60+ years
  pregnant,
  pwd, // Person with disability
  seniorCitizen,
  pediatric, // General pediatric category
}

/// PhilHealth category enum
enum PhilHealthCategory {
  directContributor,
  indigent,
  sponsored,
  seniorCitizen,
  lifetime,
}

/// Water source level enum (for FHSIS epidemiology data)
enum WaterSourceLevel {
  level1, // Point source (well, spring)
  level2, // Communal faucet
  level3, // Individual house connection
}

/// Toilet facility type enum
enum ToiletFacilityType {
  waterSealed,
  pitLatrine,
  none, // Open defecation
}

/// Extension for PhilHealthCategory display names
extension PhilHealthCategoryExtension on PhilHealthCategory {
  String get displayName {
    switch (this) {
      case PhilHealthCategory.directContributor:
        return 'Direct Contributor';
      case PhilHealthCategory.indigent:
        return 'Indigent';
      case PhilHealthCategory.sponsored:
        return 'Sponsored';
      case PhilHealthCategory.seniorCitizen:
        return 'Senior Citizen';
      case PhilHealthCategory.lifetime:
        return 'Lifetime Member';
    }
  }
}

/// Extension for WaterSourceLevel display names
extension WaterSourceLevelExtension on WaterSourceLevel {
  String get displayName {
    switch (this) {
      case WaterSourceLevel.level1:
        return 'Level 1: Point Source (Well, Spring)';
      case WaterSourceLevel.level2:
        return 'Level 2: Communal Faucet';
      case WaterSourceLevel.level3:
        return 'Level 3: House Connection';
    }
  }
}

/// Extension for ToiletFacilityType display names
extension ToiletFacilityTypeExtension on ToiletFacilityType {
  String get displayName {
    switch (this) {
      case ToiletFacilityType.waterSealed:
        return 'Water-Sealed';
      case ToiletFacilityType.pitLatrine:
        return 'Pit Latrine';
      case ToiletFacilityType.none:
        return 'None / Open Defecation';
    }
  }
}

extension PatientCategoryExtension on PatientCategory {
  String get displayName {
    switch (this) {
      case PatientCategory.infant:
        return 'Infant';
      case PatientCategory.toddler:
        return 'Toddler';
      case PatientCategory.preschool:
        return 'Preschool';
      case PatientCategory.schoolAge:
        return 'School Age';
      case PatientCategory.adolescent:
        return 'Adolescent';
      case PatientCategory.adult:
        return 'Adult';
      case PatientCategory.senior:
        return 'Senior';
      case PatientCategory.pregnant:
        return 'Pregnant';
      case PatientCategory.pwd:
        return 'PWD';
      case PatientCategory.seniorCitizen:
        return 'Senior Citizen';
      case PatientCategory.pediatric:
        return 'Pediatric';
    }
  }

  Color get color {
    switch (this) {
      case PatientCategory.infant:
      case PatientCategory.toddler:
      case PatientCategory.preschool:
      case PatientCategory.pediatric:
        return Colors.pink;
      case PatientCategory.schoolAge:
      case PatientCategory.adolescent:
        return Colors.green;
      case PatientCategory.pregnant:
        return Colors.purple;
      case PatientCategory.pwd:
        return Colors.orange;
      case PatientCategory.senior:
      case PatientCategory.seniorCitizen:
        return Colors.blue;
      case PatientCategory.adult:
        return Colors.grey;
    }
  }
}

PatientCategory? patientCategoryFromDateOfBirth(DateTime? dateOfBirth) {
  if (dateOfBirth == null) return null;

  final now = DateTime.now();
  var age = now.year - dateOfBirth.year;
  if (now.month < dateOfBirth.month ||
      (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
    age--;
  }

  return patientCategoryFromAge(age);
}

PatientCategory patientCategoryFromAge(int age) {
  if (age < 1) return PatientCategory.infant;
  if (age < 3) return PatientCategory.toddler;
  if (age < 5) return PatientCategory.preschool;
  if (age < 12) return PatientCategory.schoolAge;
  if (age < 19) return PatientCategory.adolescent;
  if (age < 60) return PatientCategory.adult;
  return PatientCategory.senior;
}

class Patient {
  // Basic Identifiers
  final String id;
  final String firstName;
  final String lastName;
  final String? middleName;
  final String? suffix; // Jr., Sr., III, etc.

  // Demographics
  final DateTime? dateOfBirth;
  final String? gender;
  final String? civilStatus;
  final String? religion;

  // Contact Information
  final String? contactNumber;
  final String? email;
  final String? address;
  final String? barangay;
  final String? purokSitio; // Purok/Sitio within barangay
  final String? city;
  final String? province;
  final String? zipCode;

  // Government IDs & Insurance
  final String? philHealthNumber;
  final PhilHealthCategory? philHealthCategory;
  final String? localLguIdNumber; // Local government ID

  // Emergency Contact
  final String? emergencyContactName;
  final String? emergencyContactNumber;
  final String? emergencyContactRelation;

  // Socio-Economic & Vulnerability
  final String? occupation;
  final String? employer;
  final bool isPwd; // Person with disability
  final bool isSoloParent;
  final bool isIndigenousPerson;
  final String? tribeEthnolinguisticGroup; // Conditional on isIndigenousPerson
  final bool is4PsBeneficiary;
  final String? householdIdNumber; // Conditional on is4PsBeneficiary

  // Environmental & Sanitation (FHSIS Data)
  final WaterSourceLevel? waterSource;
  final ToiletFacilityType? toiletFacility;

  // Medical Data
  final String? bloodType;
  final double? height;
  final double? weight;
  final String? allergies;
  final String? medicalHistory;

  // System Fields
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastVisitDate;
  final int? syncStatus;
  final String? syncError;
  final PatientCategory? category;
  final bool isArchived;
  final DateTime? archivedAt;

  Patient({
    required this.id,
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
    this.emergencyContactName,
    this.emergencyContactNumber,
    this.emergencyContactRelation,
    this.occupation,
    this.employer,
    this.isPwd = false,
    this.isSoloParent = false,
    this.isIndigenousPerson = false,
    this.tribeEthnolinguisticGroup,
    this.is4PsBeneficiary = false,
    this.householdIdNumber,
    this.waterSource,
    this.toiletFacility,
    this.bloodType,
    this.height,
    this.weight,
    this.allergies,
    this.medicalHistory,
    this.createdAt,
    this.updatedAt,
    this.lastVisitDate,
    this.syncStatus,
    this.syncError,
    this.category,
    this.isArchived = false,
    this.archivedAt,
  });

  String get fullName {
    final parts = [
      firstName,
      if (formatMiddleInitial(middleName) != null)
        formatMiddleInitial(middleName)!,
      lastName,
      if (normalizeSuffix(suffix) != null) normalizeSuffix(suffix)!,
    ];
    return parts.where((part) => part.trim().isNotEmpty).join(' ');
  }

  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int age = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      age--;
    }
    return age;
  }

  Patient copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? middleName,
    String? suffix,
    DateTime? dateOfBirth,
    String? gender,
    String? civilStatus,
    String? religion,
    String? contactNumber,
    String? email,
    String? address,
    String? barangay,
    String? purokSitio,
    String? city,
    String? province,
    String? zipCode,
    String? philHealthNumber,
    PhilHealthCategory? philHealthCategory,
    String? localLguIdNumber,
    String? emergencyContactName,
    String? emergencyContactNumber,
    String? emergencyContactRelation,
    String? occupation,
    String? employer,
    bool? isPwd,
    bool? isSoloParent,
    bool? isIndigenousPerson,
    String? tribeEthnolinguisticGroup,
    bool? is4PsBeneficiary,
    String? householdIdNumber,
    WaterSourceLevel? waterSource,
    ToiletFacilityType? toiletFacility,
    String? bloodType,
    double? height,
    double? weight,
    String? allergies,
    String? medicalHistory,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastVisitDate,
    int? syncStatus,
    String? syncError,
    PatientCategory? category,
    bool? isArchived,
    DateTime? archivedAt,
  }) {
    return Patient(
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
      bloodType: bloodType ?? this.bloodType,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      allergies: allergies ?? this.allergies,
      medicalHistory: medicalHistory ?? this.medicalHistory,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastVisitDate: lastVisitDate ?? this.lastVisitDate,
      syncStatus: syncStatus ?? this.syncStatus,
      syncError: syncError ?? this.syncError,
      category: category ?? this.category,
      isArchived: isArchived ?? this.isArchived,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'middle_name': middleName,
      'suffix': suffix,
      'date_of_birth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'civil_status': civilStatus,
      'religion': religion,
      'contact_number': contactNumber,
      'email': email,
      'address': address,
      'barangay': barangay,
      'purok_sitio': purokSitio,
      'city': city,
      'province': province,
      'zip_code': zipCode,
      'philhealth_number': philHealthNumber,
      'philhealth_category': philHealthCategory?.name,
      'local_lgu_id': localLguIdNumber,
      'blood_type': bloodType,
      'emergency_contact_name': emergencyContactName,
      'emergency_contact_number': emergencyContactNumber,
      'emergency_contact_relation': emergencyContactRelation,
      'occupation': occupation,
      'employer': employer,
      'is_pwd': isPwd,
      'is_solo_parent': isSoloParent,
      'is_indigenous_person': isIndigenousPerson,
      'tribe_ethnolinguistic_group': tribeEthnolinguisticGroup,
      'is_4ps_beneficiary': is4PsBeneficiary,
      'household_id_number': householdIdNumber,
      'water_source': waterSource?.name,
      'toilet_facility': toiletFacility?.name,
      'height': height,
      'weight': weight,
      'allergies': allergies,
      'medical_history': medicalHistory,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'last_visit_date': lastVisitDate?.toIso8601String(),
      'sync_status': syncStatus,
      'sync_error': syncError,
      'category': category?.name,
      'is_archived': isArchived,
      'archived_at': archivedAt?.toIso8601String(),
    };
  }

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      middleName: json['middle_name'] as String?,
      suffix: json['suffix'] as String?,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'] as String)
          : null,
      gender: json['gender'] as String?,
      civilStatus: json['civil_status'] as String?,
      religion: json['religion'] as String?,
      contactNumber: json['contact_number'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      barangay: json['barangay'] as String?,
      purokSitio: json['purok_sitio'] as String?,
      city: json['city'] as String?,
      province: json['province'] as String?,
      zipCode: json['zip_code'] as String?,
      philHealthNumber: json['philhealth_number'] as String?,
      philHealthCategory: json['philhealth_category'] != null
          ? PhilHealthCategory.values.byName(
              json['philhealth_category'] as String,
            )
          : null,
      localLguIdNumber: json['local_lgu_id'] as String?,
      bloodType: json['blood_type'] as String?,
      emergencyContactName: json['emergency_contact_name'] as String?,
      emergencyContactNumber: json['emergency_contact_number'] as String?,
      emergencyContactRelation: json['emergency_contact_relation'] as String?,
      occupation: json['occupation'] as String?,
      employer: json['employer'] as String?,
      isPwd: json['is_pwd'] as bool? ?? false,
      isSoloParent: json['is_solo_parent'] as bool? ?? false,
      isIndigenousPerson: json['is_indigenous_person'] as bool? ?? false,
      tribeEthnolinguisticGroup: json['tribe_ethnolinguistic_group'] as String?,
      is4PsBeneficiary: json['is_4ps_beneficiary'] as bool? ?? false,
      householdIdNumber: json['household_id_number'] as String?,
      waterSource: json['water_source'] != null
          ? WaterSourceLevel.values.byName(json['water_source'] as String)
          : null,
      toiletFacility: json['toilet_facility'] != null
          ? ToiletFacilityType.values.byName(json['toilet_facility'] as String)
          : null,
      height: json['height'] != null
          ? (json['height'] as num).toDouble()
          : null,
      weight: json['weight'] != null
          ? (json['weight'] as num).toDouble()
          : null,
      allergies: json['allergies'] as String?,
      medicalHistory: json['medical_history'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      lastVisitDate: json['last_visit_date'] != null
          ? DateTime.parse(json['last_visit_date'] as String)
          : null,
      syncStatus: json['sync_status'] as int?,
      syncError: json['sync_error'] as String?,
      category: json['category'] != null
          ? PatientCategory.values.byName(json['category'] as String)
          : null,
      isArchived: json['is_archived'] as bool? ?? false,
      archivedAt: json['archived_at'] != null
          ? DateTime.parse(json['archived_at'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Patient && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class PatientSearchResult {
  final Patient patient;
  final double relevanceScore;

  PatientSearchResult({required this.patient, required this.relevanceScore});
}
