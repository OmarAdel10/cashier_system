// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'package:firebase_core/firebase_core.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import '../auth/firebase_auth_service.dart';

/// Initializes Firebase and FirebaseAuth for the application. This is the
/// only "Firebase" init code — the real-time sync logic now lives in the
/// daftari-api Cloudflare Worker (/api/config/auth/config.ts) and in
/// lib/core/backend/workers/{auth_sync,session_sync,analytics}_service.dart.
Future<Either<Failure, void>> initializeFirebase() async {
  try {
    await Firebase.initializeApp();
    return const Right(null);
  } on FirebaseException catch (e) {
    return Left(
      DatabaseFailure('Firebase init failed: ${e.message}', cause: e),
    );
  } catch (e) {
    return Left(DatabaseFailure('Firebase init failed: $e', cause: e));
  }
}

/// Returns the configured FirebaseAuthService.
FirebaseAuthService createAuthService() {
  return FirebaseAuthService();
}
