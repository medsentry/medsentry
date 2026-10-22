import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A camera the user can pick in the scanner.
class DocumentCameraInfo {
  /// Platform identifier (browser deviceId or plugin camera name).
  final String id;

  /// Human-readable name, e.g. "Integrated Webcam".
  final String label;

  const DocumentCameraInfo({required this.id, required this.label});

  @override
  bool operator ==(Object other) =>
      other is DocumentCameraInfo && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Live camera used by the document scanner to photograph pages.
///
/// [start] picks a camera on its own: the one used last time if it is still
/// connected, otherwise a rear or document-facing camera, otherwise whatever
/// the device offers.
abstract class DocumentCamera {
  /// Cameras found on this device. Filled in by [start].
  List<DocumentCameraInfo> get cameras;

  /// The camera currently streaming, or `null` when stopped.
  DocumentCameraInfo? get active;

  /// Opens [camera], or the automatically chosen camera when omitted.
  ///
  /// Throws [DocumentCameraException] with a user-friendly message on failure.
  Future<void> start({DocumentCameraInfo? camera});

  /// Live preview of the running camera.
  Widget buildPreview();

  /// Photographs the current frame and returns it as image bytes.
  Future<Uint8List> capture();

  /// Releases the camera so the device light turns off.
  Future<void> stop();
}

class DocumentCameraException implements Exception {
  final String message;

  const DocumentCameraException(this.message);

  @override
  String toString() => message;
}

const _lastCameraKey = 'medsentry.scanner.last_camera_id';

/// Id of the camera used last time, so the scanner reopens the same one.
Future<String?> readLastCameraId() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastCameraKey);
  } catch (_) {
    return null;
  }
}

Future<void> rememberCameraId(String id) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastCameraKey, id);
  } catch (_) {
    // Remembering the camera is a convenience; ignore storage failures.
  }
}
