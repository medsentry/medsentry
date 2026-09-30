class MunicipalityAddressData {
  final String name;
  final String zipCode;
  final Map<String, List<String>> barangayPuroks;

  const MunicipalityAddressData({
    required this.name,
    required this.zipCode,
    required this.barangayPuroks,
  });
}

const List<String> suffixOptions = [
  'None',
  'Jr.',
  'Sr.',
  'II',
  'III',
  'IV',
  'V',
];

const List<String> defaultPuroks = [
  'Purok 1',
  'Purok 2',
  'Purok 3',
  'Purok 4',
  'Purok 5',
  'Purok 6',
  'Purok 7',
];

Map<String, List<String>> _barangays(List<String> names) {
  return {for (final name in names) name: defaultPuroks};
}

final Map<String, MunicipalityAddressData> municipalityAddressData = {
  'Cantilan': MunicipalityAddressData(
    name: 'Cantilan',
    zipCode: '8317',
    barangayPuroks: _barangays([
      'Bugsukan',
      'Buntalid',
      'Cabangahan',
      'Cabas-an',
      'Calagdaan',
      'Consuelo',
      'General Island',
      'Lininti-an',
      'Lobo',
      'Magasang',
      'Magosilom',
      'Pag-antayan',
      'Palasao',
      'Parang',
      'San Pedro',
      'Tapi',
      'Tigabong',
    ]),
  ),
  'Carrascal': MunicipalityAddressData(
    name: 'Carrascal',
    zipCode: '8318',
    barangayPuroks: _barangays([
      'Adlay',
      'Babuyan',
      'Bacolod',
      'Baybay',
      'Bon-ot',
      'Caglayag',
      'Dahican',
      'Doyos',
      'Embarcadero',
      'Gamuton',
      'Panikian',
      'Pantukan',
      'Saca',
      'Tag-Anito',
    ]),
  ),
  'Carmen': MunicipalityAddressData(
    name: 'Carmen',
    zipCode: '8315',
    barangayPuroks: _barangays([
      'Antao',
      'Cancavan',
      'Carmen',
      'Esperanza',
      'Hinapoyan',
      'Puyat',
      'San Vicente',
      'Santa Cruz',
    ]),
  ),
  'Lanuza': MunicipalityAddressData(
    name: 'Lanuza',
    zipCode: '8314',
    barangayPuroks: _barangays([
      'Agsam',
      'Bocawe',
      'Bunga',
      'Gamuton',
      'Habag',
      'Mampi',
      'Nurcia',
      'Pakwan',
      'Sibahay',
      'Zone I',
      'Zone II',
      'Zone III',
      'Zone IV',
    ]),
  ),
  'Madrid': MunicipalityAddressData(
    name: 'Madrid',
    zipCode: '8316',
    barangayPuroks: _barangays([
      'Bagsac',
      'Bayogo',
      'Linibonan',
      'Magsaysay',
      'Manga',
      'Panayogon',
      'Patong Patong',
      'Quirino',
      'San Antonio',
      'San Juan',
      'San Roque',
      'San Vicente',
      'Songkit',
      'Union',
    ]),
  ),
};

String? formatMiddleInitial(String? value) {
  final letter = value?.trim().replaceAll('.', '');
  if (letter == null || letter.isEmpty) return null;

  final match = RegExp(r'[A-Za-z]').firstMatch(letter);
  if (match == null) return null;

  return '${match.group(0)!.toUpperCase()}.';
}

String? normalizeSuffix(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty || trimmed == 'None') return null;
  return trimmed;
}
