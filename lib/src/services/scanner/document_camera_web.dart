import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'document_camera_interface.dart';

DocumentCamera createDocumentCamera() => _BrowserDocumentCamera();

/// Browser camera driven directly through getUserMedia.
///
/// The camera plugin's web implementation opens every camera on the device
/// one after another just to learn which way each faces, then opens the
/// chosen one again; on Windows each open can take seconds. Here a single
/// getUserMedia call lets the browser pick the camera, and the device list
/// comes from enumerateDevices, which needs no extra streams.
class _BrowserDocumentCamera implements DocumentCamera {
  final web.HTMLVideoElement _video = web.HTMLVideoElement()
    ..autoplay = true
    ..muted = true
    ..playsInline = true;

  web.MediaStream? _stream;
  List<DocumentCameraInfo> _cameras = const [];
  DocumentCameraInfo? _active;

  _BrowserDocumentCamera() {
    _video.style
      ..width = '100%'
      ..height = '100%'
      ..objectFit = 'contain'
      ..backgroundColor = 'black';
  }

  @override
  List<DocumentCameraInfo> get cameras => _cameras;

  @override
  DocumentCameraInfo? get active => _active;

  @override
  Future<void> start({DocumentCameraInfo? camera}) async {
    await stop();

    final mediaDevices = web.window.navigator.mediaDevices;
    final rememberedId = camera == null ? await readLastCameraId() : null;

    Future<web.MediaStream> open(Map<String, Object> source) {
      final video = <String, Object>{
        ...source,
        'width': {'ideal': 1920},
        'height': {'ideal': 1080},
      };
      return mediaDevices
          .getUserMedia(
            web.MediaStreamConstraints(video: video.jsify()!, audio: false.toJS),
          )
          .toDart;
    }

    // Rear camera on phones and tablets; the system default on computers.
    const automatic = <String, Object>{
      'facingMode': {'ideal': 'environment'},
    };

    web.MediaStream stream;
    try {
      if (camera != null) {
        stream = await open({
          'deviceId': {'exact': camera.id},
        });
      } else if (rememberedId != null && rememberedId.isNotEmpty) {
        stream = await open({
          'deviceId': {'ideal': rememberedId},
        });
      } else {
        stream = await open(automatic);
      }
    } catch (e) {
      // A chosen or remembered camera may have been unplugged: fall back to
      // automatic selection before giving up.
      if (camera == null && rememberedId == null) throw _describe(e);
      try {
        stream = await open(automatic);
      } catch (e) {
        throw _describe(e);
      }
    }

    _stream = stream;
    _video.srcObject = stream;
    try {
      await _video.play().toDart;
    } catch (_) {
      // Autoplay of a muted inline video is allowed everywhere we run; if a
      // browser still refuses, the element starts once it is on screen.
    }

    final tracks = stream.getVideoTracks().toDart;
    final activeId = tracks.isEmpty ? '' : tracks.first.getSettings().deviceId;
    final activeLabel = tracks.isEmpty ? '' : tracks.first.label;

    // Labels are only readable after permission, i.e. now.
    try {
      final devices = (await mediaDevices.enumerateDevices().toDart).toDart;
      var n = 0;
      _cameras = [
        for (final d in devices)
          if (d.kind == 'videoinput')
            DocumentCameraInfo(
              id: d.deviceId,
              label: d.label.isNotEmpty ? d.label : 'Camera ${++n}',
            ),
      ];
    } catch (_) {
      _cameras = const [];
    }

    _active =
        _cameras.where((c) => c.id == activeId).firstOrNull ??
        DocumentCameraInfo(
          id: activeId,
          label: activeLabel.isNotEmpty ? activeLabel : 'Camera',
        );
    if (_cameras.isEmpty) _cameras = [_active!];
    if (activeId.isNotEmpty) await rememberCameraId(activeId);
  }

  static DocumentCameraException _describe(Object error) {
    final text = error.toString();
    if (text.contains('NotAllowedError') || text.contains('SecurityError')) {
      return const DocumentCameraException(
        'Camera access is blocked. Allow the camera for this site in your '
        'browser settings, then try again.',
      );
    }
    if (text.contains('NotFoundError') || text.contains('Overconstrained')) {
      return const DocumentCameraException(
        'No camera or webcam detected on this device.',
      );
    }
    if (text.contains('NotReadableError') || text.contains('AbortError')) {
      return const DocumentCameraException(
        'The camera is being used by another app or tab. Close it there and '
        'try again.',
      );
    }
    return DocumentCameraException('Failed to open camera: $text');
  }

  @override
  Widget buildPreview() {
    return HtmlElementView.fromTagName(
      tagName: 'div',
      onElementCreated: (element) {
        final container = element as web.HTMLElement;
        container.style
          ..width = '100%'
          ..height = '100%'
          ..backgroundColor = 'black';
        container.append(_video);
      },
    );
  }

  @override
  Future<Uint8List> capture() async {
    final width = _video.videoWidth;
    final height = _video.videoHeight;
    if (_stream == null || width == 0 || height == 0) {
      throw const DocumentCameraException(
        'The camera is still starting. Try again in a moment.',
      );
    }

    // Full sensor resolution, independent of how large the preview is drawn.
    final canvas = web.HTMLCanvasElement()
      ..width = width
      ..height = height;
    final context = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    context.drawImage(_video, 0, 0);

    final completer = Completer<web.Blob?>();
    canvas.toBlob(
      ((web.Blob? blob) => completer.complete(blob)).toJS,
      'image/jpeg',
      0.92.toJS,
    );
    final blob = await completer.future;
    if (blob == null) {
      throw const DocumentCameraException('Failed to capture photo.');
    }
    final buffer = await blob.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  }

  @override
  Future<void> stop() async {
    final stream = _stream;
    _stream = null;
    _active = null;
    if (stream == null) return;
    for (final track in stream.getTracks().toDart) {
      track.stop();
    }
    _video.srcObject = null;
  }
}
