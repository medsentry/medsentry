import 'document_storage_interface.dart';

DocumentFileStorage createDocumentFileStorage() => throw UnsupportedError(
  'Cannot create document file storage without dart:io or dart:js_interop.',
);
