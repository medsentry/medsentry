import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/widgets/forms/app_form_components.dart';

void main() {
  group('Form validation helpers', () {
    test('validates email addresses', () {
      expect(isValidEmailAddress('clinic@example.org'), isTrue);
      expect(isValidEmailAddress('clinic+records@example.org'), isTrue);
      expect(isValidEmailAddress('not-an-email'), isFalse);
      expect(isValidEmailAddress('user@invalid'), isFalse);
    });

    test('validates Philippine mobile numbers', () {
      expect(isValidPhilippinePhone('0917-123-4567'), isTrue);
      expect(isValidPhilippinePhone('+63 917 123 4567'), isTrue);
      expect(isValidPhilippinePhone('12345'), isFalse);
    });

    test('validates names and postal addresses', () {
      expect(isValidPersonName("Jose Dela Cruz"), isTrue);
      expect(isValidPersonName('J'), isFalse);
      expect(isValidPersonName('Jane123'), isFalse);
      expect(isValidPostalAddress('Purok 2, Barangay Poblacion'), isTrue);
      expect(isValidPostalAddress('!!'), isFalse);
    });
  });
}
