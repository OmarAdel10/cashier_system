import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/licensing/infrastructure/crypto/ed25519_verifier.dart';

void main() {
  group('Ed25519Verifier', () {
    late SimpleKeyPair keyPair;
    late String publicKeyHex;
    late Ed25519Verifier verifier;

    setUp(() async {
      final ed25519 = Ed25519();
      keyPair = await ed25519.newKeyPair();
      final pk = await keyPair.extractPublicKey();
      publicKeyHex = pk.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      verifier = Ed25519Verifier.fromPublicKeyHex(publicKeyHex);
    });

    test('should verify a valid signature', () async {
      final deviceId = 'CS-A1B2-C3D4';
      final ed25519 = Ed25519();
      final signature = await ed25519.sign(
        utf8.encode(deviceId),
        keyPair: keyPair,
      );

      final result = await verifier.verifySignature(
        deviceId: deviceId,
        activationKey: base64Url.encode(signature.bytes),
      );

      expect(result, isTrue);
    });

    test('should reject signature for different device ID', () async {
      final deviceId = 'CS-A1B2-C3D4';
      final ed25519 = Ed25519();
      final signature = await ed25519.sign(
        utf8.encode(deviceId),
        keyPair: keyPair,
      );

      final result = await verifier.verifySignature(
        deviceId: 'CS-X1X2-X3X4',
        activationKey: base64Url.encode(signature.bytes),
      );

      expect(result, isFalse);
    });

    test('should reject tampered signature bytes', () async {
      final deviceId = 'CS-A1B2-C3D4';
      final ed25519 = Ed25519();
      final signature = await ed25519.sign(
        utf8.encode(deviceId),
        keyPair: keyPair,
      );

      final tamperedBytes = signature.bytes.toList();
      tamperedBytes[0] = tamperedBytes[0] ^ 0xFF;

      final result = await verifier.verifySignature(
        deviceId: deviceId,
        activationKey: base64Url.encode(tamperedBytes),
      );

      expect(result, isFalse);
    });

    test('should reject wrong public key', () async {
      final deviceId = 'CS-A1B2-C3D4';
      final ed25519 = Ed25519();
      final otherPair = await ed25519.newKeyPair();
      final signature = await ed25519.sign(
        utf8.encode(deviceId),
        keyPair: otherPair,
      );

      final result = await verifier.verifySignature(
        deviceId: deviceId,
        activationKey: base64Url.encode(signature.bytes),
      );

      expect(result, isFalse);
    });

    test('should reject invalid base64 input', () async {
      final result = await verifier.verifySignature(
        deviceId: 'CS-A1B2-C3D4',
        activationKey: '!!!not-valid-base64!!!',
      );

      expect(result, isFalse);
    });

    test('should reject empty activation key', () async {
      final result = await verifier.verifySignature(
        deviceId: 'CS-A1B2-C3D4',
        activationKey: '',
      );

      expect(result, isFalse);
    });

    test('should verify with different device ID formats', () async {
      final ed25519 = Ed25519();
      final testCases = ['CS-ABCD-1234', 'CS-0000-FFFF', 'CS-AAAA-BBBB'];

      for (final deviceId in testCases) {
        final signature = await ed25519.sign(
          utf8.encode(deviceId),
          keyPair: keyPair,
        );
        final result = await verifier.verifySignature(
          deviceId: deviceId,
          activationKey: base64Url.encode(signature.bytes),
        );
        expect(result, isTrue, reason: 'Failed for deviceId: $deviceId');
      }
    });
  });
}
