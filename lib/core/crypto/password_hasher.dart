import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

final _random = Random.secure();

String generateSalt() =>
    base64Url.encode(List.generate(32, (_) => _random.nextInt(256)));

String hashPassword(String password, String salt) {
  final passwordBytes = utf8.encode(password);
  final saltBytes = base64Url.decode(salt);
  const iterations = 100000;
  const keyLength = 32;
  final hmac = Hmac(sha256, passwordBytes);
  final block1 = _pbkdf2Block(hmac, saltBytes, 1, iterations);
  final block2 = _pbkdf2Block(hmac, saltBytes, 2, iterations);
  final result = [...block1, ...block2];
  return base64.encode(result.sublist(0, keyLength));
}

String hashPasswordLegacy(String password, String salt) {
  final passwordBytes = utf8.encode(password);
  final saltBytes = utf8.encode(salt);
  const iterations = 100000;
  const keyLength = 32;
  final hmac = Hmac(sha256, passwordBytes);
  final block1 = _pbkdf2Block(hmac, saltBytes, 1, iterations);
  final block2 = _pbkdf2Block(hmac, saltBytes, 2, iterations);
  final result = [...block1, ...block2];
  return base64.encode(result.sublist(0, keyLength));
}

List<int> _pbkdf2Block(
  Hmac hmac,
  List<int> salt,
  int blockIndex,
  int iterations,
) {
  final block = [
    ...salt,
    (blockIndex >> 24) & 0xff,
    (blockIndex >> 16) & 0xff,
    (blockIndex >> 8) & 0xff,
    blockIndex & 0xff,
  ];
  var u = hmac.convert(block).bytes;
  var t = List<int>.from(u);
  for (var i = 1; i < iterations; i++) {
    u = hmac.convert(u).bytes;
    for (var j = 0; j < t.length; j++) {
      t[j] ^= u[j];
    }
  }
  return t;
}

/// Whether [stored] uses the scheme-tagged format.
bool isTagged(String stored) => stored.startsWith(r'pbkdf2-sha512$');

/// Hashes [password] into the scheme-tagged format:
/// `pbkdf2-sha512$<iterations>$<saltB64Url>$<hashB64>`.
///
/// The salt embeds inside the stored string, so no separate salt column
/// is needed. Byte-compatible with backend/shared/src/password_kdf.ts
/// (PBKDF2-HMAC-SHA512, dkLen 32, hash standard base64).
String hashTagged(
  String password, {
  int iterations = 50000,
  String? saltB64Url,
}) {
  final salt = saltB64Url ?? generateSalt();
  final hash = _pbkdf2Sha512(password, salt, iterations);
  return 'pbkdf2-sha512\$$iterations\$$salt\$$hash';
}

/// Verifies [password] against a scheme-tagged [stored] value.
///
/// Returns false for wrong passwords, malformed values, or unknown
/// schemes. Legacy untagged hashes keep their own login paths.
bool verifyTagged(String stored, String password) {
  final parts = stored.split(r'$');
  if (parts.length != 4 || parts[0] != 'pbkdf2-sha512') return false;
  final iterations = int.tryParse(parts[1]);
  if (iterations == null || iterations <= 0) return false;
  try {
    final actual = _pbkdf2Sha512(password, parts[2], iterations);
    return _constantTimeEquals(actual, parts[3]);
  } on FormatException {
    return false;
  }
}

String _pbkdf2Sha512(String password, String saltB64Url, int iterations) {
  final saltBytes = base64Url.decode(_padBase64(saltB64Url));
  final hmac = Hmac(sha512, utf8.encode(password));
  final block = _pbkdf2Block(hmac, saltBytes, 1, iterations);
  return base64.encode(block.sublist(0, 32));
}

/// Dart's base64 decoder requires canonical length; tolerate unpadded
/// input (the TypeScript worker generates unpadded salts).
String _padBase64(String value) => value + '=' * ((4 - value.length % 4) % 4);

bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}
