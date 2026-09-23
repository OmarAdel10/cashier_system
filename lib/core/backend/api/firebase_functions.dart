// Copyright (c) 2024 Daftari POS. All rights reserved.
//
// Firebase initialization for Daftari POS.
//
// Firebase is used ONLY for Authentication (Google OAuth + magic link).
// All server-side logic lives in Cloudflare Workers (lib/core/backend/workers/).
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:cashier_system/core/config/env_config.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';

/// Initializes Firebase via dart-defines + environment config.
Future<Either<Failure, void>> initializeFirebase() async {
  try {
    final options = FirebaseOptions(
      apiKey: EnvConfig.firebaseProjectId,
      appId: '1:firebase-app-id',
      messagingSenderId: 'not-used',
      projectId: EnvConfig.firebaseProjectId,
      authDomain: '${EnvConfig.firebaseProjectId}.firebaseapp.com',
      databaseURL: 'https://${EnvConfig.firebaseProjectId}.firebaseio.com',
      storageBucket: '${EnvConfig.firebaseProjectId}.appspot.com',
    );
    await Firebase.initializeApp(options: options);
    return const Right(null);
  } on Exception catch (e) {
    return Left(DatabaseFailure('Firebase init failed: $e', cause: e));
  }
}
