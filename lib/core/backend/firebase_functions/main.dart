// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'package:firebase_core/firebase_core.dart';
import '../auth/firebase_auth_service.dart';

/// Initializes Firebase and Firebase Auth for the application.
///
/// This should be called early in the app bootstrap process, before
/// any Firebase services are used.
Future<void> initializeFirebase() async {
  await Firebase.initializeApp();

  // Optional: Configure auth settings
  // FirebaseAuth.instance.setLanguageCode('ar'); // Set language for auth emails
}

/// Returns a configured [FirebaseAuthService] instance using the initialized Firebase Auth.
///
/// Must be called after [initializeFirebase] has completed.
FirebaseAuthService createAuthService() {
  return FirebaseAuthService();
}
