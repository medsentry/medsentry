import 'file_exporter_interface.dart';

FileExporter createFileExporter() => throw UnsupportedError(
  'Cannot create file exporter without dart:io or dart:js_interop.',
);
