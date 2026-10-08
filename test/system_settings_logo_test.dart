import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/models/system_settings.dart';

void main() {
  test('system logo is preserved when settings are serialized', () {
    const logoDataUri = 'data:image/png;base64,aGVsbG8=';
    final settings = const SystemSettings().copyWith(
      clinicName: 'Madrid RHU',
      logoDataUri: logoDataUri,
    );

    final restored = SystemSettings.fromJson(settings.toJson());

    expect(restored.clinicName, 'Madrid RHU');
    expect(restored.logoDataUri, logoDataUri);
    expect(restored.copyWith(logoDataUri: '').logoDataUri, isEmpty);
  });
}
