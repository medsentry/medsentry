import 'package:flutter_test/flutter_test.dart';
import 'package:medsentry/src/models/models.dart';
import 'package:medsentry/src/utils/patient_address_data.dart';

void main() {
  group('Patient edit field normalization', () {
    test('handles casing differences and fallback lookups gracefully', () {
      final patient = Patient(
        id: 'test-1',
        firstName: 'Pedro',
        lastName: 'Mendoza',
        middleName: 'L.',
        dateOfBirth: DateTime(1985, 3, 15),
        gender: 'Male', // Title Case from seed/db
        civilStatus: 'Single', // Title Case from seed/db
        contactNumber: '09181111001',
        city: 'madrid', // Lowercase
        barangay: 'San Juan',
        purokSitio: 'Purok 1',
        bloodType: 'o+', // Lowercase
        suffix: 'jr.', // Lowercase
      );

      // Suffix normalization
      final rawSuffix = patient.suffix?.trim();
      final matchedSuffix = suffixOptions.firstWhere(
        (opt) => opt.toLowerCase() == rawSuffix?.toLowerCase(),
        orElse: () => rawSuffix ?? 'None',
      );
      expect(matchedSuffix, 'Jr.');

      // Gender normalization
      final rawGender = patient.gender?.trim().toLowerCase();
      expect(rawGender, 'male');
      const validGenders = ['male', 'female', 'other'];
      expect(validGenders.contains(rawGender), isTrue);

      // Civil status normalization
      final rawCivil = patient.civilStatus?.trim().toLowerCase();
      expect(rawCivil, 'single');
      const validStatuses = [
        'single',
        'married',
        'widowed',
        'separated',
        'live-in',
      ];
      expect(validStatuses.contains(rawCivil), isTrue);

      // Municipality case-insensitive match
      final rawCity = patient.city?.trim();
      final matchedCity = municipalityAddressData.keys.firstWhere(
        (k) => k.toLowerCase() == rawCity?.toLowerCase(),
        orElse: () => rawCity ?? 'Madrid',
      );
      expect(matchedCity, 'Madrid');
      expect(municipalityAddressData.containsKey(matchedCity), isTrue);

      // Barangay resolution
      final barangays = municipalityAddressData[matchedCity]!
          .barangayPuroks
          .keys
          .toList();
      expect(barangays.contains('San Juan'), isTrue);

      // Puroks resolution
      final puroks =
          municipalityAddressData[matchedCity]!.barangayPuroks['San Juan']!;
      expect(puroks.contains('Purok 1'), isTrue);

      // Blood type normalization
      final rawBlood = patient.bloodType?.trim().toUpperCase();
      const validBlood = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
      expect(rawBlood, 'O+');
      expect(validBlood.contains(rawBlood), isTrue);
    });

    test('preserves custom cities and barangays outside standard map', () {
      final customPatient = Patient(
        id: 'test-custom',
        firstName: 'Maria',
        lastName: 'Santos',
        dateOfBirth: DateTime(1990, 1, 1),
        city: 'Sample City',
        barangay: 'Custom Barangay',
        purokSitio: 'Zone 9',
      );

      // Municipality preserves custom city
      final rawCity = customPatient.city?.trim();
      final matchedCity = municipalityAddressData.keys.firstWhere(
        (k) => k.toLowerCase() == rawCity?.toLowerCase(),
        orElse: () => rawCity!,
      );
      expect(matchedCity, 'Sample City');

      // Municipalities list includes custom city
      final municipalities = municipalityAddressData.keys.toList();
      if (!municipalities.contains(matchedCity)) {
        municipalities.add(matchedCity);
      }
      expect(municipalities.contains('Sample City'), isTrue);

      // Barangays list retains custom barangay
      final brgyList = <String>[];
      if (municipalityAddressData.containsKey(matchedCity)) {
        brgyList.addAll(
          municipalityAddressData[matchedCity]!.barangayPuroks.keys,
        );
      }
      if (!brgyList.contains(customPatient.barangay)) {
        brgyList.insert(0, customPatient.barangay!);
      }
      expect(brgyList.contains('Custom Barangay'), isTrue);
      expect(brgyList.first, 'Custom Barangay');
    });
  });
}
