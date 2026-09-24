// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';

/// Firebase Auth service with tenant ID model.
///
/// The tenant_id is the Firebase UID of the business owner/tenant.
/// All devices and local users belong to this tenant.
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

  /// Signs in with email and password.
  Future<Either<Failure, UserCredential>> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return Right(credential);
    } on FirebaseAuthException catch (e) {
      return Left(DatabaseFailure(e.message ?? 'Sign in failed', cause: e));
    } catch (e) {
      return Left(DatabaseFailure('Sign in failed: $e', cause: e));
    }
  }

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

  /// Creates a new user with email and password.
  Future<Either<Failure, UserCredential>> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return Right(credential);
    } on FirebaseAuthException catch (e) {
      return Left(
        DatabaseFailure(e.message ?? 'Account creation failed', cause: e),
      );
    } catch (e) {
      return Left(DatabaseFailure('Account creation failed: $e', cause: e));
    }
  }

  /// Sends a password reset email.
  Future<Either<Failure, void>> sendPasswordResetEmail({
    required String email,
  }) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return const Right(null);
    } on FirebaseAuthException catch (e) {
      return Left(
        DatabaseFailure(e.message ?? 'Password reset failed', cause: e),
      );
    } catch (e) {
      return Left(DatabaseFailure('Password reset failed: $e', cause: e));
    }
  }
}
