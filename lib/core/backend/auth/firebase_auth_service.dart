// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'package:firebase_auth/firebase_auth.dart';

/// Firebase Auth service with tenant ID model.
///
/// The tenant_id is the Firebase UID of the business owner/tenant.
/// All devices and local users belong to this tenant.
class FirebaseAuthService {
  final FirebaseAuth _auth;

  /// The Firebase UID of the currently authenticated user/tenant.
  final String tenantId;
  final String? currentUserUid;

  /// Creates a new FirebaseAuthService instance.
  /// Verifies that the tenant ID is derived from the Firebase UID.
  ///
  /// For testing, pass a mock [FirebaseAuth] instance.
  FirebaseAuthService({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance,
      tenantId = (auth ?? FirebaseAuth.instance).currentUser?.uid ?? '',
      currentUserUid = (auth ?? FirebaseAuth.instance).currentUser?.uid;

  /// Returns the current tenant ID (Firebase UID).
  /// This is the unique identifier for the business/tenant.
  String getCurrentTenantId() => _auth.currentUser?.uid ?? '';

  /// Checks if a user is currently authenticated.
  bool get isAuthenticated => _auth.currentUser != null;
}
