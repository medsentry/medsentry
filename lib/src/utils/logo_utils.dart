import 'dart:convert';
import 'dart:typed_data';

Uint8List? decodeLogoDataUri(String dataUri) {
  if (!dataUri.startsWith('data:image/')) return null;
  final separator = dataUri.indexOf(',');
  if (separator < 0) return null;

  try {
    return base64Decode(dataUri.substring(separator + 1));
  } on FormatException {
    return null;
  }
}
