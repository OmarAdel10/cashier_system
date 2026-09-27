// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/core/config/env_config.dart';

/// Firebase Auth service with tenant ID model.
///
/// The tenant_id is the Firebase UID of the business owner/tenant.
/// All devices and local users belong to this tenant.
///
/// Providers (auth-licensing spec §2.1): Google OAuth (primary) +
/// magic link (fallback). Email/Password is DISABLED — its methods were
/// removed in the admin-dashboard Phase 1 (T11).
class FirebaseAuthService {
  final FirebaseAuth _auth;

  /// Creates a new FirebaseAuthService instance.
  ///
  /// For testing, pass a mock [FirebaseAuth] instance.
  FirebaseAuthService({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  /// The Firebase UID of the currently authenticated user/tenant.
  /// Reactive getter - always returns current auth state.
  String get tenantId => _auth.currentUser?.uid ?? '';

  /// The current user's UID, or null if not authenticated.
  String? get currentUserUid => _auth.currentUser?.uid;

  /// Stream of authentication state changes.
  /// Emits [User] when signed in, null when signed out.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Stream of ID token changes (includes token refresh).
  Stream<User?> get idTokenChanges => _auth.idTokenChanges();

  /// Returns the current tenant ID (Firebase UID).
  /// This is the unique identifier for the business/tenant.
  String getCurrentTenantId() => _auth.currentUser?.uid ?? '';

  /// Checks if a user is currently authenticated.
  bool get isAuthenticated => _auth.currentUser != null;

  /// Signs in with Google via a popup (web dashboard primary provider).
  Future<Either<Failure, UserCredential>> signInWithGooglePopup() async {
    try {
      final credential = await _auth.signInWithPopup(GoogleAuthProvider());
      return Right(credential);
    } on FirebaseAuthException catch (e) {
      return Left(DatabaseFailure(e.message ?? 'Sign in failed', cause: e));
    } catch (e) {
      return Left(DatabaseFailure('Sign in failed: $e', cause: e));
    }
  }

  /// Sends a magic-link (email-link) sign-in email. The link lands on the
  /// dashboard origin (finish-login route) and auto-creates the account on
  /// first completion. The email is persisted so the app can complete the
  /// link without re-asking.
  Future<Either<Failure, void>> sendMagicLink({required String email}) async {
    try {
      await _auth.sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: ActionCodeSettings(
          url: '${EnvConfig.adminOrigin}/finish-login',
          handleCodeInApp: true,
        ),
      );
      return const Right(null);
    } on FirebaseAuthException catch (e) {
      return Left(DatabaseFailure(e.message ?? 'Magic link failed', cause: e));
    } catch (e) {
      return Left(DatabaseFailure('Magic link failed: $e', cause: e));
    }
  }

  /// Whether [url] is a pending Firebase email-link sign-in URL.
  bool isSignInWithEmailLink(String url) => _auth.isSignInWithEmailLink(url);

  /// Completes a magic-link sign-in with [email] + [link].
  Future<Either<Failure, UserCredential>> signInWithEmailLink({
    required String email,
    required String link,
  }) async {
    try {
      final credential = await _auth.signInWithEmailLink(
        email: email,
        emailLink: link,
      );
      return Right(credential);
    } on FirebaseAuthException catch (e) {
      return Left(DatabaseFailure(e.message ?? 'Magic link failed', cause: e));
    } catch (e) {
      return Left(DatabaseFailure('Magic link failed: $e', cause: e));
    }
  }

  /// The current user's ID token (JWT) — refreshed by Firebase.
  Future<String?> currentIdToken() async =>
      await _auth.currentUser?.getIdToken();

  /// Signs out the current user.
  Future<Either<Failure, void>> signOut() async {
    try {
      await _auth.signOut();
      return const Right(null);
    } on FirebaseAuthException catch (e) {
      return Left(DatabaseFailure(e.message ?? 'Sign out failed', cause: e));
    } catch (e) {
      return Left(DatabaseFailure('Sign out failed: $e', cause: e));
    }
  }
}
