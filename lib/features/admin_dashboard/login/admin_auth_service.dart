// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:cashier_system/core/backend/workers/api_client.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';

/// A successful /auth/login result.
class AdminCredentials {
  final String token;
  final String sessionId;
  final Map<String, dynamic> profile;
  const AdminCredentials({
    required this.token,
    required this.sessionId,
    required this.profile,
  });
}

/// Credential-stage auth for the web admin dashboard (T11).
///
/// Talks to the api worker's POST /auth/login (username/password, hashed
/// PBKDF2-SHA512 server-side) and persists the resulting HS256 session JWT
/// + tenant id via secure storage. The dashboard's TWO-STAGE login:
/// Firebase (owner, periodic) establishes the tenant; this service is the
/// daily identity stage.
class AdminAuthService {
  AdminAuthService({ApiClient? apiClient, FlutterSecureStorage? storage})
    : _api = apiClient ?? ApiClient(),
      _storage = storage ?? const FlutterSecureStorage();

  static const _jwtKey = 'admin_session_jwt';
  static const _tenantKey = 'admin_tenant_id';
  static const _pendingEmailKey = 'admin_pending_email';

  final ApiClient _api;
  final FlutterSecureStorage _storage;

  Future<String?> storedToken() => _storage.read(key: _jwtKey);

  Future<String?> storedTenantId() => _storage.read(key: _tenantKey);

  /// Persists the tenant id once the Firebase (Stage-1) login establishes
  /// it — the credential stage reads it back for /auth/login (T11 QA: the
  /// only previous writer was credentialLogin itself, which needs a tenant
  /// as INPUT — a fresh browser could never complete the credentials stage).
  Future<void> saveTenantId(String tenantId) =>
      _storage.write(key: _tenantKey, value: tenantId);

  Future<String?> pendingMagicEmail() => _storage.read(key: _pendingEmailKey);

  Future<void> savePendingEmail(String email) =>
      _storage.write(key: _pendingEmailKey, value: email);

  /// POST /auth/login → [AdminCredentials] (token persisted) or Failure.
  /// The api returns ok:false + a machine code on every rejection path:
  /// BAD_CREDENTIALS, OWNER_REAUTH_REQUIRED, DASHBOARD_ADMIN_ONLY,
  /// LOGIN_LOCKED (+locked_until), SESSION_CONFLICT (+conflict_session_id).
  Future<Either<Failure, AdminCredentials>> credentialLogin({
    required String tenantId,
    required String username,
    required String password,
  }) async {
    final res = await _api.post(
      '/auth/login',
      {'tenant_id': tenantId, 'username': username, 'password': password},
      idToken: '', // public route — no bearer needed
    );
    final body = res.fold((f) => null, (b) => b);
    if (body == null) {
      return Left(const DatabaseFailure('Login request failed'));
    }
    if (body['ok'] != true) {
      final error = body['error'] as String? ?? 'UNKNOWN';
      if (error == 'SESSION_CONFLICT') {
        return Left(
          SessionConflictFailure(
            (body['conflict_session_id'] as String?) ?? '',
          ),
        );
      }
      return Left(AdminAuthFailure(error, detail: error));
    }
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      return const Left(DatabaseFailure('Login response missing data'));
    }
    final token = data['token'];
    if (token is! String) {
      return const Left(DatabaseFailure('Login response missing token'));
    }
    await _storage.write(key: _jwtKey, value: token);
    await _storage.write(key: _tenantKey, value: tenantId);
    return Right(
      AdminCredentials(
        token: token,
        sessionId: data['session_id'] as String? ?? '',
        profile: (data['profile'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }

  /// POST /auth/owner-refresh — stamps the tenant's last owner login
  /// (resets the 90-day re-auth window). Called right after a successful
  /// Firebase (Stage-1) login.
  Future<Either<Failure, void>> refreshOwner({required String idToken}) async {
    final res = await _api.post('/auth/owner-refresh', {}, idToken: idToken);
    return res.fold((f) => Left(f), (_) => const Right(null));
  }

  /// GET /admin/users — the tenant's accounts; an EMPTY list means the
  /// owner (Firebase-authenticated) proceeds directly (first-admin
  /// bootstrap; T14's Users Management creates the first account).
  Future<Either<Failure, List<Map<String, dynamic>>>> tenantAccounts({
    required String idToken,
  }) async {
    final res = await _api.get('/admin/users', idToken: idToken);
    return res.fold((f) => Left(f), (body) {
      if (body['ok'] != true) {
        final error = body['error'] as String? ?? 'UNKNOWN';
        return Left(AdminAuthFailure(error, detail: error));
      }
      final data = body['data'] as Map<String, dynamic>?;
      final users = (data?['users'] as List?) ?? const [];
      return Right(users.cast<Map<String, dynamic>>());
    });
  }

  /// POST /sessions/revoke — force-ends the username's active sessions
  /// (session-conflict UX, spec §6.5). Tenant comes from the token.
  /// Inspects ok:false (the api worker signals 401/403 in the body — T11 QA:
  /// a rejected revoke must be a Left, or the conflict dialog loops).
  Future<Either<Failure, void>> revokeSessions({
    required String username,
    required String idToken,
  }) async {
    final res = await _api.post('/sessions/revoke', {
      'username': username,
    }, idToken: idToken);
    return res.fold((f) => Left(f), (body) {
      if (body['ok'] != true) {
        final error = body['error'] as String? ?? 'UNKNOWN';
        return Left(AdminAuthFailure(error, detail: error));
      }
      return const Right(null);
    });
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _jwtKey);
    await _storage.delete(key: _tenantKey);
  }
}
