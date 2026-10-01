// Copyright (c) 2024 Daftari POS. All rights reserved.

/// Cloudflare Workers API client for Daftari POS.
///
/// Wraps daftari-api (authenticated REST), daftari-realtime (WebSocket hub),
/// daftari-paymob (HMAC webhook handler), and daftari-admin (static host).
///
/// Auth: Bearer Firebase ID token (from FirebaseAuthService). All calls
/// run via a single http.Client (dependency-injected in tests).
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/core/config/env_config.dart';

/// HTTP client for the daftari-api Workers backend.
class ApiClient {
  final String baseUrl;
  final http.Client _client;

  ApiClient({String? baseUrl, http.Client? httpClient})
    : baseUrl = baseUrl ?? EnvConfig.apiBaseUrl,
      _client = httpClient ?? http.Client();

  Future<Either<Failure, Map<String, dynamic>>> post(
    String path,
    Map<String, dynamic> body, {
    required String idToken,
  }) => _send('POST', path, idToken: idToken, body: body);

  Future<Either<Failure, Map<String, dynamic>>> get(
    String path, {
    required String idToken,
    Map<String, String>? query,
  }) => _send('GET', path, idToken: idToken, query: query);

  Future<Either<Failure, Map<String, dynamic>>> patch(
    String path,
    Map<String, dynamic> body, {
    required String idToken,
  }) => _send('PATCH', path, idToken: idToken, body: body);

  Future<Either<Failure, Map<String, dynamic>>> delete(
    String path, {
    required String idToken,
  }) => _send('DELETE', path, idToken: idToken);

  /// Shared transport for the four verbs.
  ///
  /// Invariant: a non-2xx response whose body decodes to a JSON object is
  /// returned as `Right(body)` — the workers put the machine-readable cause
  /// in `body['error']` (e.g. `PROVIDER_NOT_ALLOWED`) even on 401/403/500.
  /// Only a non-2xx body that is NOT a JSON object becomes
  /// [HttpFailure]. A bare `catch` makes the `Either` total: a `TypeError`
  /// from a malformed body must not escape.
  Future<Either<Failure, Map<String, dynamic>>> _send(
    String method,
    String path, {
    required String idToken,
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    try {
      final base = Uri.parse('$baseUrl$path');
      final uri = query != null ? base.replace(queryParameters: query) : base;
      final request = http.Request(method, uri)
        ..headers['Authorization'] = 'Bearer $idToken';
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      final res = await http.Response.fromStream(await _client.send(request));
      final decoded = _decodeObject(res.body);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return decoded != null
            ? Right(decoded)
            : Left(HttpFailure(res.statusCode, path));
      }
      return Right(decoded ?? const {});
    } catch (e) {
      return Left(DatabaseFailure('$method $path failed', cause: e));
    }
  }

  /// Owner-only: link a device to the tenant via POST /admin/devices/link.
  /// Returns the created/updated device wire shape.
  Future<Either<Failure, Map<String, dynamic>>> linkDevice(
    String idToken,
    String deviceHwid,
    String deviceName, {
    String? platform,
  }) async {
    return post('/admin/devices/link', {
      'device_hwid': deviceHwid,
      'device_name': deviceName,
      if (platform != null) 'platform': platform!,
    }, idToken: idToken);
  }

  Future<Either<Failure, Map<String, dynamic>>> getAuthMe(
    String idToken,
  ) async {
    return get('/auth/me', idToken: idToken);
  }

  /// [body] as a JSON object, or null when it is not one (bad JSON / array /
  /// scalar) — never throws.
  Map<String, dynamic>? _decodeObject(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
