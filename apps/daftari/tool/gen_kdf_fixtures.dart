// Copyright (c) 2026 Daftari POS. All rights reserved.

/// Generates kdf_vectors.json — cross-runtime compatibility fixtures consumed
/// by backend/shared/src/password_kdf.test.ts.
///
/// Dart is the reference implementation: the TypeScript worker must produce
/// byte-identical tagged hashes. Run from the package root
/// (`apps/daftari`):
///   dart run tool/gen_kdf_fixtures.dart
///
/// The output directory defaults to the package root so the tool never writes
/// outside the Flutter package. Set `KDF_FIXTURES_OUTPUT_DIR` to write into
/// `backend/shared/fixtures` explicitly (CI / backend flow).
library;

import 'dart:convert';
import 'dart:io';

import 'package:daftari/core/crypto/password_hasher.dart';

void main() {
  const cases = [
    ('abc123', 1000, 'c2FsdHNhbHQ'),
    ('سلام123', 1000, 'c2FsdHNhbHQ'),
    ('p@ssw0rd!9', 5000, 'c2hvcnQ'),
    (
      'a-very-long-password-with-ن-و-ع-و-م-ر-06',
      1000,
      'MTIzNDU2Nzg5MGFiY2RlZg',
    ),
    ('abc123', 1000, 'c2FsdHNhbHQ='),
  ];

  final vectors = [
    for (final c in cases)
      {
        'password': c.$1,
        'iterations': c.$2,
        'salt_b64url': c.$3,
        'expected': hashTagged(c.$1, iterations: c.$2, saltB64Url: c.$3),
      },
  ];

  // Output directory: env var override for test hermeticity; default to the
  // package root so `dart run tool/gen_kdf_fixtures.dart` never writes outside
  // the Flutter package. Callers/CI pass `KDF_FIXTURES_OUTPUT_DIR` to write
  // into `backend/shared/fixtures` explicitly.
  final outputDir = Directory(
    Platform.environment['KDF_FIXTURES_OUTPUT_DIR'] ?? Directory.current.path,
  );
  outputDir.createSync(recursive: true);
  File('${outputDir.path}/kdf_vectors.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(vectors));
}
