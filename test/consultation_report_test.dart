import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/models/consultation.dart';
import 'package:medsentry/src/providers/reports_provider.dart';
import 'package:medsentry/src/services/report_pdf_service.dart';
import 'package:medsentry/src/models/system_settings.dart';

void main() {
  ConsultationReportEntry entry(String id, DateTime? date) {
    return ConsultationReportEntry(
      consultation: Consultation(
        id: id,
        patientId: 'patient-$id',
        consultationDate: date,
        createdAt: DateTime(2026, 1, 1),
      ),
      patient: null,
      provider: null,
    );
  }

  test('consultation report filter includes both date boundaries', () {
    final entries = [
      entry('before', DateTime(2026, 10, 1, 23, 59)),
      entry('start', DateTime(2026, 10, 2)),
      entry('end', DateTime(2026, 10, 4, 23, 59)),
      entry('after', DateTime(2026, 10, 5)),
      entry('no-date', null),
    ];

    final filtered = filterConsultationReportEntries(
      entries: entries,
      startDate: DateTime(2026, 10, 2),
      endDate: DateTime(2026, 10, 4),
    );

    expect(filtered.map((item) => item.consultation.id), ['start', 'end']);
  });

  test('consultation report PDF can be generated with visit rows', () async {
    final pdf = await const ReportPdfService().generateConsultationHistoryPdf(
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 10, 31),
      visitRows: const [
        ['Test Patient', 'Oct 16, 2026', 'Test Provider', 'Assessment', 'Plan'],
      ],
      settings: const SystemSettings(),
      preparedByName: 'Test Staff',
      preparedByRole: 'Staff',
    );

    expect(String.fromCharCodes(pdf.take(4)), '%PDF');
  });
}
