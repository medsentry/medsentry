import 'dart:io';
import 'seed_exporter_interface.dart';

class IoSeedExporter implements SeedExporter {
  @override
  Future<File> exportToFile(String outputPath, String content) async {
    final file = File(outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(content, flush: true);
    return file;
  }
}

SeedExporter createSeedExporter() => IoSeedExporter();
