export 'document_storage_interface.dart';
export 'document_storage_stub.dart'
    if (dart.library.io) 'document_storage_io.dart'
    if (dart.library.js_interop) 'document_storage_web.dart'
    if (dart.library.html) 'document_storage_web.dart';
