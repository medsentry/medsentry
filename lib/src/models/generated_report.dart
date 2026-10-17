class GeneratedReport {
  final String id;
  final String? clinicId;
  final String title;
  final String type;
  final DateTime generatedAt;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? filePath;

  GeneratedReport({
    required this.id,
    this.clinicId,
    required this.title,
    required this.type,
    required this.generatedAt,
    this.startDate,
    this.endDate,
    this.filePath,
  });

  GeneratedReport copyWith({
    String? id,
    String? clinicId,
    String? title,
    String? type,
    DateTime? generatedAt,
    DateTime? startDate,
    DateTime? endDate,
    String? filePath,
  }) {
    return GeneratedReport(
      id: id ?? this.id,
      clinicId: clinicId ?? this.clinicId,
      title: title ?? this.title,
      type: type ?? this.type,
      generatedAt: generatedAt ?? this.generatedAt,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      filePath: filePath ?? this.filePath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (clinicId != null) 'clinic_id': clinicId,
      'title': title,
      'type': type,
      'generated_at': generatedAt.toIso8601String(),
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'file_path': filePath,
    };
  }

  factory GeneratedReport.fromJson(Map<String, dynamic> json) {
    return GeneratedReport(
      id: json['id'] as String,
      clinicId: json['clinic_id'] as String?,
      title: json['title'] as String,
      type: json['type'] as String,
      generatedAt: DateTime.tryParse(json['generated_at']?.toString() ?? '') ??
          DateTime.now(),
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'] as String)
          : null,
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'] as String)
          : null,
      filePath: json['file_path'] as String?,
    );
  }
}
