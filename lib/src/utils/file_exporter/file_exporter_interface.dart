abstract class FileExporter {
  Future<String> exportTextFile({
    required String filename,
    required String content,
  });
  Future<void> shareFile(
    String filePath, {
    required String subject,
    required String text,
  });
}
