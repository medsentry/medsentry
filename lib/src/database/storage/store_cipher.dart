import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

import '../../utils/password_crypto.dart';

/// Raised when encrypted data cannot be opened: wrong key or passphrase, or
/// the bytes were damaged or altered.
class StoreCipherException implements Exception {
  final String message;

  const StoreCipherException(this.message);

  @override
  String toString() => message;
}

/// Authenticated encryption for patient data written to disk.
///
/// AES-256-CTR with an HMAC-SHA256 tag over the header, nonce and ciphertext
/// (encrypt-then-MAC), so altered or truncated data is rejected rather than
/// decrypted into garbage. AES-GCM would do the same, but the pure-Dart GCM
/// took about 18 s to encrypt a 20 MB store; this takes about 1.5 s.
///
/// Layout: magic | 16-byte nonce | ciphertext | 32-byte tag.
class StoreCipher {
  StoreCipher._();

  static const int _nonceLength = 16;
  static const int _tagLength = 32;

  /// Header of the database file kept on this device.
  static final List<int> deviceStoreMagic = ascii.encode('MSDB01');

  static Uint8List seal(
    List<int> masterKey,
    List<int> plaintext, {
    required List<int> magic,
  }) {
    final keys = _subkeys(masterKey);
    final nonce = encrypt.IV.fromSecureRandom(_nonceLength);
    final ciphertext = _ctr(keys.encryption).encryptBytes(
      plaintext,
      iv: nonce,
    );
    final body = BytesBuilder(copy: false)
      ..add(magic)
      ..add(nonce.bytes)
      ..add(ciphertext.bytes);
    final sealed = body.takeBytes();
    final tag = Hmac(sha256, keys.mac).convert(sealed).bytes;
    return Uint8List.fromList([...sealed, ...tag]);
  }

  static Uint8List open(
    List<int> masterKey,
    List<int> data, {
    required List<int> magic,
  }) {
    if (!hasMagic(data, magic) ||
        data.length < magic.length + _nonceLength + _tagLength) {
      throw const StoreCipherException('Not an encrypted MedSentry file.');
    }
    final keys = _subkeys(masterKey);
    final tagStart = data.length - _tagLength;
    final expected = Hmac(
      sha256,
      keys.mac,
    ).convert(data.sublist(0, tagStart)).bytes;
    if (!_constantTimeEquals(expected, data.sublist(tagStart))) {
      throw const StoreCipherException(
        'The file could not be decrypted: wrong key, or the file is damaged.',
      );
    }
    final nonce = encrypt.IV(
      Uint8List.fromList(
        data.sublist(magic.length, magic.length + _nonceLength),
      ),
    );
    return Uint8List.fromList(
      _ctr(keys.encryption).decryptBytes(
        encrypt.Encrypted(
          Uint8List.fromList(
            data.sublist(magic.length + _nonceLength, tagStart),
          ),
        ),
        iv: nonce,
      ),
    );
  }

  static bool hasMagic(List<int> data, List<int> magic) {
    if (data.length < magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (data[i] != magic[i]) return false;
    }
    return true;
  }

  static Uint8List randomKey() {
    final random = Random.secure();
    return Uint8List.fromList(List<int>.generate(32, (_) => random.nextInt(256)));
  }

  static encrypt.Encrypter _ctr(List<int> key) => encrypt.Encrypter(
    encrypt.AES(
      encrypt.Key(Uint8List.fromList(key)),
      mode: encrypt.AESMode.sic,
      padding: null,
    ),
  );

  // Separate keys for encryption and authentication, derived from one stored
  // key so the device keeps a single secret.
  static ({List<int> encryption, List<int> mac}) _subkeys(List<int> masterKey) {
    final hmac = Hmac(sha256, masterKey);
    return (
      encryption: hmac.convert(ascii.encode('medsentry:encrypt')).bytes,
      mac: hmac.convert(ascii.encode('medsentry:authenticate')).bytes,
    );
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

/// Passphrase-protected database backups.
///
/// The device key never leaves the machine, so a backup sealed with it could
/// not be restored after the computer fails, which is when a backup is
/// needed. Backups are sealed with a key derived from a passphrase instead.
///
/// Layout: magic | 16-byte salt | 4-byte iteration count | sealed store.
class BackupCipher {
  BackupCipher._();

  static final List<int> _magic = ascii.encode('MSBAK1');
  static const int _saltLength = 16;
  static const int defaultIterations = 150000;
  static const int minimumPassphraseLength = 8;
  static const String fileExtension = 'msbak';

  static bool isEncrypted(List<int> data) => StoreCipher.hasMagic(data, _magic);

  static Uint8List seal(
    String json,
    String passphrase, {
    int iterations = defaultIterations,
  }) {
    if (passphrase.length < minimumPassphraseLength) {
      throw ArgumentError(
        'Backup passphrase must be at least $minimumPassphraseLength characters',
      );
    }
    final salt = StoreCipher.randomKey().sublist(0, _saltLength);
    final header = BytesBuilder(copy: false)
      ..add(_magic)
      ..add(salt)
      ..add(_uint32(iterations));
    final headerBytes = header.takeBytes();
    final key = PasswordCrypto.deriveKey(passphrase, salt, iterations);
    // The whole header is the inner magic, so the salt and iteration count
    // are covered by the tag as well.
    return StoreCipher.seal(key, utf8.encode(json), magic: headerBytes);
  }

  static String open(List<int> data, String passphrase) {
    final headerLength = _magic.length + _saltLength + 4;
    if (!isEncrypted(data) || data.length < headerLength) {
      throw const StoreCipherException('Not an encrypted MedSentry backup.');
    }
    final header = data.sublist(0, headerLength);
    final salt = header.sublist(_magic.length, _magic.length + _saltLength);
    final iterations = ByteData.sublistView(
      Uint8List.fromList(header),
    ).getUint32(_magic.length + _saltLength);
    if (iterations < 1000 || iterations > 10000000) {
      throw const StoreCipherException('The backup file is damaged.');
    }
    final key = PasswordCrypto.deriveKey(passphrase, salt, iterations);
    try {
      return utf8.decode(StoreCipher.open(key, data, magic: header));
    } on StoreCipherException {
      throw const StoreCipherException(
        'Wrong passphrase, or the backup file is damaged.',
      );
    }
  }

  static List<int> _uint32(int value) =>
      (ByteData(4)..setUint32(0, value)).buffer.asUint8List();
}
