abstract class DatabaseStorage {
  /// Reads the serialized database JSON string from persistent storage.
  Future<String?> readStore();

  /// Writes the serialized database JSON string to persistent storage.
  Future<void> writeStore(String jsonString);

  /// Creates a backup of the database storage and returns a message/path.
  Future<String> createBackup(String jsonString);

  /// Optional custom file injection for testing on IO platforms.
  void setCustomStoreFile(dynamic file) {}
}
