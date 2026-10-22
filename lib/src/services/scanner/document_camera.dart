export 'document_camera_interface.dart';
export 'document_camera_stub.dart'
    if (dart.library.io) 'document_camera_io.dart'
    if (dart.library.js_interop) 'document_camera_web.dart';
