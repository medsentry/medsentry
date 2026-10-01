import 'dart:typed_data';

abstract class FileExporter {
  /// Exports a text file (CSV/JSON).
  Future<String> exportTextFile({
    required String filename,
    required String content,
  });

  /// Prompts the user with a system-native "Save As" file dialog to choose
  /// the save directory and edit/confirm the file name, then writes the bytes.
  /// Returns the saved absolute file path (or filename on Web), or null if the user cancelled.
  Future<String?> saveBinaryFile({
    required String filename,
    required Uint8List bytes,
    String? dialogTitle,
    String mimeType = 'application/pdf',
  });

  /// Opens the file using the default system application (e.g. PDF reader).
  Future<bool> openFile(String filePath);

  /// Shares a file via the system share sheet.
  Future<void> shareFile(
    String filePath, {
    required String subject,
    required String text,
  });
}
