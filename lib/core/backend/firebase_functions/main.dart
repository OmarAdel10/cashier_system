// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import '../auth/firebase_auth_service.dart';
import '../database/real_time_db.dart';
import '../../config/env_config.dart';

/// Initializes Firebase and Firebase Auth for the application.
///
/// This should be called early in the app bootstrap process, before
/// any Firebase services are used.
///
/// Returns [Either<Failure, void>] - Right on success, Left with [DatabaseFailure] on error.
Future<Either<Failure, void>> initializeFirebase() async {
  try {
    // Use default Firebase initialization from dart-defines
    await Firebase.initializeApp();

    // Optional: Configure auth settings
    // FirebaseAuth.instance.setLanguageCode('ar'); // Set language for auth emails

    return const Right(null);
  } on FirebaseException catch (e) {
    return Left(
      DatabaseFailure('Firebase initialization failed: ${e.message}', cause: e),
    );
  } catch (e) {
    return Left(
      DatabaseFailure('Firebase initialization failed: $e', cause: e),
    );
  }
}

/// Returns a configured [FirebaseAuthService] instance using the initialized Firebase Auth.
///
/// Must be called after [initializeFirebase] has completed.
FirebaseAuthService createAuthService() {
  return FirebaseAuthService();
}

/// Returns a configured [RealTimeDb] instance for session tracking.
///
/// [tenantId] is the Firebase UID of the business owner/tenant.
/// Must be called after [initializeFirebase] has completed.
RealTimeDb createDatabaseService({required String tenantId}) {
  final database = FirebaseDatabase.instance.ref();
  return RealTimeDb(database: database, tenantId: tenantId);
}
