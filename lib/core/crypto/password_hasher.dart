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
