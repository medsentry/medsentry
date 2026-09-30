abstract class DocumentFileStorage {
  Future<String> saveFile({
    required String documentId,
    required String patientId,
    required List<int> encryptedBytes,
    required String fileName,
  });

  Future<void> openFile(
    String filePath, {
    List<int>? decryptedBytes,
    String? fileName,
  });

  Future<void> deleteFile(String filePath);

  Future<List<int>?> readFile(String filePath);
}
