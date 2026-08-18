import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'key_store.dart';

class Ed25519Verifier {
  final SimplePublicKey _publicKey;

  Ed25519Verifier()
    : _publicKey = SimplePublicKey(
        Uint8List.fromList(_hexToBytes(_validateKey(ed25519PublicKeyHex))),
        type: KeyPairType.ed25519,
      );

  static String _validateKey(String hex) {
    if (hex.isEmpty) {
      throw StateError(
        'ED25519_PUBKEY_HEX not set. '
        'Pass --dart-define=ED25519_PUBKEY_HEX=<hex> to flutter run/build.',
      );
    }
    return hex;
  }

  Ed25519Verifier.fromPublicKeyHex(String hexPublicKey)
    : _publicKey = SimplePublicKey(
        Uint8List.fromList(_hexToBytes(hexPublicKey)),
        type: KeyPairType.ed25519,
      );

  static List<int> _hexToBytes(String hex) {
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  Future<bool> verifySignature({
    required String deviceId,
    required String activationKey,
  }) async {
    try {
      final signatureBytes = base64Url.decode(activationKey);
      final ed25519 = Ed25519();
      final signature = Signature(
        Uint8List.fromList(signatureBytes),
        publicKey: _publicKey,
      );
      final result = await ed25519.verify(
        Uint8List.fromList(utf8.encode(deviceId)),
        signature: signature,
      );
      return result;
    } catch (_) {
      return false;
    }
  }
}
