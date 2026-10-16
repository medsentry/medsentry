import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/models/document.dart';

void main() {
  group('MedicalDocument status compatibility', () {
    MedicalDocument readDocumentWithStatus(String status) {
      return MedicalDocument.fromJson({
        'id': 'document-1',
        'patient_id': 'patient-1',
        'type': 'labResult',
        'title': 'Lab result',
        'file_path': '',
        'file_size': 0,
        'status': status,
      });
    }

    test('legacy pending and verified statuses load as active', () {
      expect(readDocumentWithStatus('pending').status, DocumentStatus.active);
      expect(readDocumentWithStatus('pending').statusDisplay, 'Active');
      expect(readDocumentWithStatus('verified').status, DocumentStatus.active);
      expect(readDocumentWithStatus('verified').statusDisplay, 'Active');
    });

    test('active documents serialize without review statuses', () {
      final json = MedicalDocument(
        id: 'document-1',
        patientId: 'patient-1',
        type: DocumentType.labResult,
        title: 'Lab result',
        filePath: '',
        fileSize: 0,
      ).toJson();

      expect(json['status'], 'active');
      expect(json.containsKey('verified_by'), isFalse);
      expect(json.containsKey('verified_date'), isFalse);
    });

    test('archived documents retain their status', () {
      expect(
        readDocumentWithStatus('archived').status,
        DocumentStatus.archived,
      );
    });

    test('unsupported statuses are rejected', () {
      expect(() => readDocumentWithStatus('unknown'), throwsFormatException);
    });
  });
}
