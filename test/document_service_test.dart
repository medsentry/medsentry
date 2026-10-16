import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/models/document.dart';
import 'package:medsentry/src/services/document_service.dart';

void main() {
  group('DocumentService', () {
    test('rejects unsupported document extensions', () {
      final picked = DocumentPickerResult(
        name: 'record.exe',
        extension: 'exe',
        size: 4,
        bytes: [1, 2, 3, 4],
      );

      expect(
        () => DocumentService.validatePickedDocument(picked),
        throwsA(isA<DocumentValidationException>()),
      );
    });

    test('rejects empty and oversized documents', () {
      final empty = DocumentPickerResult(
        name: 'empty.pdf',
        extension: 'pdf',
        size: 0,
        bytes: const [],
      );
      final oversized = DocumentPickerResult(
        name: 'large.pdf',
        extension: 'pdf',
        size: DocumentService.maxFileSizeBytes + 1,
        bytes: const [1],
      );

      expect(
        () => DocumentService.validatePickedDocument(empty),
        throwsA(isA<DocumentValidationException>()),
      );
      expect(
        () => DocumentService.validatePickedDocument(oversized),
        throwsA(isA<DocumentValidationException>()),
      );
    });

    test('builds a safe filename with the document extension', () {
      final document = MedicalDocument(
        id: 'document-id',
        patientId: 'patient-id',
        type: DocumentType.labResult,
        title: r'../Lab: Result',
        filePath: 'web://documents/patient-id/document-id',
        fileSize: 10,
        mimeType: 'pdf',
      );

      expect(DocumentService.fileNameForDocument(document), '_Lab_ Result.pdf');
    });

    test('preserves the cloud storage path in document JSON', () {
      final document = MedicalDocument(
        id: 'document-id',
        patientId: 'patient-id',
        type: DocumentType.labResult,
        title: 'Lab Result',
        filePath: 'local-file-path',
        storagePath: 'clinic-id/document-id',
        fileSize: 10,
        mimeType: 'pdf',
      );

      expect(
        MedicalDocument.fromJson(document.toJson()).storagePath,
        'clinic-id/document-id',
      );
    });

    test('round-trips every user-selected document type', () {
      for (final type in DocumentType.values) {
        final document = MedicalDocument(
          id: 'document-${type.name}',
          patientId: 'patient-id',
          type: type,
          title: 'Medical document',
          filePath: 'local-file-path',
          fileSize: 10,
          mimeType: 'png',
        );

        expect(
          MedicalDocument.fromJson(document.toJson()).type,
          type,
          reason: 'The selected ${type.name} type should be preserved.',
        );
      }
    });
  });
}
