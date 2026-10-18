import 'dart:typed_data';

import 'scanner_service_interface.dart';

/// Platforms without scanner support (web). The UI falls back to the webcam
/// and the regular file picker.
class _UnsupportedScannerService implements ScannerService {
  @override
  bool get isSupported => false;

  @override
  Future<Uint8List?> scanPage() async {
    throw const ScannerException(
      'Scanner access is only available in the Windows desktop app.',
    );
  }
}

ScannerService createScannerService() => _UnsupportedScannerService();
