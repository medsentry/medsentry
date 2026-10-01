class Clinic {
  final String id;
  final String name;
  final String code;
  final String? address;
  final String? contactNumber;
  final String? email;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Clinic({
    required this.id,
    required this.name,
    required this.code,
    this.address,
    this.contactNumber,
    this.email,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status.toLowerCase() == 'active';

  Clinic copyWith({
    String? id,
    String? name,
    String? code,
    String? address,
    String? contactNumber,
    String? email,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Clinic(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      address: address ?? this.address,
      contactNumber: contactNumber ?? this.contactNumber,
      email: email ?? this.email,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      if (address != null) 'address': address,
      if (contactNumber != null) 'contact_number': contactNumber,
      if (email != null) 'email': email,
      'status': status,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  factory Clinic.fromJson(Map<String, dynamic> json) {
    return Clinic(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      address: json['address'] as String?,
      contactNumber: json['contact_number'] as String?,
      email: json['email'] as String?,
      status: json['status'] as String? ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Clinic && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Clinic(id: $id, name: $name, code: $code, status: $status)';
}
