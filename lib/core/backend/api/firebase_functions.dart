// Copyright (c) 2024 Daftari POS. All rights reserved.

/// Firebase Auth init + services for Daftari POS.
///
/// Firebase itself remains the Auth provider (Google OAuth, magic link,
/// email/password). All server-side sync now happens via Workers in
/// `lib/core/backend/workers/` and `backend/api/`.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/core/config/env_config.dart';

/// Initializes Firebase with env-specific options from dart-defines.
Future<Either<Failure, void>> initializeFirebase() async {
  try {
    final options = FirebaseOptions(
      apiKey: EnvConfig.firebaseProjectId,
      appId: '1:app-id-not-needed',
      messagingSenderId: 'unused',
      projectId: EnvConfig.firebaseProjectId,
      authDomain: '${EnvConfig.firebaseProjectId}.firebaseapp.com',
      databaseURL: 'https://${EnvConfig.firebaseProjectId}.firebaseio.com',
      storageBucket: '${EnvConfig.firebaseProjectId}.appspot.com',
    );
    await Firebase.initializeApp(options: options);
    return const Right(null);
  } on Exception catch (e) {
    return Left(
      DatabaseFailure('Firebase initialization failed: $e', cause: e),
    );
  }
}
