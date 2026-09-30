class GeneratedReport {
  final String id;
  final String title;
  final String type;
  final DateTime generatedAt;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? filePath;

  GeneratedReport({
    required this.id,
    required this.title,
    required this.type,
    required this.generatedAt,
    this.startDate,
    this.endDate,
    this.filePath,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
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
      title: json['title'] as String,
      type: json['type'] as String,
      generatedAt: DateTime.parse(json['generated_at'] as String),
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : null,
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      filePath: json['file_path'] as String?,
    );
  }
}
