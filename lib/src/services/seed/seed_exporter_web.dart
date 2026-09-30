import 'seed_exporter_interface.dart';

class WebSeedExporter implements SeedExporter {
  @override
  Future<dynamic> exportToFile(String outputPath, String content) async {
    return content;
  }
}

SeedExporter createSeedExporter() => WebSeedExporter();
