import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

import 'document_camera_interface.dart';

DocumentCamera createDocumentCamera() => _PluginDocumentCamera();

/// Desktop and mobile camera, backed by the camera plugin.
class _PluginDocumentCamera implements DocumentCamera {
  /// Listing cameras is slow on some drivers, so it runs once per app session.
  static Future<List<CameraDescription>>? _descriptions;

  List<CameraDescription> _found = const [];
  CameraController? _controller;
  CameraDescription? _activeDescription;

  @override
  List<DocumentCameraInfo> get cameras => _found.map(_info).toList();

  @override
  DocumentCameraInfo? get active =>
      _activeDescription == null ? null : _info(_activeDescription!);

  static DocumentCameraInfo _info(CameraDescription d) =>
      DocumentCameraInfo(id: d.name, label: d.name);

  Future<List<CameraDescription>> _listCameras() async {
    final pending = _descriptions ??= availableCameras();
    try {
      final found = await pending;
      // Nothing found may mean a webcam was plugged in later: look again
      // next time instead of caching the empty result.
      if (found.isEmpty) _descriptions = null;
      return found;
    } catch (_) {
      _descriptions = null;
      rethrow;
    }
  }

  /// Rear cameras photograph documents best; front cameras come last.
  static int _rank(CameraDescription d) => switch (d.lensDirection) {
    CameraLensDirection.back => 0,
    CameraLensDirection.external => 1,
    CameraLensDirection.front => 2,
  };

  @override
  Future<void> start({DocumentCameraInfo? camera}) async {
    try {
      _found = await _listCameras();
    } catch (e) {
      throw DocumentCameraException('Unable to look for cameras: $e');
    }
    if (_found.isEmpty) {
      throw const DocumentCameraException(
        'No camera or webcam detected on this device.',
      );
    }

    final wantedId = camera?.id ?? await readLastCameraId();
    final description =
        _found.where((d) => d.name == wantedId).firstOrNull ??
        (List.of(_found)..sort((a, b) => _rank(a) - _rank(b))).first;

    await stop();
    final controller = CameraController(
      description,
      ResolutionPreset.veryHigh,
      enableAudio: false,
    );
    try {
      await controller.initialize();
    } catch (e) {
      await controller.dispose();
      throw DocumentCameraException('Failed to open camera: $e');
    }
    _controller = controller;
    _activeDescription = description;
    await rememberCameraId(description.name);
  }

  @override
  Widget buildPreview() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return CameraPreview(controller);
  }

  @override
  Future<Uint8List> capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw const DocumentCameraException('The camera is not running.');
    }
    final photo = await controller.takePicture();
    return photo.readAsBytes();
  }

  @override
  Future<void> stop() async {
    final controller = _controller;
    _controller = null;
    _activeDescription = null;
    await controller?.dispose();
  }
}
