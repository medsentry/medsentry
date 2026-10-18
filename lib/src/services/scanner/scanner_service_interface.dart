import 'dart:typed_data';

/// Reads one page from a connected flatbed or sheet-fed scanner.
abstract class ScannerService {
  /// Whether this platform can talk to a scanner at all.
  bool get isSupported;

  /// Opens the system scanner dialog and returns the scanned page as image
  /// bytes (JPEG/PNG/BMP), or `null` if the user cancelled.
  ///
  /// Throws [ScannerException] with a user-friendly message on failure.
  Future<Uint8List?> scanPage();
}

class ScannerException implements Exception {
  final String message;

  const ScannerException(this.message);

  @override
  String toString() => message;
}

