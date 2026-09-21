// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'api_client.dart';

/// Auth sync service: syncs the Firebase Auth user into the workers-side
/// database (Option A — explicit sync after login), fetches user profile,
/// and the license associated to the tenant's device-count.
class AuthSyncService {
  final ApiClient _api;

  AuthSyncService({ApiClient? api}) : _api = api ?? ApiClient();

  /// Sync user after Firebase Auth signIn (Google/magic link login).
  Future<Either<Failure, Map<String, dynamic>>> syncUser({
    required String idToken,
  }) {
    return _api.post('/auth/sync-user', {}, idToken: idToken);
  }

  /// Admin dashboard + license check: fetch profile + license.
  Future<Either<Failure, Map<String, dynamic>>> fetchProfile({
    required String idToken,
  }) {
    return _api.get('/auth/me', idToken: idToken);
  }
}
