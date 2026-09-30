import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';

/// PBKDF2-HMAC-SHA256 password hashing used for local MedSentry accounts.
class PasswordCrypto {
  /// On web (single-threaded JS without WebCrypto workers), 2,000 iterations keeps UI responsive (<10ms).
  /// On native desktop/mobile VM, 120,000 iterations provides hardened server-grade derivation.
  static const int hashIterations = kIsWeb ? 2000 : 120000;

  static final Map<String, String> _deterministicCache = {};

  static String hash(String password) {
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final digest = _pbkdf2(password, salt, hashIterations);
    return 'pbkdf2_sha256:$hashIterations:${base64Encode(salt)}:${base64Encode(digest)}';
  }

  /// Deterministic hash for reproducible seed databases (dev/sample data only).
  static String hashWithSalt(String password, List<int> salt) {
    final digest = _pbkdf2(password, salt, hashIterations);
    return 'pbkdf2_sha256:$hashIterations:${base64Encode(salt)}:${base64Encode(digest)}';
  }

  /// Reproducible hash for dev seed data only — never use in production auth.
  static String hashDeterministic(String password, String seedLabel) {
    final key = '$password:$seedLabel';
    return _deterministicCache[key] ??= hashWithSalt(
      password,
      _deterministicSalt(seedLabel),
    );
  }

  static List<int> _deterministicSalt(String seed) {
    final digest = sha256.convert(utf8.encode('medsentry:$seed')).bytes;
    return digest.sublist(0, 16);
  }

  static bool verify(String password, String storedHash) {
    final parts = storedHash.split(':');
    if (parts.length == 4 && parts[0] == 'pbkdf2_sha256') {
      final iterations = int.tryParse(parts[1]);
      if (iterations == null) return false;
      final salt = base64Decode(parts[2]);
      final expected = base64Decode(parts[3]);
      final actual = _pbkdf2(password, salt, iterations);
      return _constantTimeEquals(actual, expected);
    }

    return _constantTimeEquals(
      utf8.encode(sha256.convert(utf8.encode(password)).toString()),
      utf8.encode(storedHash),
    );
  }

  static List<int> _pbkdf2(String password, List<int> salt, int iterations) {
    const keyLength = 32;
    final hmac = Hmac(sha256, utf8.encode(password));
    final blockInput = <int>[...salt, 0, 0, 0, 1];
    var block = hmac.convert(blockInput).bytes;
    final result = List<int>.from(block);

    for (var i = 1; i < iterations; i++) {
      block = hmac.convert(block).bytes;
      for (var j = 0; j < keyLength; j++) {
        result[j] ^= block[j];
      }
    }

    return result;
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
