import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class SystemLogo extends StatelessWidget {
  final String dataUri;
  final double size;
  final double iconSize;
  final Color backgroundColor;
  final Color iconColor;
  final double borderRadius;

  const SystemLogo({
    super.key,
    required this.dataUri,
    required this.size,
    required this.backgroundColor,
    required this.iconColor,
    this.iconSize = 24,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final imageBytes = _decodeImage();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageBytes == null
          ? Icon(Icons.local_hospital, color: iconColor, size: iconSize)
          : Image.memory(
              imageBytes,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(Icons.local_hospital, color: iconColor, size: iconSize),
            ),
    );
  }

  Uint8List? _decodeImage() {
    if (!dataUri.startsWith('data:image/')) return null;
    final separator = dataUri.indexOf(',');
    if (separator < 0) return null;
    try {
      return base64Decode(dataUri.substring(separator + 1));
    } on FormatException {
      return null;
    }
  }
}
